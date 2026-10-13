-- Rollback de la migration 20260504000049 (volet 5, lot D-bis etape 1)
-- Retablit l'etat anterieur, failles comprises : a n'utiliser qu'en cas de blocage.

GRANT ALL ON public.notifications, public.ecommerce_parcels, public.push_tokens,
  public.public_parcel_tracking TO anon, authenticated;

DROP FUNCTION IF EXISTS public.get_public_parcel_tracking(text);
CREATE POLICY "parcels_select_tracking_public"
    ON public.ecommerce_parcels FOR SELECT
    USING (tracking_number IS NOT NULL);

DROP POLICY IF EXISTS "notifications_insert_related" ON public.notifications;
DROP FUNCTION IF EXISTS public.can_notify_profile(uuid);
CREATE POLICY "notifications_insert_service"
    ON public.notifications FOR INSERT
    WITH CHECK (true);
CREATE POLICY "notifications_insert_authenticated"
    ON public.notifications FOR INSERT
    TO authenticated
    WITH CHECK (true);
