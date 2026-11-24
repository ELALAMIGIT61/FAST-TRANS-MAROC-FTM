-- Migration 084 : actions de l'administrateur et notifications faites par le serveur
-- (approche validee par le porteur le 24/11/2026 : une fonction serveur par action ;
--  correction de l'accent « Demande validée », y compris dans l'historique existant)
--
-- Avant : l'application de l'administrateur faisait l'action, puis envoyait la
-- notification au chauffeur. Si elle plantait entre les deux, le chauffeur n'etait
-- pas prevenu (constate le 20/11/2026 sur une recharge de 100 DH).
-- Apres : chaque action est une seule operation du serveur, qui fait l'action ET
-- cree la notification ; soit tout est fait, soit rien.
--   1. admin_validate_pending_transaction (existante) : cree aussi « Demande validée »
--   2. admin_reject_pending_transaction (nouvelle)    : rejet + « Demande rejetée »
--   3. admin_verify_document (nouvelle)               : validation + « Document validé »
--                                                       (+ « Dossier complet validé »)
--   4. admin_reject_document (nouvelle)               : refus + « Document refusé »
--                                                       (+ chauffeur « Hors service »)
--   5. admin_confirm_bank_reconciliation (nouvelle)   : confirmation + « Paiement confirmé »
-- Les textes des notifications sont ceux de l'application, sans changement.
-- La sonnerie reste assuree par le declencheur de la migration 057.
-- Aucun fichier protege, aucune policy modifies.

-- 0. Notification d'un chauffeur a partir de son portefeuille (usage interne)
CREATE OR REPLACE FUNCTION public.notify_wallet_owner(
  p_wallet_id uuid, p_type text, p_title text, p_body text, p_data jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_profile uuid;
BEGIN
  SELECT d.profile_id INTO v_profile
    FROM public.wallet w JOIN public.drivers d ON d.id = w.driver_id
   WHERE w.id = p_wallet_id;
  IF v_profile IS NOT NULL THEN
    INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
    VALUES (v_profile, p_type, p_title, p_body, p_data, false);
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.notify_wallet_owner(uuid, text, text, text, jsonb) FROM PUBLIC, anon, authenticated;

-- 1. Validation d'une demande (recharge ou remboursement) : + notification, accents
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
         description  = 'Demande validée — créditée via nouvelle transaction',
         processed_at = now()
   WHERE id = p_transaction_id
     AND status = 'pending'
     AND transaction_type IN ('topup', 'refund')
  RETURNING id, wallet_id, transaction_type, amount, mission_id, metadata INTO v_req;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'deja_traitee: Cette transaction a déjà été traitée.';
  END IF;

  v_note := coalesce(nullif(v_req.metadata ->> 'note', ''), 'Demande validée');

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

  PERFORM public.notify_wallet_owner(
    v_req.wallet_id, 'transaction_validated', '✅ Demande validée',
    CASE WHEN v_req.transaction_type = 'refund' THEN 'Remboursement' ELSE 'Recharge' END
      || ' de ' || to_char(v_req.amount, 'FM999999990.00')
      || ' DH validée. Votre solde a été mis à jour.',
    jsonb_build_object('amount', v_req.amount, 'transactionType', v_req.transaction_type,
                       'screen', 'WalletDashboard'));

  RETURN v_credit || jsonb_build_object(
    'wallet_id',        v_req.wallet_id,
    'transaction_type', v_req.transaction_type,
    'amount',           v_req.amount
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_validate_pending_transaction(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_validate_pending_transaction(uuid) TO authenticated, service_role;

-- 2. Rejet d'une demande (meme resultat que l'ancienne modification directe)
CREATE OR REPLACE FUNCTION public.admin_reject_pending_transaction(
  p_transaction_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_reason text := btrim(coalesce(p_reason, ''));
  v_req    record;
BEGIN
  IF public.get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'acces_refuse: opération réservée à l''administrateur.';
  END IF;
  IF v_reason = '' THEN
    RAISE EXCEPTION 'motif_requis: Indiquez le motif du rejet.';
  END IF;

  UPDATE public.transactions
     SET status       = 'failed',
         description  = 'Rejetée : ' || v_reason,
         processed_at = now()
   WHERE id = p_transaction_id
     AND status = 'pending'
  RETURNING id, wallet_id, transaction_type, amount INTO v_req;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'deja_traitee: Cette transaction a déjà été traitée.';
  END IF;

  PERFORM public.notify_wallet_owner(
    v_req.wallet_id, 'transaction_rejected', '❌ Demande rejetée',
    CASE WHEN v_req.transaction_type = 'refund' THEN 'Remboursement' ELSE 'Recharge' END
      || ' de ' || to_char(v_req.amount, 'FM999999990.00')
      || ' DH rejetée. Motif : ' || v_reason,
    jsonb_build_object('amount', v_req.amount, 'transactionType', v_req.transaction_type,
                       'screen', 'WalletDashboard'));

  RETURN jsonb_build_object('wallet_id', v_req.wallet_id,
                            'transaction_type', v_req.transaction_type,
                            'amount', v_req.amount);
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_reject_pending_transaction(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_reject_pending_transaction(uuid, text) TO authenticated, service_role;

-- 3 et 4. Validation ou refus d'un document du chauffeur
CREATE OR REPLACE FUNCTION public.admin_set_document_status(
  p_driver_id uuid, p_document_type text, p_status public.verification_status)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_old  public.verification_status;
  v_was  boolean;
  v_now  boolean;
  v_prof uuid;
BEGIN
  IF p_document_type = 'driver_license' THEN
    SELECT driver_license_verified, is_verified INTO v_old, v_was FROM public.drivers WHERE id = p_driver_id FOR UPDATE;
  ELSIF p_document_type = 'vehicle_registration' THEN
    SELECT vehicle_registration_verified, is_verified INTO v_old, v_was FROM public.drivers WHERE id = p_driver_id FOR UPDATE;
  ELSIF p_document_type = 'insurance' THEN
    SELECT insurance_verified, is_verified INTO v_old, v_was FROM public.drivers WHERE id = p_driver_id FOR UPDATE;
  ELSIF p_document_type = 'technical_inspection' THEN
    SELECT technical_inspection_verified, is_verified INTO v_old, v_was FROM public.drivers WHERE id = p_driver_id FOR UPDATE;
  ELSE
    RAISE EXCEPTION 'type_inconnu: Type de document inconnu.';
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'chauffeur_introuvable: Chauffeur introuvable.';
  END IF;
  IF v_old = p_status THEN
    RAISE EXCEPTION 'deja_traite: Ce document a déjà été %.',
      CASE WHEN p_status = 'verified' THEN 'validé' ELSE 'refusé' END;
  END IF;

  UPDATE public.drivers SET
    driver_license_verified       = CASE WHEN p_document_type = 'driver_license'       THEN p_status ELSE driver_license_verified END,
    vehicle_registration_verified = CASE WHEN p_document_type = 'vehicle_registration' THEN p_status ELSE vehicle_registration_verified END,
    insurance_verified            = CASE WHEN p_document_type = 'insurance'            THEN p_status ELSE insurance_verified END,
    technical_inspection_verified = CASE WHEN p_document_type = 'technical_inspection' THEN p_status ELSE technical_inspection_verified END,
    -- Refus : le chauffeur passe « Hors service » (decision du porteur, 24/11/2026)
    is_available                  = CASE WHEN p_status = 'rejected' THEN false ELSE is_available END
   WHERE id = p_driver_id
  RETURNING is_verified, profile_id INTO v_now, v_prof;

  RETURN jsonb_build_object('profile_id', v_prof,
                            'is_fully_verified', coalesce(v_now, false),
                            'became_fully_verified', coalesce(v_now, false) AND NOT coalesce(v_was, false));
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_set_document_status(uuid, text, public.verification_status) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.document_label(p_document_type text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_document_type
    WHEN 'driver_license'       THEN 'Permis de conduire'
    WHEN 'vehicle_registration' THEN 'Carte grise'
    WHEN 'insurance'            THEN 'Assurance'
    WHEN 'technical_inspection' THEN 'Visite technique'
    ELSE p_document_type END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_verify_document(p_driver_id uuid, p_document_type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res jsonb;
  v_prof uuid;
BEGIN
  IF public.get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'acces_refuse: opération réservée à l''administrateur.';
  END IF;
  v_res  := public.admin_set_document_status(p_driver_id, p_document_type, 'verified');
  v_prof := (v_res ->> 'profile_id')::uuid;

  INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
  VALUES (v_prof, 'document_verified', '✅ Document validé',
          'Votre ' || public.document_label(p_document_type)
            || ' a été approuvé. Continuez à accepter des missions.',
          jsonb_build_object('document_type', p_document_type, 'screen', 'DocumentStatusScreen'),
          false);

  IF (v_res ->> 'became_fully_verified')::boolean THEN
    INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
    VALUES (v_prof, 'driver_fully_verified', '🎉 Dossier complet validé !',
            'Tous vos documents ont été approuvés. Activez votre disponibilité pour recevoir des missions.',
            jsonb_build_object('screen', 'DriverHomeStack'),
            false);
  END IF;

  RETURN jsonb_build_object('is_fully_verified', (v_res ->> 'is_fully_verified')::boolean);
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_verify_document(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_verify_document(uuid, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_reject_document(
  p_driver_id uuid, p_document_type text, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_reason text := btrim(coalesce(p_reason, ''));
  v_res    jsonb;
BEGIN
  IF public.get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'acces_refuse: opération réservée à l''administrateur.';
  END IF;
  IF v_reason = '' THEN
    RAISE EXCEPTION 'motif_requis: Veuillez saisir un motif de rejet.';
  END IF;
  v_res := public.admin_set_document_status(p_driver_id, p_document_type, 'rejected');

  INSERT INTO public.notifications (profile_id, type, title, body, data, is_read)
  VALUES ((v_res ->> 'profile_id')::uuid, 'document_rejected', '❌ Document refusé — Action requise',
          'Votre ' || public.document_label(p_document_type) || ' a été refusé : "'
            || v_reason || '". Re-uploadez un document valide.',
          jsonb_build_object('document_type', p_document_type, 'reason', v_reason,
                             'screen', 'DocumentStatusScreen'),
          false);

  RETURN jsonb_build_object('is_fully_verified', false);
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_reject_document(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_reject_document(uuid, text, text) TO authenticated, service_role;

-- 5. Confirmation d'un paiement apres verification bancaire
CREATE OR REPLACE FUNCTION public.admin_confirm_bank_reconciliation(p_transaction_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_tx record;
BEGIN
  IF public.get_my_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'acces_refuse: opération réservée à l''administrateur.';
  END IF;

  UPDATE public.transactions
     SET bank_reconciled_at = now()
   WHERE id = p_transaction_id
     AND status = 'completed'
     AND bank_reconciled_at IS NULL
  RETURNING wallet_id, transaction_type, amount INTO v_tx;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'deja_traitee: Ce paiement a déjà été confirmé.';
  END IF;

  PERFORM public.notify_wallet_owner(
    v_tx.wallet_id, 'transaction_bank_confirmed', '✅ Paiement confirmé',
    CASE WHEN v_tx.transaction_type = 'refund' THEN 'Remboursement' ELSE 'Recharge' END
      || ' de ' || to_char(v_tx.amount, 'FM999999990.00')
      || ' DH définitivement confirmée après vérification bancaire.',
    jsonb_build_object('amount', v_tx.amount, 'transactionType', v_tx.transaction_type,
                       'screen', 'WalletDashboard'));

  RETURN jsonb_build_object('wallet_id', v_tx.wallet_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_confirm_bank_reconciliation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_confirm_bank_reconciliation(uuid) TO authenticated, service_role;

-- 6. Correction de l'historique existant (accent « Demande validée »)
UPDATE public.transactions
   SET description = 'Demande validée — créditée via nouvelle transaction'
 WHERE description = 'Demande validee -- creditee via nouvelle transaction';

UPDATE public.transactions
   SET description = replace(description, 'Demande validee', 'Demande validée')
 WHERE description IN ('Remboursement — Demande validee', 'Recharge wallet — Réf: Demande validee');

UPDATE public.transactions
   SET metadata = jsonb_set(metadata, '{reason}', '"Demande validée"')
 WHERE metadata ->> 'reason' = 'Demande validee';

UPDATE public.transactions
   SET metadata = jsonb_set(metadata, '{agent_ref}', '"Demande validée"')
 WHERE metadata ->> 'agent_ref' = 'Demande validee';
