-- =====================================================================
-- FTM P4 — Migration : Tracking Functions, Table et Vue
-- =====================================================================

-- TABLE: ecommerce_parcels
CREATE TABLE IF NOT EXISTS ecommerce_parcels (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_id UUID REFERENCES missions(id) ON DELETE CASCADE UNIQUE NOT NULL,

    -- Expéditeur
    sender_name  VARCHAR(255) NOT NULL,
    sender_phone VARCHAR(20)  NOT NULL,

    -- Destinataire
    recipient_name  VARCHAR(255) NOT NULL,
    recipient_phone VARCHAR(20)  NOT NULL,

    -- Dimensions (cm)
    length_cm DECIMAL(10,2) NOT NULL CHECK (length_cm > 0),
    width_cm  DECIMAL(10,2) NOT NULL CHECK (width_cm > 0),
    height_cm DECIMAL(10,2) NOT NULL CHECK (height_cm > 0),
    weight_kg DECIMAL(10,2) NOT NULL CHECK (weight_kg > 0),

    -- Volume calculé automatiquement par PostgreSQL (GENERATED ALWAYS)
    volume_m3 DECIMAL(10,4) GENERATED ALWAYS AS (
        (length_cm * width_cm * height_cm) / 1000000
    ) STORED,

    -- Contenu et options
    content_description TEXT    NOT NULL,
    is_fragile          BOOLEAN DEFAULT false,

    -- Numéro de suivi unique
    tracking_number VARCHAR(50) UNIQUE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour accès rapide
CREATE INDEX IF NOT EXISTS idx_parcels_mission  ON ecommerce_parcels(mission_id);
CREATE INDEX IF NOT EXISTS idx_parcels_tracking ON ecommerce_parcels(tracking_number);

-- =====================================================================
-- FONCTION : generate_tracking_number()
-- =====================================================================
CREATE OR REPLACE FUNCTION generate_tracking_number()
RETURNS TEXT AS $$
DECLARE
    new_number  TEXT;
    done        BOOLEAN := false;
    chars       TEXT    := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    random_part TEXT    := '';
    i           INTEGER;
BEGIN
    WHILE NOT done LOOP
        random_part := '';
        FOR i IN 1..8 LOOP
            random_part := random_part ||
                SUBSTR(chars, FLOOR(RANDOM() * LENGTH(chars))::INTEGER + 1, 1);
        END LOOP;

        new_number := 'FTM-TRACK-' || random_part;

        IF NOT EXISTS (
            SELECT 1 FROM ecommerce_parcels
            WHERE tracking_number = new_number
        ) THEN
            done := true;
        END IF;
    END LOOP;
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- TRIGGER : set_tracking_number
-- =====================================================================
CREATE OR REPLACE FUNCTION set_tracking_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tracking_number IS NULL THEN
        NEW.tracking_number := generate_tracking_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_tracking_number ON ecommerce_parcels;
CREATE TRIGGER trigger_set_tracking_number
    BEFORE INSERT ON ecommerce_parcels
    FOR EACH ROW EXECUTE FUNCTION set_tracking_number();

-- =====================================================================
-- VUE PUBLIQUE : public_parcel_tracking
-- =====================================================================
CREATE OR REPLACE VIEW public_parcel_tracking AS
SELECT
    ep.tracking_number,
    ep.sender_name,
    CONCAT(
        LEFT(ep.sender_phone, 3),
        '****',
        RIGHT(ep.sender_phone, 2)
    ) AS sender_phone_masked,
    ep.recipient_name,
    ep.content_description,
    ep.is_fragile,
    ep.weight_kg,
    ep.volume_m3,
    m.status              AS mission_status,
    m.pickup_city,
    m.dropoff_city,
    m.pickup_address,
    m.dropoff_address,
    m.estimated_distance_km,
    m.actual_pickup_time,
    m.actual_dropoff_time,
    m.completed_at,
    m.mission_number,
    p.full_name           AS driver_name,
    d.vehicle_category,
    d.vehicle_brand,
    d.vehicle_model,
    d.current_location,
    d.last_location_update
FROM ecommerce_parcels ep
INNER JOIN missions m  ON m.id = ep.mission_id
LEFT  JOIN drivers  d  ON d.id = m.driver_id
LEFT  JOIN profiles p  ON p.id = d.profile_id;
