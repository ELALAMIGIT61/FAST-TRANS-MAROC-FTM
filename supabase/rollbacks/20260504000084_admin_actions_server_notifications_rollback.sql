-- Retour arriere de la migration 20260504000084 (actions de l'administrateur et
-- notifications faites par le serveur) : retire les fonctions ajoutees et remet la
-- fonction de validation des demandes dans son etat de la migration 080.
-- A n'utiliser qu'avec le retour a l'ancienne version de l'application de
-- l'administrateur (sinon les actions de l'administrateur ne fonctionnent plus).
-- La correction des accents dans l'historique n'est pas annulee (texte seulement).
DROP FUNCTION IF EXISTS public.admin_reject_pending_transaction(uuid, text);
DROP FUNCTION IF EXISTS public.admin_verify_document(uuid, text);
DROP FUNCTION IF EXISTS public.admin_reject_document(uuid, text, text);
DROP FUNCTION IF EXISTS public.admin_confirm_bank_reconciliation(uuid);
DROP FUNCTION IF EXISTS public.admin_set_document_status(uuid, text, public.verification_status);
DROP FUNCTION IF EXISTS public.document_label(text);

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

DROP FUNCTION IF EXISTS public.notify_wallet_owner(uuid, text, text, text, jsonb);
