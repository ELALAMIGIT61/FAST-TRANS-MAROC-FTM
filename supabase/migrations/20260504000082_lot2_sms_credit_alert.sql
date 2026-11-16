-- Migration 20260504000082 - lot 2 (B5) : alerte de credit SMS bas
-- (contenu valide par le porteur le 16/11/2026 ; aucun fichier protege modifie)
--
-- Toutes les heures, la fonction serveur check-sms-credit lit le solde du compte
-- AdaSMS (GET /v1/account, consultation sans envoi de SMS) et transmet le
-- resultat a report_sms_credit, qui tient l'etat a jour et previent tous les
-- administrateurs actifs :
--   - moins de 100 SMS restants (reglable) : alerte, puis rappel toutes les
--     24 h (reglable) tant que le credit reste bas ;
--   - moins de 30 SMS restants (reglable) : alerte urgente, une fois ;
--   - cle refusee par AdaSMS (401 ou 403) ou absente : alerte, puis une fois
--     par jour tant que le probleme dure ;
--   - solde illisible 3 fois de suite (reseau, panne) : alerte, une fois.
-- Apres une recharge (credit revenu au-dessus du seuil), les alertes se rearment.
-- La fonction send-sms (envoi des codes de connexion) n'est pas touchee.

-- 1. Reglages (modifiables par l'administrateur)
INSERT INTO public.app_settings (key, value, description) VALUES
  ('sms_credit_check_enabled', 1, 'Surveillance du crédit SMS AdaSMS : 1 = activée, 0 = arrêtée'),
  ('sms_credit_alert_threshold', 100, 'Alerte quand il reste moins de ce nombre de SMS (crédit AdaSMS)'),
  ('sms_credit_critical_threshold', 30, 'Alerte urgente quand il reste moins de ce nombre de SMS (crédit AdaSMS)'),
  ('sms_credit_reminder_hours', 24, 'Rappel (heures) tant que le crédit SMS reste bas ou que la clé AdaSMS est refusée')
ON CONFLICT (key) DO NOTHING;

-- 2. Controle des reglages (reprend la version 079 de validate_app_setting, ajouts en fin)
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
  -- Migration 082 (lot 2, B5) : alerte de credit SMS bas
  IF NEW.key = 'sms_credit_check_enabled' AND NEW.value NOT IN (0, 1) THEN
    RAISE EXCEPTION 'reglage_invalide: surveillance du crédit SMS : 1 (activée) ou 0 (arrêtée)' USING ERRCODE = '22023';
  END IF;
  IF NEW.key = 'sms_credit_alert_threshold' THEN
    IF NEW.value < 1 OR NEW.value > 100000 OR NEW.value <> trunc(NEW.value) THEN
      RAISE EXCEPTION 'reglage_invalide: le seuil d''alerte doit être un nombre entier de SMS, de 1 à 100000' USING ERRCODE = '22023';
    END IF;
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'sms_credit_critical_threshold';
    IF v_other IS NOT NULL AND NEW.value <= v_other THEN
      RAISE EXCEPTION 'reglage_invalide: le seuil d''alerte (% SMS) doit être supérieur au seuil critique (% SMS)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  IF NEW.key = 'sms_credit_critical_threshold' THEN
    IF NEW.value > 100000 OR NEW.value <> trunc(NEW.value) THEN
      RAISE EXCEPTION 'reglage_invalide: le seuil critique doit être un nombre entier de SMS, de 0 à 100000' USING ERRCODE = '22023';
    END IF;
    SELECT s.value INTO v_other FROM app_settings s WHERE s.key = 'sms_credit_alert_threshold';
    IF v_other IS NOT NULL AND NEW.value >= v_other THEN
      RAISE EXCEPTION 'reglage_invalide: le seuil critique (% SMS) doit être inférieur au seuil d''alerte (% SMS)',
        trim_scale(NEW.value), trim_scale(v_other) USING ERRCODE = '22023';
    END IF;
  END IF;
  IF NEW.key = 'sms_credit_reminder_hours' AND (NEW.value < 1 OR NEW.value > 168) THEN
    RAISE EXCEPTION 'reglage_invalide: le rappel doit revenir toutes les 1 à 168 heures' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$function$;


-- 3. Etat du credit SMS (une seule ligne), lisible par l'administrateur seul
CREATE TABLE IF NOT EXISTS public.sms_credit_state (
  id                    smallint PRIMARY KEY DEFAULT 1,
  checked_at            timestamptz,
  ok_at                 timestamptz,
  sms_remaining         integer,
  balance_mad           numeric(12,4),
  unit_price_mad        numeric(10,4),
  currency              text,
  last_http_status      integer,
  last_error            text,
  consecutive_failures  integer NOT NULL DEFAULT 0,
  level                 smallint NOT NULL DEFAULT 0,
  low_alert_at          timestamptz,
  critical_alert_at     timestamptz,
  key_alert_at          timestamptz,
  failure_alert_at      timestamptz,
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sms_credit_state_single_row CHECK (id = 1),
  -- niveau : 0 = normal, 1 = bas, 2 = critique
  CONSTRAINT sms_credit_state_level_check CHECK (level IN (0, 1, 2)),
  CONSTRAINT sms_credit_state_error_check CHECK (last_error IS NULL OR char_length(last_error) <= 300)
);
INSERT INTO public.sms_credit_state (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.sms_credit_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sms_credit_state FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.sms_credit_state TO authenticated;
DROP POLICY IF EXISTS sms_credit_state_select_admin ON public.sms_credit_state;
CREATE POLICY sms_credit_state_select_admin ON public.sms_credit_state
  FOR SELECT TO authenticated USING (public.get_my_role() = 'admin');

-- 4. Compte rendu d'une lecture du solde (appele par check-sms-credit, cle serveur)
--    p_http_status : statut HTTP de la reponse AdaSMS (0 = pas de reponse)
--    p_sms_remaining : SMS restants (NULL si la reponse est inexploitable)
--    p_error : 'cle_absente' si la cle AdaSMS n'est pas configuree
CREATE OR REPLACE FUNCTION public.report_sms_credit(
  p_http_status integer,
  p_sms_remaining integer,
  p_balance numeric,
  p_unit_price numeric,
  p_currency text,
  p_error text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_alert    integer := greatest(public.app_setting_value('sms_credit_alert_threshold', 100), 1)::int;
  v_critical integer := greatest(public.app_setting_value('sms_credit_critical_threshold', 30), 0)::int;
  v_hours    numeric := greatest(public.app_setting_value('sms_credit_reminder_hours', 24), 1);
  v_s        public.sms_credit_state%ROWTYPE;
  v_level    smallint;
  v_title    text := NULL;
  v_body     text := NULL;
  v_kind     text := NULL;
  v_sent     integer := 0;
  v_error    text := left(p_error, 300);
BEGIN
  INSERT INTO sms_credit_state (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
  SELECT * INTO v_s FROM sms_credit_state WHERE id = 1 FOR UPDATE;

  IF p_http_status = 200 AND p_sms_remaining IS NOT NULL THEN
    -- Lecture reussie
    v_level := CASE WHEN p_sms_remaining < v_critical THEN 2
                    WHEN p_sms_remaining < v_alert THEN 1
                    ELSE 0 END;
    IF v_level < 2 THEN
      -- Credit revenu au-dessus du seuil critique : l'alerte urgente se rearme
      v_s.critical_alert_at := NULL;
    END IF;
    IF v_level = 0 THEN
      -- Credit revenu au-dessus du seuil : les alertes se rearment
      v_s.low_alert_at := NULL;
      v_s.critical_alert_at := NULL;
    ELSIF v_level = 2 AND v_s.critical_alert_at IS NULL THEN
      v_kind := 'critical';
      v_title := '🔴 Crédit SMS presque épuisé';
      v_body := 'Il reste ' || p_sms_remaining || ' SMS sur le compte AdaSMS. Rechargez maintenant : '
             || 'sans crédit, les codes de connexion ne partent plus.';
      v_s.critical_alert_at := now();
      v_s.low_alert_at := now();
    ELSIF v_s.low_alert_at IS NULL OR v_s.low_alert_at <= now() - make_interval(secs => v_hours * 3600) THEN
      v_kind := CASE WHEN v_s.low_alert_at IS NULL THEN 'low' ELSE 'reminder' END;
      v_title := CASE WHEN v_level = 2 THEN '🔴 Crédit SMS presque épuisé' ELSE '🟠 Crédit SMS bas' END;
      v_body := 'Il reste ' || p_sms_remaining || ' SMS sur le compte AdaSMS. Pensez à recharger '
             || 'pour que les codes de connexion continuent de partir.';
      v_s.low_alert_at := now();
    END IF;
    UPDATE sms_credit_state SET
      checked_at = now(), ok_at = now(), sms_remaining = p_sms_remaining,
      balance_mad = p_balance, unit_price_mad = p_unit_price, currency = left(p_currency, 10),
      last_http_status = p_http_status, last_error = NULL, consecutive_failures = 0,
      level = v_level, low_alert_at = v_s.low_alert_at, critical_alert_at = v_s.critical_alert_at,
      key_alert_at = NULL, failure_alert_at = NULL, updated_at = now()
    WHERE id = 1;

  ELSIF p_http_status IN (401, 403) OR p_error = 'cle_absente' THEN
    -- Cle refusee ou absente : les SMS de connexion sont menaces
    IF v_s.key_alert_at IS NULL OR v_s.key_alert_at <= now() - interval '24 hours' THEN
      v_kind := 'key';
      v_title := '🔴 AdaSMS refuse la clé d''accès';
      v_body := 'La lecture du crédit SMS a échoué (' || CASE WHEN p_error = 'cle_absente' THEN 'clé absente'
             ELSE 'erreur ' || p_http_status END || '). Les codes de connexion risquent de ne plus partir : '
             || 'vérifiez le compte et la clé AdaSMS.';
      v_s.key_alert_at := now();
    END IF;
    UPDATE sms_credit_state SET
      checked_at = now(), last_http_status = p_http_status, last_error = v_error,
      consecutive_failures = v_s.consecutive_failures + 1, key_alert_at = v_s.key_alert_at,
      updated_at = now()
    WHERE id = 1;

  ELSE
    -- Autre echec (reseau, panne, reponse illisible, trop d'appels)
    v_s.consecutive_failures := v_s.consecutive_failures + 1;
    IF v_s.consecutive_failures >= 3 AND v_s.failure_alert_at IS NULL THEN
      v_kind := 'failure';
      v_title := '🟠 Crédit SMS illisible';
      v_body := 'Le solde du compte AdaSMS n''a pas pu être lu ' || v_s.consecutive_failures
             || ' fois de suite. Vérifiez le compte AdaSMS.';
      v_s.failure_alert_at := now();
    END IF;
    UPDATE sms_credit_state SET
      checked_at = now(), last_http_status = p_http_status, last_error = v_error,
      consecutive_failures = v_s.consecutive_failures, failure_alert_at = v_s.failure_alert_at,
      updated_at = now()
    WHERE id = 1;
  END IF;

  IF v_kind IS NOT NULL THEN
    INSERT INTO notifications (profile_id, type, title, body, data, is_read)
    SELECT p.id, 'sms_credit_alert', v_title, v_body,
           jsonb_build_object('kind', v_kind, 'sms_remaining', p_sms_remaining, 'screen', 'AdminSettingsScreen'),
           false
    FROM profiles p
    WHERE p.role = 'admin' AND coalesce(p.is_active, true);
    GET DIAGNOSTICS v_sent = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object('alert', v_kind, 'notified', v_sent,
                            'level', (SELECT level FROM sms_credit_state WHERE id = 1));
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.report_sms_credit(integer, integer, numeric, numeric, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.report_sms_credit(integer, integer, numeric, numeric, text, text) TO service_role;

-- 5. Lecture horaire (minute 17), seulement si la surveillance est activee
SELECT cron.unschedule('check-sms-credit')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-sms-credit');
SELECT cron.schedule(
  'check-sms-credit',
  '17 * * * *',
  $$
    SELECT net.http_post(
      url := 'https://ustckqnecsilxqlyjute.supabase.co/functions/v1/check-sms-credit',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_service_role_key' LIMIT 1)
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    )
    WHERE public.app_setting_value('sms_credit_check_enabled', 1) = 1;
  $$
);
