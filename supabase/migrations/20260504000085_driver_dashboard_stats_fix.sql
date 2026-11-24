-- Migration 085 : statistiques justes de l'ecran « Mon Wallet » du chauffeur
-- (decision du porteur le 24/11/2026 : corriger le calcul, et afficher a la
--  fois les missions en cours et les missions realisees ce mois)
--
-- Avant : la vue driver_dashboard (migration 014) associait chaque mission du
-- chauffeur a chacune de ses transactions. Chaque transaction etait donc
-- comptee autant de fois que le chauffeur avait de missions (recharges et
-- commissions du mois multipliees), et chaque mission autant de fois qu'il
-- avait de transactions.
-- Apres : missions et transactions sont comptees separement, une seule fois.
-- De plus, une demande de recharge validee laisse une ligne de trace « Demande
-- validée » (sans effet sur le solde) en plus de la ligne de credit : seule la
-- ligne qui a reellement credite le solde est comptee dans les recharges.
-- Les colonnes existantes sont gardees, dans le meme ordre, avec le meme sens
-- (l'ancienne version de l'application continue de fonctionner). Deux colonnes
-- sont ajoutees a la fin :
--   ongoing_missions                 : missions conclues pas encore terminees
--                                      (« conclue » ou « en cours »)
--   completed_missions_current_month : missions terminees pendant le mois en cours
-- Protections de la migration 017 conservees : security_invoker, pas d'acces anonyme.

CREATE OR REPLACE VIEW public.driver_dashboard
WITH (security_invoker = true) AS
SELECT
    d.id AS driver_id,
    p.full_name,
    d.vehicle_category,
    d.rating_average,
    d.total_missions,
    d.total_reviews,
    w.balance AS wallet_balance,
    w.total_earned,
    w.total_commissions,
    d.is_available,
    d.is_verified,
    coalesce(ms.pending_missions, 0)  AS pending_missions,
    coalesce(ms.active_missions, 0)   AS active_missions,
    w.id AS wallet_id,
    w.minimum_balance,
    w.balance < w.minimum_balance AS is_wallet_blocked,
    coalesce(ts.commissions_current_month, 0) AS commissions_current_month,
    coalesce(ts.recharges_current_month, 0)   AS recharges_current_month,
    coalesce(ms.ongoing_missions, 0)                 AS ongoing_missions,
    coalesce(ms.completed_missions_current_month, 0) AS completed_missions_current_month
FROM public.drivers d
JOIN public.profiles p ON p.id = d.profile_id
LEFT JOIN public.wallet w ON w.driver_id = d.id
LEFT JOIN LATERAL (
    SELECT
        count(*) FILTER (WHERE m.status = 'pending')     AS pending_missions,
        count(*) FILTER (WHERE m.status = 'in_progress') AS active_missions,
        count(*) FILTER (WHERE m.status IN ('accepted', 'in_progress')) AS ongoing_missions,
        count(*) FILTER (WHERE m.status = 'completed'
                           AND date_trunc('month', m.completed_at) = date_trunc('month', now()))
                                                         AS completed_missions_current_month
    FROM public.missions m
    WHERE m.driver_id = d.id
) ms ON true
LEFT JOIN LATERAL (
    SELECT
        sum(t.amount) FILTER (WHERE t.transaction_type = 'commission' AND t.status = 'completed'
                                AND date_trunc('month', t.created_at) = date_trunc('month', now()))
                                                         AS commissions_current_month,
        sum(t.amount) FILTER (WHERE t.transaction_type = 'topup' AND t.status = 'completed'
                                AND t.balance_after IS DISTINCT FROM t.balance_before
                                AND date_trunc('month', t.created_at) = date_trunc('month', now()))
                                                         AS recharges_current_month
    FROM public.transactions t
    WHERE t.wallet_id = w.id
) ts ON true;

REVOKE ALL ON public.driver_dashboard FROM anon;
