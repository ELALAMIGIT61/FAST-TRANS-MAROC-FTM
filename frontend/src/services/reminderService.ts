// /services/reminderService.ts
// Fast Trans Maroc — P2
// Typically called by a Supabase Edge Function (daily CRON)

import { supabase } from '../lib/supabaseClient';

export async function checkAndSendReminders(): Promise<void> {
  console.log('[FTM-DEBUG] Reminders - Checking expiring documents', {
    timestamp: new Date().toISOString(),
  });

  const today    = new Date();
  const in30Days = new Date(today);
  in30Days.setDate(today.getDate() + 30);

  const { data: reminders30, error } = await supabase
    .from('document_reminders')
    .select('*, drivers(profile_id)')
    .lte('expiry_date', in30Days.toISOString().split('T')[0])
    .gte('expiry_date', today.toISOString().split('T')[0])
    .eq('reminder_30_days_sent', false);

  if (error) {
    console.log('[FTM-DEBUG] Reminders - Fetch error', { error: error.message });
    return;
  }

  console.log('[FTM-DEBUG] Reminders - Found reminders to send', {
    count30: reminders30?.length ?? 0,
  });

  for (const reminder of reminders30 ?? []) {
    const daysLeft = Math.ceil(
      (new Date(reminder.expiry_date as string).getTime() - today.getTime()) /
        (1000 * 60 * 60 * 24)
    );

    await supabase.from('notifications').insert({
      profile_id: (reminder.drivers as { profile_id: string }).profile_id,
      title:      `Document expirant dans ${daysLeft} jours`,
      body:       `Votre ${reminder.document_type} expire le ${reminder.expiry_date}. Renouvelez-le pour rester actif.`,
      type:       'document_expiry',
      data:       { document_type: reminder.document_type, expiry_date: reminder.expiry_date },
    });

    await supabase
      .from('document_reminders')
      .update({ reminder_30_days_sent: true })
      .eq('id', reminder.id);

    console.log('[FTM-DEBUG] Reminders - Reminder sent', {
      reminderId:   reminder.id,
      documentType: reminder.document_type,
      daysLeft,
    });
  }
}
