-- Migration : 20260504000007_fix_notifications_insert_rls.sql
-- Objectif : Autoriser INSERT sur notifications pour les utilisateurs authentifies
-- Cause    : notifications_insert_service couvre uniquement {public}
--            Le role authenticated n'a aucune politique INSERT -> 403 Forbidden
-- Solution : Ajouter politique INSERT pour authenticated

CREATE POLICY "notifications_insert_authenticated"
    ON notifications FOR INSERT
    TO authenticated
    WITH CHECK (true);
