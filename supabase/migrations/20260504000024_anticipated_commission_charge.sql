-- Migration 20260504000024 -- Reforme du timing de commission (session 2.17)
-- Objectif : prelevement anticipe de la commission (24h avant scheduled_pickup_time,
-- ou immediat si delai court), au lieu du prelevement a la completion de la mission.
--
-- Conception (Option B, arbitrage porteur) : nouvelle colonne commission_charged_at
-- sur missions, tracant le moment reel du prelevement. La table transactions
-- continue de recevoir la ligne 'commission' exactement comme avant -- aucune
-- perte de tracabilite, uniquement un raccourci de consultation ajoute.
--
-- Le declenchement du prelevement anticipe est applicatif (verification periodique
-- cote client, sur le modele deja valide du canal vocal, session 2.14 septies,
-- meme delai de 24h). Cette migration fournit la fonction RPC appelee par le
-- code applicatif, avec garde-fou contre le double prelevement.
--
-- Le trigger existant (process_commission_payment, declenche a la completion)
-- est conserve comme FILET DE SECURITE : il ne se declenche desormais que si
-- commission_charged_at est encore NULL au moment de la completion -- c'est-a-dire
-- uniquement si le prelevement anticipe n'a jamais eu lieu. Aucune mission ne peut
-- ainsi se terminer sans prelevement, meme si le mecanisme applicatif n'a jamais
-- pu s'executer.

-- Etape 1 : nouvelle colonne
ALTER TABLE missions ADD COLUMN commission_charged_at TIMESTAMP WITH TIME ZONE;

-- Etape 2 : fonction RPC pour le prelevement anticipe, appelee par le code applicatif
CREATE OR REPLACE FUNCTION charge_commission_anticipated(p_mission_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_mission RECORD;
    v_driver_wallet_id UUID;
    v_current_balance DECIMAL(10,2);
BEGIN
    -- Verrouiller la ligne mission pour eviter une double execution concurrente
    SELECT id, driver_id, commission_amount, mission_number, commission_charged_at
    INTO v_mission
    FROM missions
    WHERE id = p_mission_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'mission_not_found');
    END IF;

    -- Garde-fou : deja preleve, ne rien refaire (idempotence)
    IF v_mission.commission_charged_at IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'already_charged');
    END IF;

    IF v_mission.driver_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'no_driver_assigned');
    END IF;

    SELECT w.id, w.balance INTO v_driver_wallet_id, v_current_balance
    FROM wallet w
    WHERE w.driver_id = v_mission.driver_id;

    IF v_driver_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
    END IF;

    -- Le CHECK (balance >= 0) rejettera cette operation si le solde est
    -- insuffisant -- comportement assume (voir Partie 1, objectif 2 : marge
    -- de securite 100 DH + blocage automatique deja existant juges suffisants,
    -- pas de gestion d'erreur specifique supplementaire construite ici).
    UPDATE wallet
    SET balance = balance - v_mission.commission_amount,
        total_commissions = total_commissions + v_mission.commission_amount
    WHERE id = v_driver_wallet_id;

    INSERT INTO transactions (
        wallet_id, mission_id, transaction_type, amount,
        balance_before, balance_after, status, description, processed_at
    ) VALUES (
        v_driver_wallet_id, p_mission_id, 'commission', v_mission.commission_amount,
        v_current_balance, v_current_balance - v_mission.commission_amount,
        'completed', 'Commission anticipee pour mission ' || v_mission.mission_number, NOW()
    );

    UPDATE missions SET commission_charged_at = NOW() WHERE id = p_mission_id;

    RETURN jsonb_build_object(
        'success', true,
        'balance_before', v_current_balance,
        'balance_after', v_current_balance - v_mission.commission_amount
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Etape 3 : trigger existant transforme en filet de securite
CREATE OR REPLACE FUNCTION process_commission_payment()
RETURNS TRIGGER AS $$
DECLARE
    driver_wallet_id UUID;
    current_balance DECIMAL(10,2);
BEGIN
    -- Ne se declenche desormais que si le prelevement anticipe n'a jamais eu lieu
    IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.commission_charged_at IS NULL THEN
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

            UPDATE missions SET commission_charged_at = NOW() WHERE id = NEW.id;

            UPDATE drivers
            SET total_missions = total_missions + 1
            WHERE id = NEW.driver_id;
        END IF;
    ELSIF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Commission deja prelevee par anticipation : uniquement les statistiques
        UPDATE drivers
        SET total_missions = total_missions + 1
        WHERE id = NEW.driver_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
