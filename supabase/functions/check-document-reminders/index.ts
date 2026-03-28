import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/*
 * PLANIFICATION CRON Supabase Dashboard → Database → Cron Jobs :
 *
 * select cron.schedule(
 *   'check-document-reminders',
 *   '0 8 * * *',
 *   $$
 *     select net.http_post(
 *       url := 'https://[project].supabase.co/functions/v1/check-document-reminders',
 *       headers := '{"Authorization": "Bearer [SERVICE_ROLE_KEY]"}'::jsonb
 *     )
 *   $$
 * );
 */

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

async function insertNotification(
  profileId: string,
  type: string,
  title: string,
  body: string,
  data: Record<string, unknown> = {}
) {
  const { data: notif, error } = await supabase
    .from('notifications')
    .insert({ profile_id: profileId, type, title, body, data, is_read: false })
    .select()
    .single();

  if (error) {
    console.error('[FTM-DEBUG] Reminders - insertNotification error', error.message);
    throw error;
  }

  await supabase.functions.invoke('send-push-notification', {
    body: {
      profile_id:      profileId,
      notification_id: notif.id,
      type,
      title,
      body,
      data:            { ...data, notification_id: notif.id },
      channel_id:      'ftm_documents',
    },
  });
}

async function notifyDocumentExpiry(
  driverProfileId: string,
  documentType: string,
  expiryDate: string,
  daysLeft: number
) {
  const docLabels: Record<string, string> = {
    driver_license:       'Permis de conduire',
    insurance:            'Assurance',
    technical_inspection: 'Visite technique',
  };
  const docLabel = docLabels[documentType] || documentType;
  const urgency  = daysLeft <= 7 ? '🔴 URGENT — ' : daysLeft <= 15 ? '🟠 ' : '🟡 ';

  console.log('[FTM-DEBUG] Push - Notify document expiry', {
    driverProfileId, documentType, expiryDate, daysLeft,
  });

  return insertNotification(
    driverProfileId,
    'document_expiry',
    `${urgency}${docLabel} expire dans ${daysLeft} jours`,
    `Votre ${docLabel} expire le ${expiryDate}. Renouvelez-le pour rester actif sur FTM.`,
    { document_type: documentType, expiry_date: expiryDate, days_left: daysLeft, screen: 'DocumentStatusScreen' }
  );
}

serve(async (_req) => {
  const today   = new Date();
  const results = { sent: 0, errors: 0 };

  console.log('[FTM-DEBUG] Reminders - CRON started', {
    timestamp: today.toISOString(),
  });

  type Reminder = {
    id: string;
    document_type: string;
    expiry_date: string;
    drivers: { id: string; profile_id: string };
  };

  async function processReminders(
    reminders: Reminder[] | null,
    flagColumn: string,
    label: string
  ) {
    console.log(`[FTM-DEBUG] Reminders - ${label} candidates`, {
      count: reminders?.length || 0,
    });

    for (const reminder of reminders || []) {
      const daysLeft = Math.ceil(
        (new Date(reminder.expiry_date).getTime() - today.getTime()) / (1000 * 60 * 60 * 24)
      );
      try {
        await notifyDocumentExpiry(
          reminder.drivers.profile_id,
          reminder.document_type,
          reminder.expiry_date,
          daysLeft
        );
        await supabase
          .from('document_reminders')
          .update({ [flagColumn]: true })
          .eq('id', reminder.id);

        console.log(`[FTM-DEBUG] Reminders - ${label} sent`, {
          reminderId:      reminder.id,
          documentType:    reminder.document_type,
          daysLeft,
          driverProfileId: reminder.drivers.profile_id,
        });
        results.sent++;
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        console.log(`[FTM-DEBUG] Reminders - ${label} error`, {
          reminderId: reminder.id, err: msg,
        });
        results.errors++;
      }
    }
  }

  // ─── J-30 ──────────────────────────────────────────────────────────────────
  const date30 = new Date(today); date30.setDate(today.getDate() + 30);
  const { data: r30 } = await supabase
    .from('document_reminders')
    .select('id, document_type, expiry_date, drivers(id, profile_id)')
    .lte('expiry_date', date30.toISOString().split('T')[0])
    .gte('expiry_date', today.toISOString().split('T')[0])
    .eq('reminder_30_days_sent', false);
  await processReminders(r30 as Reminder[] | null, 'reminder_30_days_sent', 'J-30');

  // ─── J-15 ──────────────────────────────────────────────────────────────────
  const date15 = new Date(today); date15.setDate(today.getDate() + 15);
  const { data: r15 } = await supabase
    .from('document_reminders')
    .select('id, document_type, expiry_date, drivers(id, profile_id)')
    .lte('expiry_date', date15.toISOString().split('T')[0])
    .gte('expiry_date', today.toISOString().split('T')[0])
    .eq('reminder_15_days_sent', false);
  await processReminders(r15 as Reminder[] | null, 'reminder_15_days_sent', 'J-15');

  // ─── J-7 ───────────────────────────────────────────────────────────────────
  const date7 = new Date(today); date7.setDate(today.getDate() + 7);
  const { data: r7 } = await supabase
    .from('document_reminders')
    .select('id, document_type, expiry_date, drivers(id, profile_id)')
    .lte('expiry_date', date7.toISOString().split('T')[0])
    .gte('expiry_date', today.toISOString().split('T')[0])
    .eq('reminder_7_days_sent', false);
  await processReminders(r7 as Reminder[] | null, 'reminder_7_days_sent', 'J-7');

  console.log('[FTM-DEBUG] Reminders - CRON completed', {
    totalSent:   results.sent,
    totalErrors: results.errors,
    timestamp:   new Date().toISOString(),
  });

  return new Response(JSON.stringify(results), {
    headers: { 'Content-Type': 'application/json' },
    status:  200,
  });
});
