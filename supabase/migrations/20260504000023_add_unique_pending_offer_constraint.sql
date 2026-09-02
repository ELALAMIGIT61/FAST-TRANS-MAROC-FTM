-- Migration 20260504000023
-- Empêche un même chauffeur d'avoir plusieurs offres actives (pending)
-- simultanément sur une même mission, sans interdire structurellement
-- qu'un chauffeur écarté (not_selected) puisse un jour refaire une offre
-- si la mission redevenait disponible (cas non tranché, non bloqué).

CREATE UNIQUE INDEX mission_offers_unique_pending_offer_per_driver
  ON public.mission_offers (mission_id, driver_id)
  WHERE status = 'pending';
