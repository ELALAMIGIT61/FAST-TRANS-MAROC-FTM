-- =====================================================
-- Fast Trans Maroc (FTM) - Initial Database Schema
-- =====================================================
-- Version: 1.0
-- Description: Schéma initial pour l'application de mise en relation
--              transporteurs-clients au Maroc
-- Backend: Supabase (PostgreSQL)
-- =====================================================

-- Activation des extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- =====================================================
-- ÉNUMÉRATIONS (ENUMS)
-- =====================================================

-- Type d'utilisateur
CREATE TYPE user_role AS ENUM ('client', 'driver', 'admin');

-- Statut de vérification des documents
CREATE TYPE verification_status AS ENUM ('pending', 'verified', 'rejected', 'expired');

-- Catégorie de véhicule
CREATE TYPE vehicle_category AS ENUM ('vul', 'n2_medium', 'n2_large');

-- Statut de mission
CREATE TYPE mission_status AS ENUM (
    'pending',          -- En attente d'acceptation
    'accepted',         -- Acceptée par chauffeur
    'in_progress',      -- En cours
    'completed',        -- Terminée
    'cancelled_client', -- Annulée par client
    'cancelled_driver'  -- Annulée par chauffeur
);

-- Type de mission
CREATE TYPE mission_type AS ENUM ('transport', 'ecommerce_parcel');

-- Statut de transaction wallet
CREATE TYPE transaction_status AS ENUM ('pending', 'completed', 'failed');

-- Type de transaction
CREATE TYPE transaction_type AS ENUM ('commission', 'refund', 'topup');

-- =====================================================
-- TABLE: profiles (Profils utilisateurs)
-- =====================================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'client',
    language_preference VARCHAR(2) DEFAULT 'fr' CHECK (language_preference IN ('fr', 'ar')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour recherche rapide
CREATE INDEX idx_profiles_phone ON profiles(phone_number);
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_user_id ON profiles(user_id);

-- =====================================================
-- TABLE: drivers (Chauffeurs)
-- =====================================================
CREATE TABLE drivers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
    
    -- Informations véhicule
    vehicle_category vehicle_category NOT NULL,
    vehicle_brand VARCHAR(100),
    vehicle_model VARCHAR(100),
    license_plate VARCHAR(20) UNIQUE NOT NULL,
    vehicle_capacity_kg INTEGER CHECK (vehicle_capacity_kg > 0),
    
    -- Documents légaux
    driver_license_number VARCHAR(50) UNIQUE NOT NULL,
    driver_license_expiry DATE NOT NULL,
    driver_license_verified verification_status DEFAULT 'pending',
    
    vehicle_registration_number VARCHAR(50) UNIQUE NOT NULL,
    vehicle_registration_verified verification_status DEFAULT 'pending',
    
    insurance_number VARCHAR(50) NOT NULL,
    insurance_expiry DATE NOT NULL,
    insurance_verified verification_status DEFAULT 'pending',
    
    technical_inspection_expiry DATE NOT NULL,
    technical_inspection_verified verification_status DEFAULT 'pending',
    
    -- URLs des documents (stockage Supabase Storage)
    driver_license_url TEXT,
    vehicle_registration_url TEXT,
    insurance_url TEXT,
    technical_inspection_url TEXT,
    
    -- Statut et disponibilité
    is_verified BOOLEAN GENERATED ALWAYS AS (
        driver_license_verified = 'verified' AND
        vehicle_registration_verified = 'verified' AND
        insurance_verified = 'verified' AND
        technical_inspection_verified = 'verified'
    ) STORED,
    is_available BOOLEAN DEFAULT false,
    
    -- Localisation en temps réel
    current_location GEOGRAPHY(POINT, 4326),
    last_location_update TIMESTAMP WITH TIME ZONE,
    
    -- Statistiques
    total_missions INTEGER DEFAULT 0,
    rating_average DECIMAL(3,2) DEFAULT 0 CHECK (rating_average >= 0 AND rating_average <= 5),
    total_reviews INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour géolocalisation et recherche
CREATE INDEX idx_drivers_location ON drivers USING GIST(current_location);
CREATE INDEX idx_drivers_verified ON drivers(is_verified) WHERE is_verified = true;
CREATE INDEX idx_drivers_available ON drivers(is_available) WHERE is_available = true;
CREATE INDEX idx_drivers_category ON drivers(vehicle_category);

-- =====================================================
-- TABLE: wallet (Portefeuille numérique chauffeurs)
-- =====================================================
CREATE TABLE wallet (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE UNIQUE NOT NULL,
    balance DECIMAL(10,2) DEFAULT 0 CHECK (balance >= 0),
    minimum_balance DECIMAL(10,2) DEFAULT 100.00,
    total_earned DECIMAL(10,2) DEFAULT 0,
    total_commissions DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_wallet_driver ON wallet(driver_id);

-- =====================================================
-- TABLE: missions (Courses/Missions)
-- =====================================================
CREATE TABLE missions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_number VARCHAR(20) UNIQUE NOT NULL,
    
    -- Parties impliquées
    client_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
    
    -- Type et catégorie
    mission_type mission_type NOT NULL DEFAULT 'transport',
    vehicle_category vehicle_category NOT NULL,
    
    -- Localisation
    pickup_location GEOGRAPHY(POINT, 4326) NOT NULL,
    pickup_address TEXT NOT NULL,
    pickup_city VARCHAR(100) NOT NULL,
    
    dropoff_location GEOGRAPHY(POINT, 4326) NOT NULL,
    dropoff_address TEXT NOT NULL,
    dropoff_city VARCHAR(100) NOT NULL,
    
    estimated_distance_km DECIMAL(10,2),
    
    -- Détails de la mission
    description TEXT,
    needs_loading_help BOOLEAN DEFAULT false,
    
    -- Prix et paiement
    negotiated_price DECIMAL(10,2),
    commission_amount DECIMAL(10,2),
    payment_method VARCHAR(20) DEFAULT 'cash',
    
    -- Statut et timing
    status mission_status DEFAULT 'pending',
    scheduled_pickup_time TIMESTAMP WITH TIME ZONE,
    actual_pickup_time TIMESTAMP WITH TIME ZONE,
    actual_dropoff_time TIMESTAMP WITH TIME ZONE,
    
    -- Notes et évaluation
    client_notes TEXT,
    driver_notes TEXT,
    client_rating INTEGER CHECK (client_rating >= 1 AND client_rating <= 5),
    driver_rating INTEGER CHECK (driver_rating >= 1 AND driver_rating <= 5),
    client_review TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Index pour recherche et performance
CREATE INDEX idx_missions_client ON missions(client_id);
CREATE INDEX idx_missions_driver ON missions(driver_id);
CREATE INDEX idx_missions_status ON missions(status);
CREATE INDEX idx_missions_created ON missions(created_at DESC);
CREATE INDEX idx_missions_pickup_location ON missions USING GIST(pickup_location);
CREATE INDEX idx_missions_dropoff_location ON missions USING GIST(dropoff_location);

-- =====================================================
-- TABLE: ecommerce_parcels (Colis E-commerce)
-- =====================================================
CREATE TABLE ecommerce_parcels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_id UUID REFERENCES missions(id) ON DELETE CASCADE UNIQUE NOT NULL,
    
    -- Informations vendeur/expéditeur
    sender_name VARCHAR(255) NOT NULL,
    sender_phone VARCHAR(20) NOT NULL,
    
    -- Informations destinataire
    recipient_name VARCHAR(255) NOT NULL,
    recipient_phone VARCHAR(20) NOT NULL,
    
    -- Dimensions et poids
    length_cm DECIMAL(10,2) NOT NULL CHECK (length_cm > 0),
    width_cm DECIMAL(10,2) NOT NULL CHECK (width_cm > 0),
    height_cm DECIMAL(10,2) NOT NULL CHECK (height_cm > 0),
    weight_kg DECIMAL(10,2) NOT NULL CHECK (weight_kg > 0),
    
    -- Volume calculé
    volume_m3 DECIMAL(10,4) GENERATED ALWAYS AS (
        (length_cm * width_cm * height_cm) / 1000000
    ) STORED,
    
    -- Contenu
    content_description TEXT NOT NULL,
    is_fragile BOOLEAN DEFAULT false,
    
    -- Traçabilité
    tracking_number VARCHAR(50) UNIQUE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_parcels_mission ON ecommerce_parcels(mission_id);
CREATE INDEX idx_parcels_tracking ON ecommerce_parcels(tracking_number);

-- =====================================================
-- TABLE: transactions (Transactions wallet)
-- =====================================================
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wallet_id UUID REFERENCES wallet(id) ON DELETE CASCADE NOT NULL,
    mission_id UUID REFERENCES missions(id) ON DELETE SET NULL,
    
    -- Détails transaction
    transaction_type transaction_type NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    balance_before DECIMAL(10,2) NOT NULL,
    balance_after DECIMAL(10,2) NOT NULL,
    
    -- Statut et description
    status transaction_status DEFAULT 'pending',
    description TEXT,
    
    -- Métadonnées
    metadata JSONB,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_transactions_wallet ON transactions(wallet_id);
CREATE INDEX idx_transactions_mission ON transactions(mission_id);
CREATE INDEX idx_transactions_created ON transactions(created_at DESC);
CREATE INDEX idx_transactions_type ON transactions(transaction_type);

-- =====================================================
-- TABLE: notifications (Notifications push)
-- =====================================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    
    -- Contenu
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    
    -- Données additionnelles
    data JSONB,
    
    -- Statut
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notifications_profile ON notifications(profile_id);
CREATE INDEX idx_notifications_unread ON notifications(profile_id, is_read) WHERE is_read = false;
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- =====================================================
-- TABLE: document_reminders (Rappels expiration documents)
-- =====================================================
CREATE TABLE document_reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE NOT NULL,
    
    -- Type de document
    document_type VARCHAR(50) NOT NULL,
    expiry_date DATE NOT NULL,
    
    -- Rappels envoyés
    reminder_30_days_sent BOOLEAN DEFAULT false,
    reminder_15_days_sent BOOLEAN DEFAULT false,
    reminder_7_days_sent BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_reminders_driver ON document_reminders(driver_id);
CREATE INDEX idx_reminders_expiry ON document_reminders(expiry_date);

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

-- Fonction pour générer un numéro de mission unique
CREATE OR REPLACE FUNCTION generate_mission_number()
RETURNS TEXT AS $$
DECLARE
    new_number TEXT;
    done BOOLEAN := false;
BEGIN
    WHILE NOT done LOOP
        new_number := 'FTM' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
        IF NOT EXISTS (SELECT 1 FROM missions WHERE mission_number = new_number) THEN
            done := true;
        END IF;
    END LOOP;
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour calculer la commission selon la catégorie
CREATE OR REPLACE FUNCTION calculate_commission(category vehicle_category)
RETURNS DECIMAL(10,2) AS $$
BEGIN
    RETURN CASE category
        WHEN 'vul' THEN 25.00
        WHEN 'n2_medium' THEN 40.00
        WHEN 'n2_large' THEN 50.00
        ELSE 25.00
    END;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour calculer la distance entre deux points (en km)
CREATE OR REPLACE FUNCTION calculate_distance(
    point1 GEOGRAPHY,
    point2 GEOGRAPHY
)
RETURNS DECIMAL(10,2) AS $$
BEGIN
    RETURN ROUND((ST_Distance(point1, point2) / 1000)::NUMERIC, 2);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON drivers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wallet_updated_at BEFORE UPDATE ON wallet
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_missions_updated_at BEFORE UPDATE ON missions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger pour générer automatiquement le numéro de mission
CREATE OR REPLACE FUNCTION set_mission_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.mission_number IS NULL THEN
        NEW.mission_number := generate_mission_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_mission_number BEFORE INSERT ON missions
    FOR EACH ROW EXECUTE FUNCTION set_mission_number();

-- Trigger pour calculer automatiquement la commission
CREATE OR REPLACE FUNCTION set_commission_amount()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.commission_amount IS NULL THEN
        NEW.commission_amount := calculate_commission(NEW.vehicle_category);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_commission BEFORE INSERT ON missions
    FOR EACH ROW EXECUTE FUNCTION set_commission_amount();

-- Trigger pour calculer la distance estimée
CREATE OR REPLACE FUNCTION set_estimated_distance()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estimated_distance_km IS NULL THEN
        NEW.estimated_distance_km := calculate_distance(
            NEW.pickup_location,
            NEW.dropoff_location
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_distance BEFORE INSERT ON missions
    FOR EACH ROW EXECUTE FUNCTION set_estimated_distance();

-- Trigger pour déduire automatiquement la commission du wallet
CREATE OR REPLACE FUNCTION process_commission_payment()
RETURNS TRIGGER AS $$
DECLARE
    driver_wallet_id UUID;
    current_balance DECIMAL(10,2);
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Récupérer le wallet du chauffeur
        SELECT w.id, w.balance INTO driver_wallet_id, current_balance
        FROM wallet w
        INNER JOIN drivers d ON d.id = w.driver_id
        WHERE d.id = NEW.driver_id;
        
        IF driver_wallet_id IS NOT NULL THEN
            -- Déduire la commission
            UPDATE wallet
            SET balance = balance - NEW.commission_amount,
                total_commissions = total_commissions + NEW.commission_amount
            WHERE id = driver_wallet_id;
            
            -- Enregistrer la transaction
            INSERT INTO transactions (
                wallet_id,
                mission_id,
                transaction_type,
                amount,
                balance_before,
                balance_after,
                status,
                description,
                processed_at
            ) VALUES (
                driver_wallet_id,
                NEW.id,
                'commission',
                NEW.commission_amount,
                current_balance,
                current_balance - NEW.commission_amount,
                'completed',
                'Commission pour mission ' || NEW.mission_number,
                NOW()
            );
            
            -- Mettre à jour les statistiques du chauffeur
            UPDATE drivers
            SET total_missions = total_missions + 1
            WHERE id = NEW.driver_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_process_commission AFTER UPDATE ON missions
    FOR EACH ROW EXECUTE FUNCTION process_commission_payment();

-- Trigger pour mettre à jour la note moyenne du chauffeur
CREATE OR REPLACE FUNCTION update_driver_rating()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.client_rating IS NOT NULL AND (OLD.client_rating IS NULL OR OLD.client_rating != NEW.client_rating) THEN
        UPDATE drivers
        SET 
            rating_average = (
                SELECT ROUND(AVG(client_rating)::NUMERIC, 2)
                FROM missions
                WHERE driver_id = NEW.driver_id AND client_rating IS NOT NULL
            ),
            total_reviews = (
                SELECT COUNT(*)
                FROM missions
                WHERE driver_id = NEW.driver_id AND client_rating IS NOT NULL
            )
        WHERE id = NEW.driver_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_rating AFTER UPDATE ON missions
    FOR EACH ROW EXECUTE FUNCTION update_driver_rating();

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Activer RLS sur toutes les tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ecommerce_parcels ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_reminders ENABLE ROW LEVEL SECURITY;

-- Policies pour profiles
CREATE POLICY "Users can view their own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = user_id);

-- Policies pour drivers
CREATE POLICY "Drivers can view their own data"
    ON drivers FOR SELECT
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Drivers can update their own data"
    ON drivers FOR UPDATE
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

-- Policies pour missions
CREATE POLICY "Users can view their own missions"
    ON missions FOR SELECT
    USING (
        client_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
        OR driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Clients can create missions"
    ON missions FOR INSERT
    WITH CHECK (
        client_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can update their own missions"
    ON missions FOR UPDATE
    USING (
        client_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
        OR driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

-- Policies pour wallet
CREATE POLICY "Drivers can view their own wallet"
    ON wallet FOR SELECT
    USING (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

-- Policies pour transactions
CREATE POLICY "Users can view their own transactions"
    ON transactions FOR SELECT
    USING (
        wallet_id IN (
            SELECT w.id FROM wallet w
            INNER JOIN drivers d ON d.id = w.driver_id
            INNER JOIN profiles p ON p.id = d.profile_id
            WHERE p.user_id = auth.uid()
        )
    );

-- Policies pour notifications
CREATE POLICY "Users can view their own notifications"
    ON notifications FOR SELECT
    USING (profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update their own notifications"
    ON notifications FOR UPDATE
    USING (profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()));

-- =====================================================
-- VUES UTILES
-- =====================================================

-- Vue pour les chauffeurs disponibles et vérifiés
CREATE OR REPLACE VIEW available_drivers AS
SELECT 
    d.id,
    d.profile_id,
    p.full_name,
    p.phone_number,
    d.vehicle_category,
    d.vehicle_brand,
    d.vehicle_model,
    d.license_plate,
    d.current_location,
    d.rating_average,
    d.total_missions,
    d.last_location_update
FROM drivers d
INNER JOIN profiles p ON p.id = d.profile_id
WHERE d.is_verified = true
  AND d.is_available = true
  AND p.is_active = true;

-- Vue pour le tableau de bord chauffeur
CREATE OR REPLACE VIEW driver_dashboard AS
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
    COUNT(CASE WHEN m.status = 'in_progress' THEN 1 END) AS active_missions
FROM drivers d
INNER JOIN profiles p ON p.id = d.profile_id
LEFT JOIN wallet w ON w.driver_id = d.id
LEFT JOIN missions m ON m.driver_id = d.id
GROUP BY d.id, p.full_name, d.vehicle_category, d.rating_average, 
         d.total_missions, d.total_reviews, w.balance, w.total_earned, 
         w.total_commissions, d.is_available, d.is_verified;

-- =====================================================
-- COMMENTAIRES
-- =====================================================

COMMENT ON TABLE profiles IS 'Profils utilisateurs (clients, chauffeurs, admins)';
COMMENT ON TABLE drivers IS 'Informations détaillées des chauffeurs et leurs véhicules';
COMMENT ON TABLE wallet IS 'Portefeuille numérique des chauffeurs avec système revolving';
COMMENT ON TABLE missions IS 'Courses et missions de transport';
COMMENT ON TABLE ecommerce_parcels IS 'Détails des colis e-commerce transportés';
COMMENT ON TABLE transactions IS 'Historique des transactions wallet';
COMMENT ON TABLE notifications IS 'Notifications push envoyées aux utilisateurs';
COMMENT ON TABLE document_reminders IS 'Rappels pour expiration des documents légaux';

-- =====================================================
-- FIN DU SCRIPT
-- =====================================================
