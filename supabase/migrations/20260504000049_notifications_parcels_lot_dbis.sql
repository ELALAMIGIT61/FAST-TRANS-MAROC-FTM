-- Migration 20260504000049 - volet 5, lot D-bis etape 1 : notifications, colis, droits
-- (decision du porteur du 13/10/2026 : lot D-bis, option (a))
--
-- Constat (13/10/2026) :
--  - deux regles d'ecriture sur notifications acceptaient tout (WITH CHECK true),
--    l'une ouverte a tous les roles : n'importe qui pouvait deposer une
--    notification au texte libre chez n'importe quel utilisateur ;
--  - la regle parcels_select_tracking_public rendait tous les colis lisibles par
--    tous, sans connexion (noms, telephones complets, contenus) ;
--  - la vue public_parcel_tracking pouvait etre listee en entier ;
--  - anon disposait de tous les droits techniques sur ces tables.
--
-- D2. Fonction can_notify_profile(cible) : vrai si l'appelant connecte
--     (a) se notifie lui-meme, (b) est administrateur, (c) est le client ou le
--     chauffeur d'une meme mission ou d'une meme offre que la cible.
--     Elle remplace les deux regles d'ecriture et servira aussi a la fonction
--     serveur send-push-notification (etape 2).
-- D6. Suppression de parcels_select_tracking_public ; le suivi public passe par
--     get_public_parcel_tracking(numero), qui ne renvoie que le colis demande ;
--     la vue n'est plus lisible directement.
-- Menage des droits : anon perd INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER,
--     REFERENCES sur notifications, ecommerce_parcels, push_tokens ;
--     authenticated perd TRUNCATE, TRIGGER, REFERENCES (et DELETE sur les colis,
--     aucune regle ne l'autorise) ; anon et authenticated perdent tout droit
--     direct sur la vue public_parcel_tracking.
-- Les fonctions serveur utilisent la cle de service et ne sont pas concernees.

-- D2
CREATE OR REPLACE FUNCTION public.can_notify_profile(p_target uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH me AS (
    SELECT p.id FROM profiles p WHERE p.user_id = auth.uid()
  )
  SELECT p_target IS NOT NULL AND auth.uid() IS NOT NULL AND (
    -- (a) soi-meme
    p_target IN (SELECT id FROM me)
    -- (b) administrateur
    OR EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin')
    -- (c) client et chauffeur d'une meme mission
    OR EXISTS (
      SELECT 1 FROM missions m JOIN drivers d ON d.id = m.driver_id
      WHERE (m.client_id IN (SELECT id FROM me) AND d.profile_id = p_target)
         OR (m.client_id = p_target AND d.profile_id IN (SELECT id FROM me))
    )
    -- (c) client et chauffeur d'une meme offre
    OR EXISTS (
      SELECT 1 FROM mission_offers o
      JOIN missions m ON m.id = o.mission_id
      JOIN drivers d ON d.id = o.driver_id
      WHERE (m.client_id IN (SELECT id FROM me) AND d.profile_id = p_target)
         OR (m.client_id = p_target AND d.profile_id IN (SELECT id FROM me))
    )
  );
$function$;

REVOKE EXECUTE ON FUNCTION public.can_notify_profile(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_notify_profile(uuid) TO authenticated;

DROP POLICY IF EXISTS "notifications_insert_service" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert_authenticated" ON public.notifications;
CREATE POLICY "notifications_insert_related"
    ON public.notifications FOR INSERT
    TO authenticated
    WITH CHECK (public.can_notify_profile(profile_id));

-- D6
DROP POLICY IF EXISTS "parcels_select_tracking_public" ON public.ecommerce_parcels;

CREATE OR REPLACE FUNCTION public.get_public_parcel_tracking(p_tracking_number text)
RETURNS SETOF public.public_parcel_tracking
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT * FROM public_parcel_tracking
  WHERE tracking_number = upper(trim(p_tracking_number))
  LIMIT 1;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_public_parcel_tracking(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_parcel_tracking(text) TO anon, authenticated;

-- Menage des droits
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES
  ON public.notifications, public.ecommerce_parcels, public.push_tokens FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES
  ON public.notifications, public.ecommerce_parcels, public.push_tokens FROM authenticated;
REVOKE DELETE ON public.ecommerce_parcels FROM authenticated;
REVOKE ALL ON public.public_parcel_tracking FROM anon, authenticated;
