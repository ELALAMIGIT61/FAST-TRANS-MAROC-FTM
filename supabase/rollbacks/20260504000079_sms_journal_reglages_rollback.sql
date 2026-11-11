-- Rollback de la migration 20260504000079 (option B, lot SMS-1 : journal des envois et reglages SMS).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Attention : le journal des envois de SMS est perdu.
-- A n'executer qu'apres avoir eteint le crochet « Send SMS » dans le tableau de bord
-- (la fonction send-sms a besoin de sms_routing_state et de sms_send_log).

SELECT cron.unschedule('purge-old-sms-log')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-old-sms-log');

DROP FUNCTION IF EXISTS public.purge_old_sms_log();
DROP FUNCTION IF EXISTS public.sms_routing_state(uuid);
DROP TABLE IF EXISTS public.sms_send_log;

DELETE FROM public.app_settings WHERE key IN (
  'sms_mode', 'sms_breaker_failures', 'sms_breaker_minutes', 'sms_timeout_primary_ms',
  'sms_timeout_with_fallback_ms', 'sms_resend_fallback_from', 'sms_resend_window_minutes',
  'sms_log_retention_months');

-- validate_app_setting : retour a la version de la migration 078
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
  RETURN NEW;
END;
$function$;
