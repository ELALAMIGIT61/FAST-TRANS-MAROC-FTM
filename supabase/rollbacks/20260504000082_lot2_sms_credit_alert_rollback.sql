-- Rollback de la migration 20260504000082 (lot 2, alerte de credit SMS bas).
-- A executer seulement sur decision du porteur. Ne pas placer dans migrations/.
-- Arrete la lecture horaire, supprime l'etat du credit, la fonction et les
-- 4 reglages, et remet validate_app_setting dans sa version 079.
-- Les notifications deja envoyees aux administrateurs sont conservees.

SELECT cron.unschedule('check-sms-credit')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-sms-credit');

DROP FUNCTION IF EXISTS public.report_sms_credit(integer, integer, numeric, numeric, text, text);
DROP TABLE IF EXISTS public.sms_credit_state;

DELETE FROM public.app_settings
WHERE key IN ('sms_credit_check_enabled', 'sms_credit_alert_threshold',
              'sms_credit_critical_threshold', 'sms_credit_reminder_hours');

-- validate_app_setting : version de la migration 079
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

