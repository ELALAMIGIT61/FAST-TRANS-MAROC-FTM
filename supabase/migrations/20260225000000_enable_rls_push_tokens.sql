-- Activer RLS sur push_tokens
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

-- Policy SELECT : chaque user voit ses propres tokens
CREATE POLICY "push_tokens_select_own"
    ON push_tokens FOR SELECT
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

-- Policy INSERT : chaque user insère ses propres tokens
CREATE POLICY "push_tokens_insert_own"
    ON push_tokens FOR INSERT
    WITH CHECK (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

-- Policy DELETE : chaque user supprime ses propres tokens
CREATE POLICY "push_tokens_delete_own"
    ON push_tokens FOR DELETE
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE user_id = auth.uid()
        )
    );

-- Policy Admin : voit tous les tokens
CREATE POLICY "push_tokens_select_admin"
    ON push_tokens FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );
