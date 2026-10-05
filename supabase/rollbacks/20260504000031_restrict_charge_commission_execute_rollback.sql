-- Rollback 20260504000031
-- Reaccorde l'execution a PUBLIC (etat d'avant cette migration).
-- La securite interne de la fonction (controle de l'appelant) reste en place,
-- donc ce rollback ne reouvre pas a lui seul une faille d'execution par un tiers.

GRANT EXECUTE ON FUNCTION public.charge_commission_anticipated(uuid) TO PUBLIC;
