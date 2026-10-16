-- Migration 20260504000054 - session 2.23 : prelevement anticipe de la commission
-- et annonce de la messagerie vocale confies a une tache planifiee cote serveur
-- (decision du porteur du 16/10/2026 : tache toutes les 5 minutes, solde
-- insuffisant => nouvel essai a chaque passage et alerte unique au chauffeur et
-- aux administrateurs, retrait du droit de prelever depuis l'application)
--
-- Constat (16/10/2026) :
--  - le prelevement anticipe (24 h avant le chargement) n'etait declenche que si
--    le chauffeur avait l'ecran de la mission ouvert ; sinon, rien avant la fin
--    de la mission (filet de securite process_commission_payment) ;
--  - la notification « Messagerie vocale disponible » n'etait envoyee que si
--    l'ecran etait ouvert, et repartait a chaque nouvelle ouverture ;
--  - en cas de solde insuffisant, personne n'etait prevenu ;
--  - charge_commission_anticipated etant executee avec les droits du
--    proprietaire, son controle « appelant = chauffeur de la mission » ne
--    fonctionnait pas (current_user y vaut toujours le proprietaire) : tout
--    utilisateur connecte pouvait declencher le prelevement d'une mission
--    acceptee, a tout moment (verifie sur une copie locale).
--
-- 1. Deux colonnes de suivi sur missions : voice_channel_notified_at (annonce
--    de la messagerie faite) et commission_alert_sent_at (alerte « solde
--    insuffisant » envoyee). Non modifiables par les utilisateurs : depuis la
--    migration 030, les droits UPDATE sur missions sont accordes colonne par
--    colonne et ces nouvelles colonnes n'en font pas partie.
-- 2. Fonction process_missions_24h_window() : pour chaque mission acceptee ou en
--    cours dont le chargement est a moins de 24 h :
--    a. preleve la commission si ce n'est pas fait (charge_commission_anticipated) ;
--       si le solde est insuffisant, alerte une seule fois le chauffeur et les
--       administrateurs, et reessaie au passage suivant ;
--    b. annonce une seule fois la messagerie vocale au client et au chauffeur.
-- 3. Tache planifiee « process-missions-24h » toutes les 5 minutes.
-- 4. Droits : process_missions_24h_window et charge_commission_anticipated ne
--    sont plus executables que par le systeme (service_role, tache planifiee).
--
-- Le filet de securite process_commission_payment (prelevement a la fin de la
-- mission si rien n'a ete preleve avant) est inchange.

-- 1
ALTER TABLE public.missions
  ADD COLUMN IF NOT EXISTS voice_channel_notified_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS commission_alert_sent_at TIMESTAMP WITH TIME ZONE;

-- Missions deja traitees par l'application (commission deja prelevee) :
-- considerees comme deja annoncees, pour ne pas renvoyer l'annonce.
UPDATE public.missions
SET voice_channel_notified_at = NOW()
WHERE status IN ('accepted', 'in_progress')
  AND commission_charged_at IS NOT NULL
  AND voice_channel_notified_at IS NULL;

-- 2
CREATE OR REPLACE FUNCTION public.process_missions_24h_window()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r RECORD;
  v_result jsonb;
  v_driver_profile uuid;
  v_balance numeric;
  v_charged integer := 0;
  v_insufficient integer := 0;
  v_voice integer := 0;
  v_marked uuid;
BEGIN
  FOR r IN
    SELECT m.id, m.mission_number, m.client_id, m.driver_id, m.commission_amount,
           m.commission_charged_at, m.voice_channel_notified_at, m.commission_alert_sent_at
    FROM missions m
    WHERE m.status IN ('accepted', 'in_progress')
      AND m.driver_id IS NOT NULL
      AND m.scheduled_pickup_time IS NOT NULL
      AND m.scheduled_pickup_time <= NOW() + INTERVAL '24 hours'
      AND (m.commission_charged_at IS NULL OR m.voice_channel_notified_at IS NULL)
    ORDER BY m.scheduled_pickup_time
  LOOP
    SELECT d.profile_id INTO v_driver_profile FROM drivers d WHERE d.id = r.driver_id;

    -- a. Commission
    IF r.commission_charged_at IS NULL AND r.commission_amount IS NOT NULL THEN
      BEGIN
        v_result := public.charge_commission_anticipated(r.id);
        IF COALESCE((v_result->>'success')::boolean, false) THEN
          v_charged := v_charged + 1;
        ELSIF COALESCE(v_result->>'error', '') <> 'already_charged' THEN
          RAISE WARNING 'process_missions_24h_window: mission % non prelevee (%)',
            r.mission_number, v_result->>'error';
        END IF;
      EXCEPTION WHEN check_violation THEN
        -- Solde insuffisant (wallet.balance >= 0) : rien n'est preleve,
        -- nouvel essai au passage suivant, alerte envoyee une seule fois.
        v_insufficient := v_insufficient + 1;
        IF r.commission_alert_sent_at IS NULL THEN
          SELECT w.balance INTO v_balance FROM wallet w WHERE w.driver_id = r.driver_id;
          IF v_driver_profile IS NOT NULL THEN
            INSERT INTO notifications (profile_id, type, title, body, data, is_read)
            VALUES (
              v_driver_profile, 'commission_insufficient_balance',
              '⚠️ Solde insuffisant',
              'Votre solde (' || to_char(COALESCE(v_balance, 0), 'FM999999990.00')
                || ' DH) ne couvre pas la commission de la mission ' || r.mission_number
                || ' (' || to_char(r.commission_amount, 'FM999999990.00')
                || ' DH). Rechargez votre portefeuille.',
              jsonb_build_object('mission_id', r.id, 'screen', 'WalletDashboard'),
              false);
          END IF;
          INSERT INTO notifications (profile_id, type, title, body, data, is_read)
          SELECT p.id, 'commission_insufficient_balance',
                 '⚠️ Commission non prélevée',
                 'La commission de la mission ' || r.mission_number
                   || ' n''a pas pu être prélevée : solde du chauffeur insuffisant.',
                 jsonb_build_object('mission_id', r.id),
                 false
          FROM profiles p WHERE p.role = 'admin';
          UPDATE missions SET commission_alert_sent_at = NOW() WHERE id = r.id;
        END IF;
      END;
    END IF;

    -- b. Annonce de la messagerie vocale (une seule fois)
    IF r.voice_channel_notified_at IS NULL THEN
      v_marked := NULL;
      UPDATE missions SET voice_channel_notified_at = NOW()
      WHERE id = r.id AND voice_channel_notified_at IS NULL
      RETURNING id INTO v_marked;
      IF v_marked IS NOT NULL THEN
        INSERT INTO notifications (profile_id, type, title, body, data, is_read)
        SELECT t.pid, 'voice_channel_opened',
               '🎤 Messagerie vocale disponible',
               'Votre mission ' || r.mission_number
                 || ' approche. Vous pouvez désormais échanger des messages vocaux.',
               jsonb_build_object('mission_id', r.id, 'screen', 'VoiceChat'),
               false
        FROM (VALUES (r.client_id), (v_driver_profile)) AS t(pid)
        WHERE t.pid IS NOT NULL;
        v_voice := v_voice + 1;
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'charged', v_charged,
    'insufficient_balance', v_insufficient,
    'voice_announced', v_voice
  );
END;
$function$;

-- 4. Droits
REVOKE EXECUTE ON FUNCTION public.process_missions_24h_window() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_missions_24h_window() TO service_role;

REVOKE EXECUTE ON FUNCTION public.charge_commission_anticipated(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.charge_commission_anticipated(uuid) TO service_role;

-- 3. Tache planifiee toutes les 5 minutes
SELECT cron.unschedule('process-missions-24h')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-missions-24h');

SELECT cron.schedule(
  'process-missions-24h',
  '*/5 * * * *',
  $$ SELECT public.process_missions_24h_window(); $$
);
