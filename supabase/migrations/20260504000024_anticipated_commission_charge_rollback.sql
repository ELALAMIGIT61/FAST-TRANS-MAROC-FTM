-- Rollback de la migration 20260504000024
-- A executer manuellement en cas de necessite de revenir en arriere.

DROP FUNCTION IF EXISTS charge_commission_anticipated(UUID);

CREATE OR REPLACE FUNCTION process_commission_payment()
RETURNS TRIGGER AS $$
DECLARE
    driver_wallet_id UUID;
    current_balance DECIMAL(10,2);
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        SELECT w.id, w.balance INTO driver_wallet_id, current_balance
        FROM wallet w
        INNER JOIN drivers d ON d.id = w.driver_id
        WHERE d.id = NEW.driver_id;

        IF driver_wallet_id IS NOT NULL THEN
            UPDATE wallet
            SET balance = balance - NEW.commission_amount,
                total_commissions = total_commissions + NEW.commission_amount
            WHERE id = driver_wallet_id;

            INSERT INTO transactions (
                wallet_id, mission_id, transaction_type, amount,
                balance_before, balance_after, status, description, processed_at
            ) VALUES (
                driver_wallet_id, NEW.id, 'commission', NEW.commission_amount,
                current_balance, current_balance - NEW.commission_amount,
                'completed', 'Commission pour mission ' || NEW.mission_number, NOW()
            );

            UPDATE drivers
            SET total_missions = total_missions + 1
            WHERE id = NEW.driver_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE missions DROP COLUMN IF EXISTS commission_charged_at;
