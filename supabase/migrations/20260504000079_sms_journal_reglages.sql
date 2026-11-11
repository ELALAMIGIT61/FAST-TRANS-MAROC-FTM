-- Migration 20260504000079 - option B (SMS de connexion), lot SMS-1 : journal des envois et reglages
-- (architecture validee par le porteur les 10/11/2026 et 11/11/2026 ; aucun envoi de SMS dans ce lot)
--
-- 1. Journal des envois de codes de connexion (sms_send_log) : une ligne par tentative
--    d'envoi faite par la future fonction serveur send-sms. Le code n'y est JAMAIS
--    enregistre ; le numero y est masque (ex. +2126••••1234). Lisible par l'admin
--    seulement ; ecrit uniquement par le serveur (service_role).
-- 2. Etat d'aiguillage (sms_routing_state) : en un seul appel, la fonction send-sms
--    obtient le mode, les delais, l'etat du disjoncteur et le rang de l'envoi pour
--    cet utilisateur (1er envoi, 1er renvoi, 2e renvoi...).
-- 3. Effacement automatique du journal apres 6 mois (reglable), chaque nuit.
-- 4. Reglages de l'admin (modifiables par requete SQL en attendant l'ecran) :
--    mode d'envoi (0 = AdaSMS seul, 1 = AdaSMS + secours automatique,
--    2 = secours seul), disjoncteur (3 echecs / 10 minutes), delais d'attente
--    (3,5 s seul / 2,5 s avec secours), renvoi par le secours a partir du 3e envoi,
--    fenetre de comptage des renvois (15 minutes), conservation du journal.

-- 1. Journal
CREATE TABLE IF NOT EXISTS public.sms_send_log (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at          timestamptz NOT NULL DEFAULT now(),
  user_id             uuid,
  phone_masked        text NOT NULL,
  send_number         smallint NOT NULL DEFAULT 1,
  attempt             smallint NOT NULL DEFAULT 1,
  mode                smallint NOT NULL,
  provider            text NOT NULL,
  outcome             text NOT NULL,
  is_fallback         boolean NOT NULL DEFAULT false,
  breaker_open        boolean NOT NULL DEFAULT false,
  http_status         integer,
  error_code          text,
  error_message       text,
  duration_ms         integer,
  provider_message_id text,
  cost_mad            numeric(10,4),
  segments            smallint,
  CONSTRAINT sms_send_log_provider_check CHECK (provider IN ('adasms', 'twilio')),
  CONSTRAINT sms_send_log_outcome_check CHECK (outcome IN ('sent', 'failed')),
  CONSTRAINT sms_send_log_mode_check CHECK (mode IN (0, 1, 2)),
  -- attempt : 1 = premiere tentative de la demande, 2 = reprise par le secours dans la meme demande
  CONSTRAINT sms_send_log_attempt_check CHECK (attempt IN (1, 2)),
  -- garde-fou : jamais plus de 5 chiffres a la suite (pas de numero complet, pas de code)
  CONSTRAINT sms_send_log_phone_masked_check CHECK (phone_masked !~ '[0-9]{5,}'),
  CONSTRAINT sms_send_log_error_message_check CHECK (error_message IS NULL OR error_message !~ '[0-9]{5,}'),
  CONSTRAINT sms_send_log_lengths_check CHECK (
    char_length(phone_masked) <= 32
    AND char_length(coalesce(error_code, '')) <= 64
    AND char_length(coalesce(error_message, '')) <= 300
    AND char_length(coalesce(provider_message_id, '')) <= 128)
);
CREATE INDEX IF NOT EXISTS sms_send_log_created_at_idx ON public.sms_send_log (created_at);
CREATE INDEX IF NOT EXISTS sms_send_log_user_created_idx ON public.sms_send_log (user_id, created_at);
CREATE INDEX IF NOT EXISTS sms_send_log_provider_created_idx ON public.sms_send_log (provider, is_fallback, created_at);

ALTER TABLE public.sms_send_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sms_send_log FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.sms_send_log TO authenticated;
DROP POLICY IF EXISTS sms_send_log_select_admin ON public.sms_send_log;
CREATE POLICY sms_send_log_select_admin ON public.sms_send_log
  FOR SELECT TO authenticated USING (public.get_my_role() = 'admin');

-- 2. Etat d'aiguillage (appele par send-sms avec la cle serveur)
CREATE OR REPLACE FUNCTION public.sms_routing_state(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_failures   integer := greatest(public.app_setting_value('sms_breaker_failures', 3), 1)::int;
  v_minutes    integer := greatest(public.app_setting_value('sms_breaker_minutes', 10), 1)::int;
  v_window     integer := greatest(public.app_setting_value('sms_resend_window_minutes', 15), 1)::int;
  v_recent     text[];
  v_last_fail  timestamptz;
  v_breaker    boolean := false;
  v_previous   integer := 0;
BEGIN
  -- Disjoncteur : les N dernieres tentatives AdaSMS (hors secours) ont toutes echoue,
  -- et la plus recente date de moins de X minutes.
  SELECT array_agg(l.outcome ORDER BY l.created_at DESC), max(l.created_at)
    INTO v_recent, v_last_fail
    FROM (SELECT outcome, created_at FROM sms_send_log
           WHERE provider = 'adasms'
           ORDER BY created_at DESC
           LIMIT v_failures) l;
  IF coalesce(array_length(v_recent, 1), 0) = v_failures
     AND NOT ('sent' = ANY (v_recent))
     AND v_last_fail > now() - make_interval(mins => v_minutes) THEN
    v_breaker := true;
  END IF;

  -- Rang de l'envoi pour cet utilisateur dans la fenetre de renvoi
  IF p_user_id IS NOT NULL THEN
    SELECT count(*) INTO v_previous FROM sms_send_log
     WHERE user_id = p_user_id AND attempt = 1
       AND created_at > now() - make_interval(mins => v_window);
  END IF;

  RETURN jsonb_build_object(
    'mode', public.app_setting_value('sms_mode', 0)::int,
    'timeout_primary_ms', public.app_setting_value('sms_timeout_primary_ms', 3500)::int,
    'timeout_with_fallback_ms', public.app_setting_value('sms_timeout_with_fallback_ms', 2500)::int,
    'resend_fallback_from', public.app_setting_value('sms_resend_fallback_from', 3)::int,
    'breaker_open', v_breaker,
    'send_number', v_previous + 1
  );
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.sms_routing_state(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sms_routing_state(uuid) TO service_role;

-- 3. Effacement du journal
CREATE OR REPLACE FUNCTION public.purge_old_sms_log()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_months integer := greatest(public.app_setting_value('sms_log_retention_months', 6), 1)::int;
  v_count  integer;
BEGIN
  DELETE FROM sms_send_log l WHERE l.created_at < now() - make_interval(months => v_months);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.purge_old_sms_log() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_old_sms_log() TO service_role;

SELECT cron.unschedule('purge-old-sms-log')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-old-sms-log');
SELECT cron.schedule(
  'purge-old-sms-log',
  '37 3 * * *',
  $$ SELECT public.purge_old_sms_log(); $$
);

-- 4. Reglages (reprend la version 078 de validate_app_setting, ajouts en fin)
CREATE OR REPLACE FUNCTION public.validate_app_setting()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cat text;
  v_other numeric;
BEGIN
  IF NEW.value < 0 THEN
    RAISE EXCEPTION 'reglage_invalide: la valeur ne peut pas être négative' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'rating_window_days' AND NEW.value < 1 THEN
    RAISE EXCEPTION 'reglage_invalide: le délai pour noter doit être d''au moins 1 jour' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'rating_reminder_hours_first' AND NEW.value > 0 THEN
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'rating_reminder_hours_second';
    IF v_other IS NOT NULL AND v_other > 0 AND NEW.value >= v_other THEN
      RAISE EXCEPTION 'reglage_invalide: le 1er rappel (% h) doit venir avant le 2e (% h)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  IF NEW.key = 'rating_reminder_hours_second' AND NEW.value > 0 THEN
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'rating_reminder_hours_first';
    IF v_other IS NOT NULL AND v_other > 0 AND NEW.value <= v_other THEN
      RAISE EXCEPTION 'reglage_invalide: le 2e rappel (% h) doit venir après le 1er (% h)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  IF NEW.key = 'client_cancel_window_months' AND NEW.value < 1 THEN
    RAISE EXCEPTION 'reglage_invalide: la période doit être d''au moins 1 mois' USING ERRCODE = '22023';
  END IF;
  IF NEW.key LIKE 'commission\_amount\_%' THEN
    IF NEW.value < 1 THEN
      RAISE EXCEPTION 'reglage_invalide: la commission doit être d''au moins 1 DH' USING ERRCODE = '22023';
    END IF;
    v_cat := substr(NEW.key, length('commission_amount_') + 1);
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'min_balance_' || v_cat;
    IF v_other IS NOT NULL AND NEW.value > v_other THEN
      RAISE EXCEPTION 'reglage_invalide: la commission (% DH) ne peut pas dépasser le solde minimum de la catégorie (% DH)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  IF NEW.key LIKE 'min\_balance\_%' THEN
    v_cat := substr(NEW.key, length('min_balance_') + 1);
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'commission_amount_' || v_cat;
    IF v_other IS NOT NULL AND NEW.value < v_other THEN
      RAISE EXCEPTION 'reglage_invalide: le solde minimum (% DH) ne peut pas être inférieur à la commission de la catégorie (% DH)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  -- Migration 078 (B1) : reglages des adresses
  IF NEW.key = 'address_entry_mode' AND NEW.value NOT IN (0, 1, 2) THEN
    RAISE EXCEPTION 'reglage_invalide: mode de saisie : 0 (adresse tapée + épingle), 1 (mixte) ou 2 (suggestions)' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'saved_addresses_max' AND (NEW.value < 1 OR NEW.value > 20 OR NEW.value <> trunc(NEW.value)) THEN
    RAISE EXCEPTION 'reglage_invalide: le nombre d''adresses enregistrées doit être un entier de 1 à 20' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'saved_addresses_unused_months' AND NEW.value < 1 THEN
    RAISE EXCEPTION 'reglage_invalide: la durée doit être d''au moins 1 mois' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'learned_point_max_distance_m' AND NEW.value < 10 THEN
    RAISE EXCEPTION 'reglage_invalide: la distance doit être d''au moins 10 m' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'learned_point_max_age_minutes' AND NEW.value < 1 THEN
    RAISE EXCEPTION 'reglage_invalide: l''ancienneté doit être d''au moins 1 minute' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'google_data_retention_days' AND (NEW.value < 1 OR NEW.value > 30) THEN
    RAISE EXCEPTION 'reglage_invalide: les données Google doivent être effacées en 30 jours au plus (au moins 1 jour)' USING ERRCODE = '22023';
  END IF;
  -- Migration 079 (option B) : reglages des SMS de connexion
  IF NEW.key = 'sms_mode' AND NEW.value NOT IN (0, 1, 2) THEN
    RAISE EXCEPTION 'reglage_invalide: mode d''envoi : 0 (AdaSMS seul), 1 (AdaSMS + secours automatique) ou 2 (secours seul)' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'sms_breaker_failures' AND (NEW.value < 1 OR NEW.value > 20 OR NEW.value <> trunc(NEW.value)) THEN
    RAISE EXCEPTION 'reglage_invalide: le nombre d''échecs du disjoncteur doit être un entier de 1 à 20' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'sms_breaker_minutes' AND (NEW.value < 1 OR NEW.value > 1440) THEN
    RAISE EXCEPTION 'reglage_invalide: la durée du disjoncteur doit être de 1 à 1440 minutes' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'sms_timeout_primary_ms' AND (NEW.value < 500 OR NEW.value > 4500) THEN
    RAISE EXCEPTION 'reglage_invalide: le délai d''attente AdaSMS seul doit être de 500 à 4500 ms (Supabase abandonne à 5 s)' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'sms_timeout_with_fallback_ms' AND (NEW.value < 500 OR NEW.value > 3000) THEN
    RAISE EXCEPTION 'reglage_invalide: le délai d''attente avec secours doit être de 500 à 3000 ms (il faut laisser du temps au secours)' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'sms_resend_fallback_from' AND (NEW.value < 2 OR NEW.value > 10 OR NEW.value <> trunc(NEW.value)) THEN
    RAISE EXCEPTION 'reglage_invalide: le renvoi par le secours doit commencer entre le 2e et le 10e envoi' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'sms_resend_window_minutes' AND (NEW.value < 1 OR NEW.value > 120) THEN
    RAISE EXCEPTION 'reglage_invalide: la fenêtre de comptage des renvois doit être de 1 à 120 minutes' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'sms_log_retention_months' AND (NEW.value < 1 OR NEW.value > 24) THEN
    RAISE EXCEPTION 'reglage_invalide: la conservation du journal des SMS doit être de 1 à 24 mois' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$function$;

INSERT INTO public.app_settings (key, value, description) VALUES
  ('sms_mode', 0, 'SMS de connexion : 0 = AdaSMS seul, 1 = AdaSMS + secours automatique, 2 = secours seul'),
  ('sms_breaker_failures', 3, 'Disjoncteur SMS : nombre d''échecs AdaSMS consécutifs avant de passer directement au secours'),
  ('sms_breaker_minutes', 10, 'Disjoncteur SMS : durée (minutes) pendant laquelle on passe directement au secours'),
  ('sms_timeout_primary_ms', 3500, 'Délai d''attente (ms) de la réponse AdaSMS quand il n''y a pas de secours'),
  ('sms_timeout_with_fallback_ms', 2500, 'Délai d''attente (ms) de la réponse AdaSMS quand le secours est actif'),
  ('sms_resend_fallback_from', 3, 'Rang de l''envoi à partir duquel « Renvoyer le code » passe par le secours (3 = 2e renvoi)'),
  ('sms_resend_window_minutes', 15, 'Fenêtre (minutes) pour compter les renvois de code d''un même utilisateur'),
  ('sms_log_retention_months', 6, 'Effacement du journal des SMS après ce nombre de mois')
ON CONFLICT (key) DO NOTHING;
