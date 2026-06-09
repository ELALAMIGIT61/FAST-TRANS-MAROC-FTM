-- Migration : 20260504000008_fix_notifications_select_admin.sql
-- Objectif : Autoriser SELECT sur notifications pour l'admin
-- Cause    : .select().single() apres INSERT echoue car admin ne peut pas
--            lire les notifications des autres utilisateurs -> 403 Forbidden
-- Solution : Politique SELECT pour admin via get_my_role()

CREATE POLICY "notifications_select_admin"
    ON notifications FOR SELECT
    USING (get_my_role() = 'admin');
