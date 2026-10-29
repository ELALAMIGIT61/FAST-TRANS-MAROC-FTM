-- Migration 20260504000071 - point A1, F9 : missions conclues jamais demarrees
-- et missions demarrees jamais cloturees (accord du porteur du 29/10/2026)
--
-- Constat : seule une mission « en attente » expirait automatiquement
-- (migration 059). Une mission « acceptee » jamais demarree, ou « en cours »
-- jamais cloturee, restait dans cet etat indefiniment : elle bloquait l'agenda
-- du chauffeur (regle des ecarts, migration 064) et restait affichee comme
-- mission a venir ou en cours chez le client et le chauffeur.
--
-- Regles validees (reglables par l'admin, par categorie ; 0 = desactive) :
-- 1. Mission acceptee non demarree :
--    - rappel unique au chauffeur 1 h apres l'heure prevue
--      (start_reminder_hours_<categorie>) ;
--    - 6 h apres l'heure prevue (not_started_close_hours_<categorie>) : la
--      mission passe a l'etat « expiree » (affichee « non realisee ») ;
--      chauffeur, client et admin sont prevenus ; l'agenda du chauffeur est
--      libere ; pas de remboursement automatique de la commission (le
--      chauffeur peut le demander, l'admin decide) ; pas comptee comme une
--      annulation du chauffeur.
-- 2. Mission en cours non cloturee : cloturee « terminee » par le serveur,
--    compte a partir du demarrage (actual_pickup_time) : VUL 6 h, N2 Moyen et
--    N2 Grand 24 h (in_progress_close_hours_<categorie>) ; client et chauffeur
--    recoivent les messages habituels de fin de mission (migration 069), l'admin
--    est prevenu. Les regles habituelles de fin de mission s'appliquent
--    (commission prelevee si elle ne l'a pas ete, statistiques).
--
-- 1. Reglages.
-- 2. Colonnes missions.start_reminder_sent_at et missions.auto_closed_at
--    (remplies par le serveur seulement).
-- 3. Fonction process_overdue_missions(), tache planifiee toutes les 5 min.
-- Aucune donnee existante modifiee par la migration elle-meme.

-- 1. Reglages
INSERT INTO public.app_settings (key, value, description) VALUES
  ('start_reminder_hours_vul', 1, 'Rappel au chauffeur VUL (heures apres l''heure prevue) si la mission n''a pas demarre (0 = pas de rappel)'),
  ('start_reminder_hours_n2_medium', 1, 'Rappel au chauffeur N2 Moyen (heures apres l''heure prevue) si la mission n''a pas demarre (0 = pas de rappel)'),
  ('start_reminder_hours_n2_large', 1, 'Rappel au chauffeur N2 Grand (heures apres l''heure prevue) si la mission n''a pas demarre (0 = pas de rappel)'),
  ('not_started_close_hours_vul', 6, 'Cloture automatique (heures apres l''heure prevue) d''une mission VUL conclue non demarree (0 = jamais)'),
  ('not_started_close_hours_n2_medium', 6, 'Cloture automatique (heures apres l''heure prevue) d''une mission N2 Moyen conclue non demarree (0 = jamais)'),
  ('not_started_close_hours_n2_large', 6, 'Cloture automatique (heures apres l''heure prevue) d''une mission N2 Grand conclue non demarree (0 = jamais)'),
  ('in_progress_close_hours_vul', 6, 'Cloture automatique (heures apres le demarrage) d''une mission VUL en cours non cloturee (0 = jamais)'),
  ('in_progress_close_hours_n2_medium', 24, 'Cloture automatique (heures apres le demarrage) d''une mission N2 Moyen en cours non cloturee (0 = jamais)'),
  ('in_progress_close_hours_n2_large', 24, 'Cloture automatique (heures apres le demarrage) d''une mission N2 Grand en cours non cloturee (0 = jamais)')
ON CONFLICT (key) DO NOTHING;

-- 2. Colonnes de suivi (le serveur seul les remplit)
ALTER TABLE public.missions
  ADD COLUMN IF NOT EXISTS start_reminder_sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS auto_closed_at timestamptz;

REVOKE UPDATE (start_reminder_sent_at, auto_closed_at) ON public.missions FROM anon, authenticated;

-- 3. Traitement des missions en retard
CREATE OR REPLACE FUNCTION public.process_overdue_missions()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r record;
  v_reminders integer := 0;
  v_not_started integer := 0;
  v_completed integer := 0;
  v_done uuid;
BEGIN
  -- a. Rappel unique au chauffeur d'une mission conclue non demarree (pas de
  --    rappel si la mission est deja a cloturer : elle l'est a l'etape b)
  FOR r IN
    SELECT m.id, m.mission_number, m.scheduled_pickup_time, d.profile_id AS driver_profile
    FROM missions m
    JOIN drivers d ON d.id = m.driver_id
    JOIN app_settings s ON s.key = 'start_reminder_hours_' || m.vehicle_category::text
    LEFT JOIN app_settings c ON c.key = 'not_started_close_hours_' || m.vehicle_category::text
    WHERE m.status = 'accepted'
      AND m.start_reminder_sent_at IS NULL
      AND m.scheduled_pickup_time IS NOT NULL
      AND s.value > 0
      AND m.scheduled_pickup_time + make_interval(secs => s.value * 3600) <= now()
      AND (coalesce(c.value, 0) <= 0
           OR m.scheduled_pickup_time + make_interval(secs => c.value * 3600) > now())
  LOOP
    BEGIN
      v_done := NULL;
      UPDATE missions SET start_reminder_sent_at = now()
      WHERE id = r.id AND status = 'accepted' AND start_reminder_sent_at IS NULL
      RETURNING id INTO v_done;
      IF v_done IS NOT NULL AND r.driver_profile IS NOT NULL THEN
        INSERT INTO notifications (profile_id, type, title, body, data, is_read)
        VALUES (r.driver_profile, 'mission_start_reminder', '⏰ Mission non démarrée',
                'La mission ' || r.mission_number || ' devait commencer le '
                  || to_char(r.scheduled_pickup_time AT TIME ZONE 'UTC', 'DD/MM "à" HH24"h"MI')
                  || '. Si vous êtes en route, touchez « Démarrer ». Sinon, annulez-la.',
                jsonb_build_object('mission_id', r.id, 'screen', 'MissionActiveScreen'), false);
        v_reminders := v_reminders + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'process_overdue_missions: rappel non envoye pour la mission % (%)', r.mission_number, SQLERRM;
    END;
  END LOOP;

  -- b. Mission conclue non demarree : cloture « non realisee » (etat expired)
  FOR r IN
    SELECT m.id, m.mission_number, m.client_id, d.profile_id AS driver_profile
    FROM missions m
    JOIN drivers d ON d.id = m.driver_id
    JOIN app_settings s ON s.key = 'not_started_close_hours_' || m.vehicle_category::text
    WHERE m.status = 'accepted'
      AND m.scheduled_pickup_time IS NOT NULL
      AND s.value > 0
      AND m.scheduled_pickup_time + make_interval(secs => s.value * 3600) <= now()
  LOOP
    BEGIN
      v_done := NULL;
      UPDATE missions SET status = 'expired', auto_closed_at = now()
      WHERE id = r.id AND status = 'accepted'
      RETURNING id INTO v_done;
      IF v_done IS NOT NULL THEN
        IF r.driver_profile IS NOT NULL THEN
          INSERT INTO notifications (profile_id, type, title, body, data, is_read)
          VALUES (r.driver_profile, 'mission_not_started', '⏱️ Mission non réalisée',
                  'La mission ' || r.mission_number || ' n''a pas démarré : elle a été clôturée.',
                  jsonb_build_object('mission_id', r.id, 'screen', 'MissionActiveScreen'), false);
        END IF;
        IF r.client_id IS NOT NULL THEN
          INSERT INTO notifications (profile_id, type, title, body, data, is_read)
          VALUES (r.client_id, 'mission_not_started', '⏱️ Mission non réalisée',
                  'La mission ' || r.mission_number || ' n''a pas démarré à l''heure prévue et a été clôturée. '
                    || 'Vous pouvez créer une nouvelle mission.',
                  jsonb_build_object('mission_id', r.id, 'screen', 'MissionTrackingScreen'), false);
        END IF;
        INSERT INTO notifications (profile_id, type, title, body, data, is_read)
        SELECT p.id, 'mission_not_started', '⏱️ Mission non réalisée',
               'La mission ' || r.mission_number || ' (conclue) n''a pas démarré : clôturée automatiquement.',
               jsonb_build_object('mission_id', r.id), false
        FROM profiles p WHERE p.role = 'admin';
        v_not_started := v_not_started + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'process_overdue_missions: mission % non cloturee (%)', r.mission_number, SQLERRM;
    END;
  END LOOP;

  -- c. Mission en cours non cloturee : cloture « terminee »
  FOR r IN
    SELECT m.id, m.mission_number
    FROM missions m
    JOIN app_settings s ON s.key = 'in_progress_close_hours_' || m.vehicle_category::text
    WHERE m.status = 'in_progress'
      AND coalesce(m.actual_pickup_time, m.scheduled_pickup_time) IS NOT NULL
      AND s.value > 0
      AND coalesce(m.actual_pickup_time, m.scheduled_pickup_time) + make_interval(secs => s.value * 3600) <= now()
  LOOP
    BEGIN
      v_done := NULL;
      UPDATE missions
      SET status = 'completed', actual_dropoff_time = now(), completed_at = now(), auto_closed_at = now()
      WHERE id = r.id AND status = 'in_progress'
      RETURNING id INTO v_done;
      IF v_done IS NOT NULL THEN
        INSERT INTO notifications (profile_id, type, title, body, data, is_read)
        SELECT p.id, 'mission_auto_completed', '🏁 Mission clôturée automatiquement',
               'La mission ' || r.mission_number || ' était en cours sans avoir été clôturée par le chauffeur : '
                 || 'elle a été clôturée « terminée » automatiquement.',
               jsonb_build_object('mission_id', r.id), false
        FROM profiles p WHERE p.role = 'admin';
        v_completed := v_completed + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      -- ex. solde insuffisant pour la commission de dernier recours : la
      -- mission reste en cours, nouvel essai au passage suivant
      RAISE WARNING 'process_overdue_missions: mission % non terminee (%)', r.mission_number, SQLERRM;
    END;
  END LOOP;

  RETURN jsonb_build_object('reminders', v_reminders, 'not_started_closed', v_not_started,
                            'in_progress_completed', v_completed);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.process_overdue_missions() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_overdue_missions() TO service_role;

SELECT cron.unschedule('process-overdue-missions')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-overdue-missions');

SELECT cron.schedule(
  'process-overdue-missions',
  '*/5 * * * *',
  $$ SELECT public.process_overdue_missions(); $$
);
