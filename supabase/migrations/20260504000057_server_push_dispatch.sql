-- Migration 20260504000057 - session 2.26 : sonnerie declenchee par le serveur
-- (decision du porteur du 16/10/2026 : chemin unique pour toutes les
-- notifications, protection contre la double sonnerie)
--
-- Constat (16/10/2026) : une notification enregistree n'est envoyee sur le
-- telephone que si quelqu'un appelle ensuite la fonction serveur
-- send-push-notification. L'application et la tache des rappels de documents
-- le font ; les notifications deposees par la base elle-meme (negociation des
-- offres 051/053, annonce de la messagerie et alerte de solde 054) ne
-- faisaient jamais sonner le telephone.
--
-- 1. Colonne notifications.push_sent_at : cochee par send-push-notification
--    au premier envoi ; tout appel suivant pour la meme notification est
--    ignore (pas de double sonnerie, y compris avec une ancienne version de
--    l'application qui ferait encore sa propre demande).
-- 2. Trigger notifications_push_dispatch (AFTER INSERT) : pour chaque
--    notification enregistree, la base demande l'envoi a send-push-notification
--    par pg_net, avec la cle de service lue dans le coffre-fort (Vault), comme
--    la tache check-document-reminders (migration 011). La requete n'est
--    emise qu'une fois la transaction validee : une notification annulee ne
--    fait rien sonner. Une erreur dans ce trigger n'empeche jamais
--    l'enregistrement de la notification.
-- 3. Droits : fonction executable par le systeme uniquement.
-- L'application et la tache des rappels ne demandent plus l'envoi elles-memes.

-- 1
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS push_sent_at TIMESTAMP WITH TIME ZONE;

-- 2
CREATE OR REPLACE FUNCTION public.dispatch_push_on_notification_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_key text;
BEGIN
  BEGIN
    SELECT decrypted_secret INTO v_key
    FROM vault.decrypted_secrets
    WHERE name = 'supabase_service_role_key'
    LIMIT 1;

    IF v_key IS NULL THEN
      RAISE WARNING 'dispatch_push_on_notification_insert: cle de service absente du coffre-fort, notification % non envoyee', NEW.id;
      RETURN NEW;
    END IF;

    PERFORM net.http_post(
      url := 'https://ustckqnecsilxqlyjute.supabase.co/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_key
      ),
      body := jsonb_build_object('notification_id', NEW.id),
      timeout_milliseconds := 10000
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'dispatch_push_on_notification_insert: envoi non demande pour la notification % (%)', NEW.id, SQLERRM;
  END;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS notifications_push_dispatch ON public.notifications;
CREATE TRIGGER notifications_push_dispatch
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.dispatch_push_on_notification_insert();

-- 3
REVOKE EXECUTE ON FUNCTION public.dispatch_push_on_notification_insert() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.dispatch_push_on_notification_insert() TO service_role;
