import * as Notifications from 'expo-notifications';
import * as Haptics from 'expo-haptics';
import Constants from 'expo-constants';
import { Platform } from 'react-native';
import { supabase } from '../lib/supabaseClient';

// ─── CONFIGURATION HANDLERS ───────────────────────────────────────────────────

if (Platform.OS !== 'web') {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowAlert: true,
      shouldPlaySound: true,
      shouldSetBadge:  true,
    }),
  });
}

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
  // Session 3.4 : categorie utilisee par le serveur pour les autres types
  await Notifications.setNotificationChannelAsync('ftm_default', {
    name:       'Notifications FTM',
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

  // Session 3.4 : le numero de projet Expo est obligatoire hors Expo Go
  const tokenData = await Notifications.getExpoPushTokenAsync({
    projectId: Constants.expoConfig?.extra?.eas?.projectId,
  });
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

  // Session 2.26 : la sonnerie est demandee par la base elle-meme (trigger
  // notifications_push_dispatch, migration 057), pour toutes les notifications.

  return { success: true, notification: notif };
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

// A1 (F7) : suppression par l'utilisateur de ses propres notifications
// (policy notifications_delete_own, migration 061).
export async function deleteNotification(
  notificationId: string,
  profileId: string
): Promise<{ success?: boolean; error?: string }> {
  const { error } = await supabase
    .from('notifications')
    .delete()
    .eq('id', notificationId)
    .eq('profile_id', profileId);
  if (error) {
    console.log('[FTM-DEBUG] Push - Delete notification error', { error: error.message });
    return { error: error.message };
  }
  return { success: true };
}

export async function deleteAllNotifications(
  profileId: string
): Promise<{ success?: boolean; error?: string }> {
  const { error } = await supabase
    .from('notifications')
    .delete()
    .eq('profile_id', profileId);
  if (error) {
    console.log('[FTM-DEBUG] Push - Delete all notifications error', { error: error.message });
    return { error: error.message };
  }
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

  // A1 (correction 21b) : nom de canal unique a chaque abonnement, pour que deux
  // cloches ouvertes en meme temps ne se marchent plus dessus (plantage).
  const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  const channel = supabase
    .channel(`notifications-${profileId}-${suffix}`)
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

export async function handleNotificationTap(
  notification: { id: string; profile_id: string; type: string; data?: Record<string, unknown> },
  navigate: (screen: string, params?: Record<string, unknown>) => void
): Promise<void> {
  console.log('[FTM-DEBUG] Push - Notification tapped', {
    notifId: notification.id,
    type:    notification.type,
    screen:  notification.data?.screen,
  });

  // Session 3.4 : la notification recue sur le telephone ne porte pas le
  // profil du destinataire ; on prend celui de l'utilisateur connecte.
  const profileId = notification.profile_id || (await getCurrentProfileId());
  if (notification.id && profileId) {
    markNotificationRead(notification.id, profileId);
  }

  // Session 3.4 (correction 8) : les ecrans de mission attendent la mission
  // complete, et le portefeuille l'identifiant du chauffeur. La notification
  // ne porte que des identifiants : on va chercher ce qu'il faut avant d'ouvrir
  // l'ecran (sinon l'ecran s'ouvrait vide ou plantait).
  const missionId = notification.data?.mission_id ? String(notification.data.mission_id) : null;

  const openWithMission = async (screen: string) => {
    if (!missionId) return;
    const { data: mission, error } = await supabase
      .from('missions')
      .select('*')
      .eq('id', missionId)
      .single();
    if (mission) navigate(screen, { mission });
    else console.log('[FTM-DEBUG] Push - Mission not found for notification', { missionId, error: error?.message });
  };

  const currentDriverId = async (): Promise<string | null> => {
    if (!profileId) return null;
    const { data: driverRow } = await supabase
      .from('drivers')
      .select('id')
      .eq('profile_id', profileId)
      .single();
    return driverRow?.id ?? null;
  };

  const openWallet = async () => {
    const driverId = await currentDriverId();
    if (driverId) navigate('WalletDashboard', { driverId });
    else console.log('[FTM-DEBUG] Push - Driver not found for wallet notification');
  };

  const screenMap: Record<string, () => void | Promise<void>> = {
    MissionTrackingScreen: () => openWithMission('MissionTracking'),
    NewMissionModal: () =>
      navigate('DriverHome', { openMission: notification.data?.mission_id }),
    WalletDashboardScreen: openWallet,
    WalletTopupScreen:     () => navigate('WalletTopup'),
    DocumentStatusScreen:  () =>
      navigate('DocumentStatus', { highlight: notification.data?.document_type }),
    RatingScreen: () => openWithMission('Rating'),
    VoiceChat: () => openWithMission('VoiceChat'),
    WalletDashboard: openWallet,
    DriverHomeScreen: () => navigate('DriverHome'),
    MissionOfferScreen: async () => {
      const driverId = await currentDriverId();
      if (driverId) {
        navigate('MissionOffer', { missionId, driverId });
      } else {
        navigate('MissionOffer', { missionId });
      }
    },
  };

  const fn = screenMap[String(notification.data?.screen || '')];
  if (fn) {
    await fn();
    console.log('[FTM-DEBUG] Push - Navigated from notification', {
      screen: notification.data?.screen,
    });
  }
}

// ─── getCurrentProfileId ───────────────────────────────────────────────────────
export async function getCurrentProfileId(): Promise<string | null> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.user?.id) {
    console.log('[FTM-DEBUG] Push - No active session for profile lookup');
    return null;
  }
  const { data: profile, error } = await supabase
    .from('profiles')
    .select('id')
    .eq('user_id', session.user.id)
    .single();
  if (error || !profile) {
    console.log('[FTM-DEBUG] Push - Profile lookup error', { error: error?.message });
    return null;
  }
  return profile.id;
}
