-- Rollback de la migration 20260504000057 (session 2.26)
-- Supprime la demande d'envoi par la base. A utiliser avec la version
-- precedente de l'application et de check-document-reminders, qui demandaient
-- l'envoi elles-memes ; sinon plus aucune notification ne sonnerait.

DROP TRIGGER IF EXISTS notifications_push_dispatch ON public.notifications;
DROP FUNCTION IF EXISTS public.dispatch_push_on_notification_insert();
ALTER TABLE public.notifications DROP COLUMN IF EXISTS push_sent_at;
