-- Retour arriere de la migration 20260504000083 (controle de la suspension des
-- clients et du numero d'assurance) : retire les triggers et les fonctions
-- ajoutes ; aucune autre regle ni donnee n'est modifiee.
DROP TRIGGER IF EXISTS a_block_suspended_client ON public.missions;
DROP TRIGGER IF EXISTS a_block_suspended_client ON public.mission_offers;
DROP TRIGGER IF EXISTS a_block_suspended_client ON public.ecommerce_parcels;
DROP FUNCTION IF EXISTS public.block_suspended_client();
DROP FUNCTION IF EXISTS public.current_client_is_suspended();
DROP TRIGGER IF EXISTS protect_driver_insurance_number ON public.drivers;
DROP FUNCTION IF EXISTS public.insurance_number_requires_validation();
