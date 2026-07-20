-- Rollback pour: 20260504000014_rename_revenue_to_recharges_driver_dashboard.sql
-- Restaure la version precedente de driver_dashboard (avec revenue_current_month)
-- ATTENTION: ce rollback SQL seul est insuffisant en cas de deploiement partiel.
-- Il faut aussi annuler en parallele le commit du code applicatif correspondant
-- (git revert), sous peine de desynchronisation entre la vue et le code
-- (WalletDashboardScreen.tsx chercherait alors une colonne qui n'existe plus).
DROP VIEW IF EXISTS driver_dashboard;
CREATE VIEW driver_dashboard AS
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
    COUNT(CASE WHEN m.status = 'pending' THEN 1 END) AS pending_missions,
    COUNT(CASE WHEN m.status = 'in_progress' THEN 1 END) AS active_missions,
    w.id AS wallet_id,
    w.minimum_balance,
    w.balance < w.minimum_balance AS is_wallet_blocked,
    COALESCE(SUM(CASE 
        WHEN t.transaction_type = 'commission' 
        AND t.status = 'completed'
        AND DATE_TRUNC('month', t.created_at) = DATE_TRUNC('month', NOW())
        THEN t.amount ELSE 0 END), 0) AS commissions_current_month,
    COALESCE(SUM(CASE 
        WHEN t.transaction_type = 'topup' 
        AND t.status = 'completed'
        AND DATE_TRUNC('month', t.created_at) = DATE_TRUNC('month', NOW())
        THEN t.amount ELSE 0 END), 0) AS revenue_current_month
FROM drivers d
INNER JOIN profiles p ON p.id = d.profile_id
LEFT JOIN wallet w ON w.driver_id = d.id
LEFT JOIN missions m ON m.driver_id = d.id
LEFT JOIN transactions t ON t.wallet_id = w.id
GROUP BY d.id, p.full_name, d.vehicle_category, d.rating_average,
         d.total_missions, d.total_reviews, w.id, w.balance,
         w.minimum_balance, w.total_earned, w.total_commissions,
         d.is_available, d.is_verified;
