-- Migration 20260504000029 - Volet 1 securite : protection financiere des missions
-- 1. Retrait du droit de modifier les colonnes financieres aux utilisateurs ordinaires
-- 2. Contraintes anti-valeurs negatives (commission_amount, negotiated_price)
-- 3. Securisation de charge_commission_anticipated (appelant + statut + search_path)
-- 4. Retrait de l'execution de charge_commission_anticipated au role anon
-- 5. Suppression de la policy UPDATE en doublon sur missions

REVOKE UPDATE (commission_amount, commission_charged_at) ON public.missions FROM anon;
REVOKE UPDATE (commission_amount, commission_charged_at) ON public.missions FROM authenticated;

ALTER TABLE public.missions
  ADD CONSTRAINT missions_commission_amount_non_negative
  CHECK (commission_amount IS NULL OR commission_amount >= 0);

ALTER TABLE public.missions
  ADD CONSTRAINT missions_negotiated_price_non_negative
  CHECK (negotiated_price IS NULL OR negotiated_price >= 0);

CREATE OR REPLACE FUNCTION public.charge_commission_anticipated(p_mission_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_mission RECORD;
  v_driver_wallet_id UUID;
  v_current_balance DECIMAL(10,2);
  v_caller_is_system BOOLEAN;
  v_caller_is_mission_driver BOOLEAN;
BEGIN
  v_caller_is_system := current_user NOT IN ('authenticated', 'anon');

  SELECT id, driver_id, commission_amount, mission_number, commission_charged_at, status
  INTO v_mission
  FROM missions WHERE id = p_mission_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'mission_not_found');
  END IF;

  IF NOT v_caller_is_system THEN
    SELECT EXISTS (
      SELECT 1 FROM drivers d
      JOIN profiles p ON p.id = d.profile_id
      WHERE d.id = v_mission.driver_id AND p.user_id = auth.uid()
    ) INTO v_caller_is_mission_driver;

    IF NOT v_caller_is_mission_driver THEN
      RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
    END IF;
  END IF;

  IF v_mission.status NOT IN ('accepted', 'in_progress') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status');
  END IF;

  IF v_mission.commission_charged_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_charged');
  END IF;

  IF v_mission.driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_driver_assigned');
  END IF;

  SELECT w.id, w.balance INTO v_driver_wallet_id, v_current_balance
  FROM wallet w WHERE w.driver_id = v_mission.driver_id;

  IF v_driver_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
  END IF;

  UPDATE wallet
  SET balance = balance - v_mission.commission_amount,
      total_commissions = total_commissions + v_mission.commission_amount
  WHERE id = v_driver_wallet_id;

  INSERT INTO transactions (
    wallet_id, mission_id, transaction_type, amount,
    balance_before, balance_after, status, description, processed_at
  ) VALUES (
    v_driver_wallet_id, p_mission_id, 'commission', v_mission.commission_amount,
    v_current_balance, v_current_balance - v_mission.commission_amount,
    'completed', 'Commission anticipee pour mission ' || v_mission.mission_number, NOW()
  );

  UPDATE missions SET commission_charged_at = NOW() WHERE id = p_mission_id;

  RETURN jsonb_build_object(
    'success', true,
    'balance_before', v_current_balance,
    'balance_after', v_current_balance - v_mission.commission_amount
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.charge_commission_anticipated(uuid) FROM anon;

DROP POLICY IF EXISTS "Users can update their own missions" ON public.missions;
