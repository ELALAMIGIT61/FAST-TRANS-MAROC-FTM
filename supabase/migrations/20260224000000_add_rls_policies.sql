-- =====================================================================
-- FTM — Migration P7 : Politiques RLS complètes
-- Timestamp : 20260224000000
-- =====================================================================

-- ── TABLE: profiles ──────────────────────────────────────────────────

CREATE POLICY "profiles_select_own"
    ON profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "profiles_select_admin"
    ON profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "profiles_insert_own"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "profiles_update_own"
    ON profiles FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "profiles_update_admin"
    ON profiles FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: drivers ────────────────────────────────────────────────────

CREATE POLICY "drivers_select_own"
    ON drivers FOR SELECT
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "drivers_select_available"
    ON drivers FOR SELECT
    USING (is_verified = true AND is_available = true);

CREATE POLICY "drivers_select_admin"
    ON drivers FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "drivers_insert_own"
    ON drivers FOR INSERT
    WITH CHECK (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "drivers_update_own"
    ON drivers FOR UPDATE
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "drivers_update_admin"
    ON drivers FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: wallet ─────────────────────────────────────────────────────

CREATE POLICY "wallet_select_own"
    ON wallet FOR SELECT
    USING (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "wallet_select_admin"
    ON wallet FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "wallet_insert_own"
    ON wallet FOR INSERT
    WITH CHECK (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "wallet_update_admin"
    ON wallet FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: missions ───────────────────────────────────────────────────

CREATE POLICY "missions_select_participants"
    ON missions FOR SELECT
    USING (
        client_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
        OR driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "missions_select_pending_for_drivers"
    ON missions FOR SELECT
    USING (
        status = 'pending'
        AND EXISTS (
            SELECT 1 FROM drivers d
            INNER JOIN profiles p ON p.id = d.profile_id
            WHERE p.user_id = auth.uid()
            AND d.vehicle_category = missions.vehicle_category
            AND d.is_verified = true
            AND d.is_available = true
        )
    );

CREATE POLICY "missions_select_admin"
    ON missions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "missions_insert_client"
    ON missions FOR INSERT
    WITH CHECK (
        client_id IN (
            SELECT id FROM profiles
            WHERE user_id = auth.uid() AND role = 'client'
        )
    );

CREATE POLICY "missions_update_participants"
    ON missions FOR UPDATE
    USING (
        client_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
        OR driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "missions_update_admin"
    ON missions FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: transactions ───────────────────────────────────────────────

CREATE POLICY "transactions_select_own"
    ON transactions FOR SELECT
    USING (
        wallet_id IN (
            SELECT w.id FROM wallet w
            INNER JOIN drivers d ON d.id = w.driver_id
            INNER JOIN profiles p ON p.id = d.profile_id
            WHERE p.user_id = auth.uid()
        )
    );

CREATE POLICY "transactions_select_admin"
    ON transactions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: notifications ──────────────────────────────────────────────

CREATE POLICY "notifications_select_own"
    ON notifications FOR SELECT
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "notifications_insert_service"
    ON notifications FOR INSERT
    WITH CHECK (true);

CREATE POLICY "notifications_update_own"
    ON notifications FOR UPDATE
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    )
    WITH CHECK (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "notifications_update_admin"
    ON notifications FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "notifications_delete_admin"
    ON notifications FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- ── TABLE: ecommerce_parcels ──────────────────────────────────────────

CREATE POLICY "parcels_select_client"
    ON ecommerce_parcels FOR SELECT
    USING (
        mission_id IN (
            SELECT id FROM missions
            WHERE client_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "parcels_select_driver"
    ON ecommerce_parcels FOR SELECT
    USING (
        mission_id IN (
            SELECT id FROM missions
            WHERE driver_id IN (
                SELECT id FROM drivers WHERE profile_id IN (
                    SELECT id FROM profiles WHERE user_id = auth.uid()
                )
            )
        )
    );

CREATE POLICY "parcels_select_tracking_public"
    ON ecommerce_parcels FOR SELECT
    USING (tracking_number IS NOT NULL);

CREATE POLICY "parcels_select_admin"
    ON ecommerce_parcels FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "parcels_insert_client"
    ON ecommerce_parcels FOR INSERT
    WITH CHECK (
        mission_id IN (
            SELECT id FROM missions
            WHERE client_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

-- ── TABLE: document_reminders ─────────────────────────────────────────

CREATE POLICY "reminders_select_own"
    ON document_reminders FOR SELECT
    USING (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "reminders_select_admin"
    ON document_reminders FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

CREATE POLICY "reminders_insert_own"
    ON document_reminders FOR INSERT
    WITH CHECK (
        driver_id IN (
            SELECT id FROM drivers WHERE profile_id IN (
                SELECT id FROM profiles WHERE user_id = auth.uid()
            )
        )
    );

-- ── VUES SECURITY DEFINER ─────────────────────────────────────────────

ALTER VIEW available_drivers OWNER TO postgres;
GRANT SELECT ON available_drivers TO authenticated;

DROP VIEW IF EXISTS public_parcel_tracking CASCADE;
CREATE OR REPLACE VIEW public_parcel_tracking
WITH (security_invoker = false)
AS
SELECT
    ep.id,
    ep.tracking_number,
    m.status,
    ep.created_at,
    ep.recipient_name,
    LEFT(ep.recipient_phone, 6) || '****' AS recipient_phone_partial,
    m.pickup_city,
    m.dropoff_city,
    m.status AS mission_status
FROM ecommerce_parcels ep
JOIN missions m ON m.id = ep.mission_id;

GRANT SELECT ON public_parcel_tracking TO anon;
GRANT SELECT ON public_parcel_tracking TO authenticated;
