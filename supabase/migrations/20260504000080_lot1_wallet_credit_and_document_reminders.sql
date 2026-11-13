-- Migration 20260504000080 - lot 1 (portefeuille et documents)
-- (lot valide par le porteur le 13/11/2026 ; aucun fichier protege modifie,
--  la policy wallet_update_admin et driverService.ts restent inchanges)
--
-- B2. Credit du portefeuille en une seule operation indivisible.
--     Avant : l'application lisait le solde, calculait le nouveau solde, puis le
--     reecrivait. Un prelevement de commission fait par le serveur entre la lecture
--     et l'ecriture etait efface. Desormais, la fonction admin_credit_wallet ajoute
--     le montant au solde reellement present (balance = balance + montant) et
--     enregistre la transaction dans la meme operation : tout ou rien.
-- B3. Validation d'une demande (recharge ou remboursement) en une seule operation :
--     la demande passe de « en attente » a « validee » avec sa date de traitement
--     (processed_at), puis le portefeuille est credite. Un second clic ne trouve
--     plus de demande en attente et ne credite rien.
-- B1. Rappels d'expiration des documents tenus a jour par le serveur, pour les
--     4 documents (permis, carte grise, assurance, visite technique) : a chaque
--     enregistrement ou changement d'une date d'expiration dans la fiche du
--     chauffeur, son rappel est recalcule. Une nouvelle date remet les rappels a
--     zero ; les paliers deja depasses (J-30, J-15) sont marques comme faits, pour
--     n'envoyer qu'un seul rappel. Un document sans date n'a pas de rappel.
--     Les rappels des chauffeurs existants sont recalcules une fois.

-- B2. Credit du portefeuille (administrateur seulement)
CREATE OR REPLACE FUNCTION public.admin_credit_wallet(
  p_wallet_id   uuid,
  p_amount      numeric,
  p_type        public.transaction_type,
  p_mission_id  uuid  DEFAULT NULL,
  p_description text  DEFAULT NULL,
  p_metadata    jsonb DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_after numeric;
  v_tx    uuid;
BEGIN
  IF public.get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'acces_refuse: opération réservée à l''administrateur.';
  END IF;
  IF p_type NOT IN ('topup', 'refund') THEN
    RAISE EXCEPTION 'operation_invalide: seule une recharge ou un remboursement peut créditer le portefeuille.';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'montant_invalide: le montant doit être supérieur à 0.';
  END IF;
  IF p_type = 'topup' AND p_amount < 100 THEN
    RAISE EXCEPTION 'montant_invalide: Recharge minimum : 100 DH';
  END IF;

  UPDATE public.wallet
     SET balance = balance + p_amount
   WHERE id = p_wallet_id
  RETURNING balance INTO v_after;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'portefeuille_introuvable: portefeuille inconnu.';
  END IF;

  INSERT INTO public.transactions (
    wallet_id, mission_id, transaction_type, amount, balance_before, balance_after,
    status, description, metadata, processed_at
  ) VALUES (
    p_wallet_id, p_mission_id, p_type, p_amount, v_after - p_amount, v_after,
    'completed', p_description, p_metadata, now()
  )
  RETURNING id INTO v_tx;

  RETURN jsonb_build_object(
    'transaction_id', v_tx,
    'balance_before', v_after - p_amount,
    'balance_after',  v_after
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_credit_wallet(uuid, numeric, public.transaction_type, uuid, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_credit_wallet(uuid, numeric, public.transaction_type, uuid, text, jsonb) TO authenticated, service_role;

-- B3. Validation d'une demande en attente (administrateur seulement)
CREATE OR REPLACE FUNCTION public.admin_validate_pending_transaction(p_transaction_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_req    record;
  v_note   text;
  v_credit jsonb;
BEGIN
  IF public.get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'acces_refuse: opération réservée à l''administrateur.';
  END IF;

  UPDATE public.transactions
     SET status       = 'completed',
         description  = 'Demande validee -- creditee via nouvelle transaction',
         processed_at = now()
   WHERE id = p_transaction_id
     AND status = 'pending'
     AND transaction_type IN ('topup', 'refund')
  RETURNING id, wallet_id, transaction_type, amount, mission_id, metadata INTO v_req;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'deja_traitee: Cette transaction a déjà été traitée.';
  END IF;

  v_note := coalesce(nullif(v_req.metadata ->> 'note', ''), 'Demande validee');

  IF v_req.transaction_type = 'refund' THEN
    v_credit := public.admin_credit_wallet(
      v_req.wallet_id, v_req.amount, 'refund', v_req.mission_id,
      'Remboursement — ' || v_note,
      jsonb_build_object('reason', v_note, 'initiated_by', 'admin', 'request_id', v_req.id));
  ELSE
    v_credit := public.admin_credit_wallet(
      v_req.wallet_id, v_req.amount, 'topup', NULL,
      'Recharge wallet — Réf: ' || v_note,
      jsonb_build_object('agent_ref', v_note, 'payment_method', 'cash_agent', 'request_id', v_req.id));
  END IF;

  RETURN v_credit || jsonb_build_object(
    'wallet_id',        v_req.wallet_id,
    'transaction_type', v_req.transaction_type,
    'amount',           v_req.amount
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_validate_pending_transaction(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_validate_pending_transaction(uuid) TO authenticated, service_role;

-- B1. Rappels d'expiration tenus a jour par le serveur
CREATE OR REPLACE FUNCTION public.upsert_document_reminder(
  p_driver_id uuid, p_document_type text, p_expiry date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_days integer;
BEGIN
  IF p_expiry IS NULL THEN
    DELETE FROM public.document_reminders
     WHERE driver_id = p_driver_id AND document_type = p_document_type;
    RETURN;
  END IF;
  v_days := p_expiry - current_date;
  INSERT INTO public.document_reminders (
    driver_id, document_type, expiry_date,
    reminder_30_days_sent, reminder_15_days_sent, reminder_7_days_sent
  ) VALUES (
    p_driver_id, p_document_type, p_expiry,
    v_days <= 15, v_days <= 7, false
  )
  ON CONFLICT (driver_id, document_type) DO UPDATE
    SET expiry_date           = EXCLUDED.expiry_date,
        reminder_30_days_sent = EXCLUDED.reminder_30_days_sent,
        reminder_15_days_sent = EXCLUDED.reminder_15_days_sent,
        reminder_7_days_sent  = EXCLUDED.reminder_7_days_sent
    WHERE public.document_reminders.expiry_date IS DISTINCT FROM EXCLUDED.expiry_date;
END;
$function$;

REVOKE ALL ON FUNCTION public.upsert_document_reminder(uuid, text, date) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.sync_document_reminders()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.driver_license_expiry IS DISTINCT FROM OLD.driver_license_expiry THEN
    PERFORM public.upsert_document_reminder(NEW.id, 'driver_license', NEW.driver_license_expiry);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.vehicle_registration_expiry IS DISTINCT FROM OLD.vehicle_registration_expiry THEN
    PERFORM public.upsert_document_reminder(NEW.id, 'vehicle_registration', NEW.vehicle_registration_expiry);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.insurance_expiry IS DISTINCT FROM OLD.insurance_expiry THEN
    PERFORM public.upsert_document_reminder(NEW.id, 'insurance', NEW.insurance_expiry);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.technical_inspection_expiry IS DISTINCT FROM OLD.technical_inspection_expiry THEN
    PERFORM public.upsert_document_reminder(NEW.id, 'technical_inspection', NEW.technical_inspection_expiry);
  END IF;
  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.sync_document_reminders() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS sync_document_reminders ON public.drivers;
CREATE TRIGGER sync_document_reminders
  AFTER INSERT OR UPDATE OF driver_license_expiry, vehicle_registration_expiry,
                            insurance_expiry, technical_inspection_expiry
  ON public.drivers
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_document_reminders();

-- Recalcul unique pour les chauffeurs existants
DO $$
DECLARE d record;
BEGIN
  FOR d IN SELECT id, driver_license_expiry, vehicle_registration_expiry,
                  insurance_expiry, technical_inspection_expiry
             FROM public.drivers LOOP
    PERFORM public.upsert_document_reminder(d.id, 'driver_license',       d.driver_license_expiry);
    PERFORM public.upsert_document_reminder(d.id, 'vehicle_registration', d.vehicle_registration_expiry);
    PERFORM public.upsert_document_reminder(d.id, 'insurance',            d.insurance_expiry);
    PERFORM public.upsert_document_reminder(d.id, 'technical_inspection', d.technical_inspection_expiry);
  END LOOP;
END $$;
