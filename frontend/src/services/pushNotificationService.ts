import * as Notifications from 'expo-notifications';
import * as Haptics from 'expo-haptics';
import { supabase } from '../lib/supabaseClient';

// ─── CONFIGURATION HANDLERS ───────────────────────────────────────────────────

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge:  true,
  }),
});

// ─── MAPPING TYPE → ICÔNE ─────────────────────────────────────────────────────

export const NOTIF_ICONS: Record<string, string> = {
  new_mission:        '🚚',
  mission_accepted:   '✅',
  mission_started:    '🚛',
  mission_completed:  '🏁',
  mission_cancelled:  '❌',
  wallet_low_balance: '💸',
  document_expiry:    '⚠️',
  document_rejected:  '❌',
  document_verified:  '✅',
  parcel_status:      '📦',
};

// ─── MAPPING TYPE → CHANNEL ANDROID ───────────────────────────────────────────

function getChannelForType(type: string): string {
  const channelMap: Record<string, string> = {
    new_mission:        'ftm_missions',
    mission_accepted:   'ftm_missions',
    mission_started:    'ftm_missions',
    mission_completed:  'ftm_missions',
    mission_cancelled:  'ftm_missions',
    wallet_low_balance: 'ftm_wallet',
    document_expiry:    'ftm_documents',
    document_rejected:  'ftm_documents',
    document_verified:  'ftm_documents',
    parcel_status:      'ftm_missions',
  };
  return channelMap[type] || 'ftm_default';
}

// ─── SETUP CHANNELS ANDROID ───────────────────────────────────────────────────

export async function setupNotificationChannels(): Promise<void> {
  await Notifications.setNotificationChannelAsync('ftm_missions', {
    name:       'Missions FTM',
    importance: Notifications.AndroidImportance.HIGH,
    sound:      'default',
    vibrationPattern: [0, 250, 250, 250],
  });
  await Notifications.setNotificationChannelAsync('ftm_wallet', {
    name:       'Wallet FTM',
    importance: Notifications.AndroidImportance.HIGH,
    sound:      'default',
  });
  await Notifications.setNotificationChannelAsync('ftm_documents', {
    name:       'Documents FTM',
    importance: Notifications.AndroidImportance.DEFAULT,
    sound:      'default',
  });
}

// ─── PERMISSION & TOKEN ────────────────────────────────────────────────────────

export async function requestPushPermission(): Promise<{ granted: boolean; token?: string }> {
  console.log('[FTM-DEBUG] Push - Requesting push permission');

  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;

  if (existingStatus !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }

  console.log('[FTM-DEBUG] Push - Permission result', { status: finalStatus });

  if (finalStatus !== 'granted') {
    console.log('[FTM-DEBUG] Push - Permission denied', { status: finalStatus });
    return { granted: false };
  }

  const tokenData = await Notifications.getExpoPushTokenAsync();
  const token = tokenData.data;

  console.log('[FTM-DEBUG] Push - Token obtained', {
    tokenPreview: token?.substring(0, 20) + '...',
  });

  return { granted: true, token };
}

export async function registerPushToken(
  profileId: string,
  token: string,
  platform: string
): Promise<{ success?: boolean; error?: string }> {
  console.log('[FTM-DEBUG] Push - Registering device token', {
    profileId,
    platform,
    tokenPreview: token?.substring(0, 20) + '...',
  });

  const { error } = await supabase.functions.invoke('register-push-token', {
    body: { profile_id: profileId, token, platform },
  });

  if (error) {
    console.log('[FTM-DEBUG] Push - Token registration error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Push - Token registered successfully', { profileId, platform });
  return { success: true };
}

// ─── INSERTION NOTIFICATION ────────────────────────────────────────────────────

export async function insertNotification(
  profileId: string,
  type: string,
  title: string,
  body: string,
  data: Record<string, unknown> = {}
): Promise<{ success?: boolean; notification?: Record<string, unknown>; error?: unknown }> {
  console.log('[FTM-DEBUG] Push - Inserting notification', { profileId, type, title });

  const { data: notif, error } = await supabase
    .from('notifications')
    .insert({ profile_id: profileId, type, title, body, data, is_read: false })
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Push - Insert notification error', { error: error.message, type });
    return { error };
  }

  console.log('[FTM-DEBUG] Push - Notification inserted', {
    notificationId: notif.id,
    profileId,
    type,
  });

  await dispatchPushNotification(profileId, type, title, body, data, notif.id);

  return { success: true, notification: notif };
}

async function dispatchPushNotification(
  profileId: string,
  type: string,
  title: string,
  body: string,
  data: Record<string, unknown>,
  notifId: string
): Promise<void> {
  console.log('[FTM-DEBUG] Push - Dispatching push notification', { profileId, type, notifId });

  try {
    const { error } = await supabase.functions.invoke('send-push-notification', {
      body: {
        profile_id:      profileId,
        notification_id: notifId,
        type,
        title,
        body,
        data:            { ...data, notification_id: notifId },
        channel_id:      getChannelForType(type),
      },
    });

    if (error) {
      console.log('[FTM-DEBUG] Push - Dispatch error', { error: error.message, type, notifId });
    } else {
      console.log('[FTM-DEBUG] Push - Dispatched successfully', { notifId, type });
    }
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Push - Dispatch exception', { err: msg });
  }
}

// ─── LECTURE / MISE À JOUR ─────────────────────────────────────────────────────

export async function markNotificationRead(
  notificationId: string,
  profileId: string
): Promise<{ success?: boolean; error?: unknown }> {
  console.log('[FTM-DEBUG] Push - Marking notification as read', { notificationId });

  const { error } = await supabase
    .from('notifications')
    .update({ is_read: true, read_at: new Date().toISOString() })
    .eq('id', notificationId)
    .eq('profile_id', profileId);

  if (error) {
    console.log('[FTM-DEBUG] Push - Mark read error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Push - Notification marked as read', { notificationId });
  return { success: true };
}

export async function markAllNotificationsRead(
  profileId: string
): Promise<{ success?: boolean; error?: unknown }> {
  console.log('[FTM-DEBUG] Push - Marking all notifications as read', { profileId });

  const { error } = await supabase
    .from('notifications')
    .update({ is_read: true, read_at: new Date().toISOString() })
    .eq('profile_id', profileId)
    .eq('is_read', false);

  if (error) {
    console.log('[FTM-DEBUG] Push - Mark all read error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Push - All notifications marked as read', { profileId });
  return { success: true };
}

export async function getNotifications(
  profileId: string,
  page = 0,
  unreadOnly = false
): Promise<{
  success?: boolean;
  notifications?: unknown[];
  totalCount?: number;
  unreadCount?: number;
  hasMore?: boolean;
  error?: unknown;
}> {
  const PAGE_SIZE = 30;
  const from = page * PAGE_SIZE;
  const to   = from + PAGE_SIZE - 1;

  console.log('[FTM-DEBUG] Push - Fetching notifications', { profileId, page, unreadOnly });

  let query = supabase
    .from('notifications')
    .select('*', { count: 'exact' })
    .eq('profile_id', profileId)
    .order('created_at', { ascending: false })
    .range(from, to);

  if (unreadOnly) query = query.eq('is_read', false);

  const { data, error, count } = await query;

  if (error) {
    console.log('[FTM-DEBUG] Push - Fetch notifications error', { error: error.message });
    return { error };
  }

  const unreadCount = (data as { is_read: boolean }[])?.filter(n => !n.is_read).length || 0;

  console.log('[FTM-DEBUG] Push - Notifications fetched', {
    profileId, total: count, fetched: data?.length, unread: unreadCount,
  });

  return {
    success:       true,
    notifications: data || [],
    totalCount:    count ?? 0,
    unreadCount,
    hasMore:       (from + PAGE_SIZE) < (count ?? 0),
  };
}

// ─── REALTIME SUBSCRIPTION ─────────────────────────────────────────────────────

export function subscribeToNotifications(
  profileId: string,
  onNewNotification: (notif: Record<string, unknown>) => void
) {
  console.log('[FTM-DEBUG] Push - Subscribing to notifications', { profileId });

  const channel = supabase
    .channel(`notifications-${profileId}`)
    .on(
      'postgres_changes',
      {
        event:  'INSERT',
        schema: 'public',
        table:  'notifications',
        filter: `profile_id=eq.${profileId}`,
      },
      (payload) => {
        const notif = payload.new as Record<string, unknown>;
        console.log('[FTM-DEBUG] Push - New notification received', {
          profileId,
          notifId: notif.id,
          type:    notif.type,
          title:   notif.title,
        });
        onNewNotification(notif);
      }
    )
    .subscribe();

  return channel;
}

// ─── HANDLERS GLOBAUX ─────────────────────────────────────────────────────────

export function setupPushHandlers(
  navigate: (screen: string, params?: Record<string, unknown>) => void
): void {
  console.log('[FTM-DEBUG] Push - Setting up push handlers');

  // App EN PREMIER PLAN
  Notifications.addNotificationReceivedListener((notification) => {
    const data = notification.request.content.data as Record<string, unknown>;
    console.log('[FTM-DEBUG] Push - Foreground notification received', {
      type:  data?.type,
      title: notification.request.content.title,
    });
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  });

  // App EN ARRIÈRE-PLAN ou FERMÉE → Tap notification système
  Notifications.addNotificationResponseReceivedListener((response) => {
    const data = response.notification.request.content.data as Record<string, unknown>;
    console.log('[FTM-DEBUG] Push - Background notification tapped', {
      type:   data?.type,
      screen: data?.screen,
    });
    handleNotificationTap(
      {
        id:         String(data?.notification_id || ''),
        profile_id: String(data?.profile_id || ''),
        type:       String(data?.type || ''),
        data,
      },
      navigate
    );
  });

  console.log('[FTM-DEBUG] Push - Push handlers configured');
}

export function handleNotificationTap(
  notification: { id: string; profile_id: string; type: string; data?: Record<string, unknown> },
  navigate: (screen: string, params?: Record<string, unknown>) => void
): void {
  console.log('[FTM-DEBUG] Push - Notification tapped', {
    notifId: notification.id,
    type:    notification.type,
    screen:  notification.data?.screen,
  });

  if (notification.id && notification.profile_id) {
    markNotificationRead(notification.id, notification.profile_id);
  }

  const screenMap: Record<string, () => void> = {
    MissionTrackingScreen: () =>
      navigate('MissionTracking', { missionId: notification.data?.mission_id }),
    NewMissionModal: () =>
      navigate('DriverHome', { openMission: notification.data?.mission_id }),
    WalletDashboardScreen: () => navigate('WalletDashboard'),
    WalletTopupScreen:     () => navigate('WalletTopup'),
    DocumentStatusScreen:  () =>
      navigate('DocumentStatus', { highlight: notification.data?.document_type }),
    RatingScreen: () =>
      navigate('Rating', { missionId: notification.data?.mission_id }),
  };

  const fn = screenMap[String(notification.data?.screen || '')];
  if (fn) {
    fn();
    console.log('[FTM-DEBUG] Push - Navigated from notification', {
      screen: notification.data?.screen,
    });
  }
}
