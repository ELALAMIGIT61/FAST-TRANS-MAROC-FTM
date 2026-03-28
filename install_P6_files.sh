#!/bin/bash

mkdir -p frontend/src/services
cat > frontend/src/services/pushNotificationService.ts << 'ENDOFFILE'
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
ENDOFFILE

mkdir -p frontend/src/services
cat > frontend/src/services/notificationTemplates.ts << 'ENDOFFILE'
import { insertNotification } from './pushNotificationService';

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

// ─── MISSIONS ──────────────────────────────────────────────────────────────────

export async function notifyNewMission(
  driverProfileId: string,
  mission: { id: string; mission_number: string; pickup_city: string; dropoff_city: string; commission_amount: number }
) {
  console.log('[FTM-DEBUG] Push - Notify new mission', {
    driverProfileId,
    missionId:     mission.id,
    missionNumber: mission.mission_number,
  });
  return insertNotification(
    driverProfileId,
    'new_mission',
    '🚚 Nouvelle mission disponible !',
    `${mission.pickup_city} → ${mission.dropoff_city} | Commission : ${mission.commission_amount} DH`,
    { mission_id: mission.id, mission_number: mission.mission_number, screen: 'NewMissionModal' }
  );
}

export async function notifyMissionAccepted(
  clientProfileId: string,
  mission: { id: string; mission_number: string },
  driverName: string
) {
  console.log('[FTM-DEBUG] Push - Notify mission accepted', {
    clientProfileId, missionId: mission.id, driverName,
  });
  return insertNotification(
    clientProfileId,
    'mission_accepted',
    '✅ Chauffeur trouvé !',
    `${driverName} a accepté votre mission ${mission.mission_number}. Il arrive bientôt.`,
    { mission_id: mission.id, screen: 'MissionTrackingScreen' }
  );
}

export async function notifyMissionStarted(
  clientProfileId: string,
  mission: { id: string; mission_number: string; dropoff_city: string }
) {
  console.log('[FTM-DEBUG] Push - Notify mission started', {
    clientProfileId, missionId: mission.id,
  });
  return insertNotification(
    clientProfileId,
    'mission_started',
    '🚛 Chargement en cours',
    `Votre mission ${mission.mission_number} a démarré. Trajet en cours vers ${mission.dropoff_city}.`,
    { mission_id: mission.id, screen: 'MissionTrackingScreen' }
  );
}

export async function notifyMissionCompleted(
  clientProfileId: string,
  driverProfileId: string,
  mission: { id: string; mission_number: string; dropoff_city: string; commission_amount: number }
) {
  console.log('[FTM-DEBUG] Push - Notify mission completed', {
    clientProfileId, driverProfileId, missionId: mission.id,
  });
  await insertNotification(
    clientProfileId,
    'mission_completed',
    '🏁 Mission terminée !',
    `Mission ${mission.mission_number} livrée à ${mission.dropoff_city}. Évaluez votre chauffeur.`,
    { mission_id: mission.id, screen: 'RatingScreen' }
  );
  return insertNotification(
    driverProfileId,
    'mission_completed',
    '💰 Commission prélevée',
    `Mission ${mission.mission_number} clôturée. Commission de ${mission.commission_amount} DH déduite.`,
    { mission_id: mission.id, screen: 'WalletDashboardScreen' }
  );
}

export async function notifyMissionCancelled(
  profileId: string,
  mission: { id: string; mission_number: string },
  cancelledBy: 'client' | 'driver'
) {
  const byLabel = cancelledBy === 'client' ? 'le client' : 'le chauffeur';
  console.log('[FTM-DEBUG] Push - Notify mission cancelled', {
    profileId, missionId: mission.id, cancelledBy,
  });
  return insertNotification(
    profileId,
    'mission_cancelled',
    '❌ Mission annulée',
    `La mission ${mission.mission_number} a été annulée par ${byLabel}.`,
    { mission_id: mission.id, screen: 'ClientHomeStack' }
  );
}

// ─── DOCUMENTS ─────────────────────────────────────────────────────────────────

const DOC_LABELS: Record<string, string> = {
  driver_license:       'Permis de conduire',
  vehicle_registration: 'Carte grise',
  insurance:            'Assurance',
  technical_inspection: 'Visite technique',
};

export async function notifyDocumentExpiry(
  driverProfileId: string,
  documentType: string,
  expiryDate: string,
  daysLeft: number
) {
  const docLabel = DOC_LABELS[documentType] || documentType;
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

export async function notifyDocumentVerified(driverProfileId: string, documentType: string) {
  console.log('[FTM-DEBUG] Push - Notify document verified', { driverProfileId, documentType });
  return insertNotification(
    driverProfileId,
    'document_verified',
    '✅ Document validé',
    `Votre ${DOC_LABELS[documentType] || documentType} a été approuvé. Continuez à accepter des missions.`,
    { document_type: documentType, screen: 'DocumentStatusScreen' }
  );
}

export async function notifyDocumentRejected(
  driverProfileId: string,
  documentType: string,
  reason: string
) {
  console.log('[FTM-DEBUG] Push - Notify document rejected', {
    driverProfileId, documentType, reason,
  });
  return insertNotification(
    driverProfileId,
    'document_rejected',
    '❌ Document refusé — Action requise',
    `Votre ${DOC_LABELS[documentType] || documentType} a été refusé : "${reason}". Re-uploadez un document valide.`,
    { document_type: documentType, reason, screen: 'DocumentStatusScreen' }
  );
}
ENDOFFILE

mkdir -p frontend/src/services
cat > frontend/src/services/audioService.ts << 'ENDOFFILE'
import { Audio } from 'expo-av';
import { supabase } from '../lib/supabaseClient';

let recordingInstance: Audio.Recording | null = null;
let soundInstance: Audio.Sound | null = null;

// ─── PERMISSION MICROPHONE ─────────────────────────────────────────────────────

export async function requestMicrophonePermission(): Promise<{
  granted: boolean;
  error?: string;
}> {
  console.log('[FTM-DEBUG] Audio - Requesting microphone permission');

  const { status } = await Audio.requestPermissionsAsync();

  console.log('[FTM-DEBUG] Audio - Microphone permission result', { status });

  if (status !== 'granted') {
    return {
      granted: false,
      error:   'Permission microphone refusée. Activez-la dans les réglages.',
    };
  }
  return { granted: true };
}

// ─── ENREGISTREMENT ────────────────────────────────────────────────────────────

export async function startRecording(): Promise<{ success?: boolean; error?: string }> {
  console.log('[FTM-DEBUG] Audio - Starting recording');

  const perms = await requestMicrophonePermission();
  if (!perms.granted) return { error: perms.error };

  try {
    await Audio.setAudioModeAsync({
      allowsRecordingIOS:   true,
      playsInSilentModeIOS: true,
    });

    const { recording } = await Audio.Recording.createAsync(
      Audio.RecordingOptionsPresets.HIGH_QUALITY
    );

    recordingInstance = recording;

    console.log('[FTM-DEBUG] Audio - Recording started', {
      format: 'aac/m4a', sampleRate: '44100 Hz', maxDuration: '120s',
    });
    return { success: true };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Audio - Start recording error', { err: msg });
    return { error: "Impossible de démarrer l'enregistrement." };
  }
}

export async function stopRecording(): Promise<{
  success?: boolean;
  uri?: string;
  duration?: number;
  size?: number;
  mimeType?: string;
  error?: string;
}> {
  console.log('[FTM-DEBUG] Audio - Stopping recording');

  if (!recordingInstance) {
    return { error: 'Aucun enregistrement en cours.' };
  }

  try {
    await recordingInstance.stopAndUnloadAsync();
    const uri    = recordingInstance.getURI();
    const status = await recordingInstance.getStatusAsync();
    recordingInstance = null;

    await Audio.setAudioModeAsync({ allowsRecordingIOS: false });

    const duration = Math.round(
      ('durationMillis' in status ? (status as { durationMillis: number }).durationMillis : 0) / 1000
    );

    console.log('[FTM-DEBUG] Audio - Recording stopped', {
      duration: duration + 's',
      uri:      uri?.substring(0, 60),
    });

    if (duration < 1) {
      console.log('[FTM-DEBUG] Audio - Recording too short', { duration });
      return { error: 'Message trop court. Maintenez appuyé pour enregistrer.' };
    }

    return {
      success:  true,
      uri:      uri || '',
      duration,
      size:     0,
      mimeType: 'audio/m4a',
    };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Audio - Stop recording error', { err: msg });
    return { error: "Erreur lors de l'arrêt de l'enregistrement." };
  }
}

// ─── UPLOAD STORAGE ────────────────────────────────────────────────────────────

export async function uploadVoiceMessage(
  missionId: string,
  senderProfileId: string,
  localUri: string,
  mimeType: string,
  duration: number
): Promise<{ success?: boolean; url?: string; filePath?: string; duration?: number; error?: string }> {
  const timestamp = Date.now();
  const extension = mimeType.includes('m4a') || mimeType.includes('aac') ? 'm4a' : 'wav';
  const filePath  = `missions/${missionId}/${senderProfileId}_${timestamp}.${extension}`;

  console.log('[FTM-DEBUG] Audio - Uploading voice message', {
    missionId, senderProfileId, filePath, mimeType, duration: duration + 's',
  });

  try {
    const response = await fetch(localUri);
    const blob     = await response.blob();

    const { error: uploadError } = await supabase.storage
      .from('voice-messages')
      .upload(filePath, blob, { contentType: mimeType, upsert: false });

    if (uploadError) {
      console.log('[FTM-DEBUG] Audio - Upload error', {
        error: uploadError.message, filePath,
      });
      return { error: uploadError.message };
    }

    const { data: signedData, error: signError } = await supabase.storage
      .from('voice-messages')
      .createSignedUrl(filePath, 7 * 24 * 3600);

    if (signError) {
      console.log('[FTM-DEBUG] Audio - Signed URL error', { error: signError.message });
      return { error: 'Message uploadé mais URL non générée.' };
    }

    console.log('[FTM-DEBUG] Audio - Voice message uploaded successfully', {
      missionId, filePath, duration: duration + 's',
    });

    return { success: true, url: signedData.signedUrl, filePath, duration };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Audio - Upload exception', { err: msg });
    return { error: 'Erreur réseau lors de l\'envoi du message.' };
  }
}

// ─── LECTURE ───────────────────────────────────────────────────────────────────

export async function playVoiceMessage(
  url: string,
  onProgress?: (progress: number) => void,
  onComplete?: () => void
): Promise<{ success?: boolean; error?: string }> {
  console.log('[FTM-DEBUG] Audio - Playing voice message', {
    url: url.substring(0, 60) + '...',
  });

  try {
    if (soundInstance) {
      await soundInstance.unloadAsync();
      soundInstance = null;
    }

    const { sound } = await Audio.Sound.createAsync(
      { uri: url },
      { shouldPlay: true },
      (status) => {
        if ('isLoaded' in status && status.isLoaded) {
          if (onProgress && status.durationMillis) {
            onProgress(status.positionMillis / status.durationMillis);
          }
          if (status.didJustFinish) {
            console.log('[FTM-DEBUG] Audio - Playback completed');
            if (onComplete) onComplete();
          }
        }
      }
    );

    soundInstance = sound;

    console.log('[FTM-DEBUG] Audio - Playback started');
    return { success: true };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Audio - Play exception', { err: msg });
    return { error: 'Impossible de lire le message.' };
  }
}

export async function stopPlayback(): Promise<void> {
  console.log('[FTM-DEBUG] Audio - Stopping playback');
  if (soundInstance) {
    await soundInstance.stopAsync();
    await soundInstance.unloadAsync();
    soundInstance = null;
  }
}

// ─── CHARGER LES MESSAGES D'UNE MISSION ───────────────────────────────────────

export async function loadVoiceMessages(missionId: string): Promise<{
  success?: boolean;
  messages?: {
    id: string;
    fileName: string;
    url: string | null;
    sender: string;
    timestamp: Date | null;
    size: number;
  }[];
  error?: unknown;
}> {
  console.log('[FTM-DEBUG] Audio - Loading voice messages', { missionId });

  const { data, error } = await supabase.storage
    .from('voice-messages')
    .list(`missions/${missionId}`, {
      sortBy: { column: 'created_at', order: 'asc' },
    });

  if (error) {
    console.log('[FTM-DEBUG] Audio - Load messages error', { error: error.message });
    return { error };
  }

  const messagesWithUrls = await Promise.all(
    (data || []).map(async (file) => {
      const { data: signed } = await supabase.storage
        .from('voice-messages')
        .createSignedUrl(`missions/${missionId}/${file.name}`, 3600);

      const parts    = file.name.split('_');
      const senderPart = parts[0];
      const tsPart   = parts[1]?.split('.')[0];

      return {
        id:        file.id,
        fileName:  file.name,
        url:       signed?.signedUrl ?? null,
        sender:    senderPart,
        timestamp: tsPart ? new Date(parseInt(tsPart)) : null,
        size:      (file.metadata as { size?: number })?.size || 0,
      };
    })
  );

  console.log('[FTM-DEBUG] Audio - Voice messages loaded', {
    missionId, count: messagesWithUrls.length,
  });

  return { success: true, messages: messagesWithUrls };
}
ENDOFFILE

mkdir -p frontend/src/components
cat > frontend/src/components/NotificationBell.tsx << 'ENDOFFILE'
import React, { useEffect, useState, useCallback } from 'react';
import {
  TouchableOpacity,
  View,
  Text,
  StyleSheet,
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { useNavigation } from '@react-navigation/native';
import { COLORS } from '../constants/theme';
import {
  getNotifications,
  subscribeToNotifications,
} from '../services/pushNotificationService';

interface Props {
  profileId: string;
}

export default function NotificationBell({ profileId }: Props) {
  const [unreadCount, setUnreadCount] = useState(0);
  const navigation = useNavigation<{ navigate: (screen: string) => void }>();

  const fetchUnread = useCallback(async () => {
    const result = await getNotifications(profileId, 0, true);
    if (result.success) {
      setUnreadCount(result.unreadCount ?? 0);
    }
  }, [profileId]);

  useEffect(() => {
    fetchUnread();

    const channel = subscribeToNotifications(profileId, () => {
      setUnreadCount((prev) => prev + 1);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    });

    return () => {
      channel.unsubscribe();
    };
  }, [profileId, fetchUnread]);

  return (
    <TouchableOpacity
      style={styles.container}
      onPress={() => navigation.navigate('NotificationCenter')}
      accessibilityLabel="Centre de notifications"
    >
      <Text style={styles.icon}>🔔</Text>
      {unreadCount > 0 && (
        <View style={styles.badge}>
          <Text style={styles.badgeText}>
            {unreadCount > 99 ? '99+' : String(unreadCount)}
          </Text>
        </View>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    position:  'relative',
    padding:   8,
    marginRight: 4,
  },
  icon: {
    fontSize: 22,
  },
  badge: {
    position:        'absolute',
    top:             2,
    right:           2,
    backgroundColor: COLORS.alert ?? '#DC3545',
    borderRadius:    10,
    minWidth:        18,
    height:          18,
    alignItems:      'center',
    justifyContent:  'center',
    paddingHorizontal: 4,
  },
  badgeText: {
    color:      '#FFFFFF',
    fontSize:   10,
    fontWeight: '700',
  },
});
ENDOFFILE

mkdir -p frontend/src/components
cat > frontend/src/components/VoiceMicButton.tsx << 'ENDOFFILE'
import React, { useRef, useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  ActivityIndicator,
  StyleSheet,
  Animated,
  Easing,
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { COLORS } from '../constants/theme';
import {
  startRecording,
  stopRecording,
  uploadVoiceMessage,
} from '../services/audioService';

interface VoiceMessage {
  url: string;
  duration: number;
  filePath: string;
  sender: string;
  timestamp: string;
}

interface Props {
  missionId: string;
  senderProfileId: string;
  onMessageSent?: (message: VoiceMessage) => void;
}

type RecordingState = 'idle' | 'recording' | 'uploading' | 'error';

export default function VoiceMicButton({ missionId, senderProfileId, onMessageSent }: Props) {
  const [recordingState, setRecordingState] = useState<RecordingState>('idle');
  const [recordingTime, setRecordingTime]   = useState(0);
  const timerRef  = useRef<ReturnType<typeof setInterval> | null>(null);
  const pulseAnim = useRef(new Animated.Value(1)).current;

  const startPulse = () => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue:         1.3,
          duration:        600,
          easing:          Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue:         1,
          duration:        600,
          easing:          Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
      ])
    ).start();
  };

  const stopPulse = () => {
    pulseAnim.stopAnimation();
    pulseAnim.setValue(1);
  };

  async function onPressIn() {
    console.log('[FTM-DEBUG] Audio - Press in — starting voice recording', {
      missionId, senderProfileId,
    });

    setRecordingState('recording');
    setRecordingTime(0);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    startPulse();

    let seconds = 0;
    timerRef.current = setInterval(() => {
      seconds++;
      setRecordingTime(seconds);
      if (seconds >= 120) {
        if (timerRef.current) clearInterval(timerRef.current);
        onPressOut();
      }
    }, 1000);

    const result = await startRecording();
    if (result.error) {
      if (timerRef.current) clearInterval(timerRef.current);
      stopPulse();
      setRecordingState('error');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      setTimeout(() => setRecordingState('idle'), 2000);
    }
  }

  async function onPressOut() {
    if (timerRef.current) clearInterval(timerRef.current);
    stopPulse();
    setRecordingState('uploading');

    const stopResult = await stopRecording();
    if (stopResult.error) {
      setRecordingState('error');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      setTimeout(() => setRecordingState('idle'), 2000);
      return;
    }

    const uploadResult = await uploadVoiceMessage(
      missionId,
      senderProfileId,
      stopResult.uri!,
      stopResult.mimeType!,
      stopResult.duration!
    );

    if (uploadResult.error) {
      setRecordingState('error');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      setTimeout(() => setRecordingState('idle'), 2000);
      return;
    }

    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setRecordingState('idle');
    setRecordingTime(0);

    if (onMessageSent) {
      onMessageSent({
        url:       uploadResult.url!,
        duration:  uploadResult.duration!,
        filePath:  uploadResult.filePath!,
        sender:    senderProfileId,
        timestamp: new Date().toISOString(),
      });
    }

    console.log('[FTM-DEBUG] Audio - Voice message sent successfully', {
      missionId, duration: stopResult.duration + 's',
    });
  }

  const formatTime = (s: number) => {
    const m = Math.floor(s / 60).toString().padStart(2, '0');
    const sec = (s % 60).toString().padStart(2, '0');
    return `${m}:${sec}`;
  };

  const bgColor =
    recordingState === 'recording' ? (COLORS.alert ?? '#DC3545')
    : recordingState === 'error'   ? '#888'
    : recordingState === 'uploading' ? '#CCC'
    : (COLORS.cta ?? '#F39C12');

  return (
    <View style={styles.wrapper}>
      {recordingState === 'recording' && (
        <Text style={styles.recordingTimer}>{formatTime(recordingTime)}</Text>
      )}

      <Animated.View style={{ transform: [{ scale: pulseAnim }] }}>
        <TouchableOpacity
          style={[styles.button, { backgroundColor: bgColor }]}
          onPressIn={onPressIn}
          onPressOut={onPressOut}
          disabled={recordingState === 'uploading'}
          activeOpacity={0.85}
        >
          {recordingState === 'uploading' ? (
            <ActivityIndicator color="#FFF" size="small" />
          ) : (
            <Text style={styles.micIcon}>🎤</Text>
          )}
        </TouchableOpacity>
      </Animated.View>

      <Text style={styles.label}>
        {recordingState === 'idle'      && 'Maintenir pour parler en Darija'}
        {recordingState === 'recording' && 'Relâchez pour envoyer'}
        {recordingState === 'uploading' && 'Envoi...'}
        {recordingState === 'error'     && 'Erreur — Réessayez'}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    alignItems: 'center',
    padding:    16,
    gap:        8,
  },
  button: {
    width:          64,
    height:         64,
    borderRadius:   32,
    alignItems:     'center',
    justifyContent: 'center',
    elevation:      4,
    shadowColor:    '#000',
    shadowOffset:   { width: 0, height: 2 },
    shadowOpacity:  0.2,
    shadowRadius:   4,
  },
  micIcon: {
    fontSize: 28,
  },
  recordingTimer: {
    fontSize:   16,
    fontWeight: '700',
    color:      '#DC3545',
  },
  label: {
    fontSize:  12,
    color:     '#666',
    textAlign: 'center',
  },
});
ENDOFFILE

mkdir -p frontend/src/screens/notifications
cat > frontend/src/screens/notifications/NotificationCenterScreen.tsx << 'ENDOFFILE'
import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { COLORS } from '../../constants/theme';
import {
  getNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  handleNotificationTap,
} from '../../services/pushNotificationService';
import { NOTIF_ICONS } from '../../services/notificationTemplates';

// ─── Typage minimal notification ──────────────────────────────────────────────

interface NotifItem {
  id: string;
  profile_id: string;
  type: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
  is_read: boolean;
  created_at: string;
}

interface Props {
  profileId: string;
}

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const min  = Math.floor(diff / 60000);
  if (min < 1)  return 'À l\'instant';
  if (min < 60) return `Il y a ${min} min`;
  const h = Math.floor(min / 60);
  if (h < 24)   return `Il y a ${h}h`;
  return `Il y a ${Math.floor(h / 24)}j`;
}

export default function NotificationCenterScreen({ profileId }: Props) {
  const [notifications, setNotifications] = useState<NotifItem[]>([]);
  const [loading, setLoading]     = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [page, setPage]           = useState(0);
  const [hasMore, setHasMore]     = useState(false);
  const navigation = useNavigation<{ navigate: (screen: string, params?: Record<string, unknown>) => void }>();

  const load = useCallback(async (p = 0, refresh = false) => {
    if (refresh) setRefreshing(true);
    const result = await getNotifications(profileId, p);
    if (result.success) {
      const items = result.notifications as NotifItem[];
      setNotifications(prev => p === 0 ? items : [...prev, ...items]);
      setHasMore(result.hasMore ?? false);
      setPage(p);
    }
    setLoading(false);
    setRefreshing(false);
  }, [profileId]);

  useEffect(() => { load(0); }, [load]);

  const onRefresh = () => load(0, true);
  const onLoadMore = () => { if (hasMore && !loading) load(page + 1); };

  const onTap = async (item: NotifItem) => {
    if (!item.is_read) {
      await markNotificationRead(item.id, profileId);
      setNotifications(prev =>
        prev.map(n => n.id === item.id ? { ...n, is_read: true } : n)
      );
    }
    handleNotificationTap(
      { id: item.id, profile_id: item.profile_id, type: item.type, data: item.data },
      (screen, params) => navigation.navigate(screen, params)
    );
  };

  const onMarkAll = async () => {
    await markAllNotificationsRead(profileId);
    setNotifications(prev => prev.map(n => ({ ...n, is_read: true })));
  };

  const renderItem = ({ item }: { item: NotifItem }) => (
    <TouchableOpacity
      style={[styles.card, !item.is_read && styles.cardUnread]}
      onPress={() => onTap(item)}
    >
      {!item.is_read && <View style={styles.dot} />}
      <Text style={styles.icon}>{NOTIF_ICONS[item.type] ?? '🔔'}</Text>
      <View style={styles.content}>
        <Text style={styles.title}>{item.title}</Text>
        <Text style={styles.body} numberOfLines={2}>{item.body}</Text>
        <Text style={styles.time}>{timeAgo(item.created_at)}</Text>
      </View>
    </TouchableOpacity>
  );

  if (loading && notifications.length === 0) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={COLORS.primary ?? '#1A73E8'} size="large" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Notifications</Text>
        <TouchableOpacity onPress={onMarkAll}>
          <Text style={styles.markAll}>Tout lire</Text>
        </TouchableOpacity>
      </View>

      <FlatList
        data={notifications}
        keyExtractor={item => item.id}
        renderItem={renderItem}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        onEndReached={onLoadMore}
        onEndReachedThreshold={0.3}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={styles.emptyIcon}>🔔</Text>
            <Text style={styles.emptyText}>Aucune notification</Text>
          </View>
        }
        ListFooterComponent={
          hasMore ? <ActivityIndicator style={{ margin: 16 }} color={COLORS.primary ?? '#1A73E8'} /> : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container:   { flex: 1, backgroundColor: '#F5F5F5' },
  center:      { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header:      {
    flexDirection:   'row',
    justifyContent:  'space-between',
    alignItems:      'center',
    padding:         16,
    backgroundColor: '#FFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  headerTitle: { fontSize: 18, fontWeight: '700' },
  markAll:     { fontSize: 14, color: COLORS.primary ?? '#1A73E8', fontWeight: '600' },
  card: {
    flexDirection:   'row',
    backgroundColor: '#FFF',
    marginHorizontal: 12,
    marginVertical:  4,
    borderRadius:    10,
    padding:         12,
    alignItems:      'flex-start',
    gap:             10,
  },
  cardUnread:  { backgroundColor: '#EBF3FF' },
  dot: {
    width:           8,
    height:          8,
    borderRadius:    4,
    backgroundColor: COLORS.primary ?? '#1A73E8',
    marginTop:       6,
  },
  icon:        { fontSize: 22 },
  content:     { flex: 1 },
  title:       { fontSize: 14, fontWeight: '700', color: '#222', marginBottom: 2 },
  body:        { fontSize: 13, color: '#555', lineHeight: 18 },
  time:        { fontSize: 11, color: '#999', marginTop: 4 },
  empty:       { alignItems: 'center', marginTop: 80, gap: 12 },
  emptyIcon:   { fontSize: 48 },
  emptyText:   { fontSize: 16, color: '#888' },
});
ENDOFFILE

mkdir -p frontend/src/screens/mission
cat > frontend/src/screens/mission/VoiceChatScreen.tsx << 'ENDOFFILE'
import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import { COLORS } from '../../constants/theme';
import {
  loadVoiceMessages,
  playVoiceMessage,
  stopPlayback,
} from '../../services/audioService';
import VoiceMicButton from '../../components/VoiceMicButton';

interface VoiceMsg {
  id: string;
  fileName: string;
  url: string | null;
  sender: string;
  timestamp: Date | null;
  size: number;
  isPlaying?: boolean;
  progress?: number;
}

interface Props {
  missionId: string;
  currentProfileId: string;
  missionNumber: string;
}

function timeAgo(date: Date | null): string {
  if (!date) return '';
  const diff = Date.now() - date.getTime();
  const min  = Math.floor(diff / 60000);
  if (min < 1)  return 'À l\'instant';
  if (min < 60) return `Il y a ${min} min`;
  return `Il y a ${Math.floor(min / 60)}h`;
}

export default function VoiceChatScreen({
  missionId,
  currentProfileId,
  missionNumber,
}: Props) {
  const [messages, setMessages] = useState<VoiceMsg[]>([]);
  const [loading, setLoading]   = useState(true);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const flatRef = useRef<FlatList>(null);

  const fetchMessages = useCallback(async () => {
    setLoading(true);
    const result = await loadVoiceMessages(missionId);
    if (result.success && result.messages) {
      setMessages(result.messages as VoiceMsg[]);
    }
    setLoading(false);
  }, [missionId]);

  useEffect(() => { fetchMessages(); }, [fetchMessages]);

  const handlePlay = async (msg: VoiceMsg) => {
    if (!msg.url) return;

    if (playingId === msg.id) {
      await stopPlayback();
      setPlayingId(null);
      return;
    }

    await stopPlayback();
    setPlayingId(msg.id);

    await playVoiceMessage(
      msg.url,
      (progress) => {
        setMessages(prev =>
          prev.map(m => m.id === msg.id ? { ...m, progress } : m)
        );
      },
      () => setPlayingId(null)
    );
  };

  const onMessageSent = (newMsg: {
    url: string;
    duration: number;
    filePath: string;
    sender: string;
    timestamp: string;
  }) => {
    const item: VoiceMsg = {
      id:        `local_${Date.now()}`,
      fileName:  newMsg.filePath.split('/').pop() || '',
      url:       newMsg.url,
      sender:    newMsg.sender,
      timestamp: new Date(newMsg.timestamp),
      size:      0,
    };
    setMessages(prev => [...prev, item]);
    setTimeout(() => flatRef.current?.scrollToEnd({ animated: true }), 100);
  };

  const renderItem = ({ item }: { item: VoiceMsg }) => {
    const isOwn    = item.sender === currentProfileId;
    const isPlay   = playingId === item.id;
    const progress = item.progress ?? 0;

    return (
      <View style={[styles.msgRow, isOwn ? styles.msgRowRight : styles.msgRowLeft]}>
        <TouchableOpacity
          style={[styles.msgBubble, isOwn ? styles.msgBubbleOwn : styles.msgBubbleOther]}
          onPress={() => handlePlay(item)}
        >
          <Text style={styles.playIcon}>{isPlay ? '⏸' : '▶'}</Text>
          <View style={styles.progressBar}>
            <View style={[styles.progressFill, { width: `${progress * 100}%` }]} />
          </View>
          <Text style={styles.time}>{timeAgo(item.timestamp)}</Text>
        </TouchableOpacity>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>💬 Chat vocal — Mission FTM...{missionNumber.slice(-3)}</Text>
        <Text style={styles.headerSub}>Messages vocaux en Darija</Text>
      </View>

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator color={COLORS.primary ?? '#1A73E8'} />
        </View>
      ) : (
        <FlatList
          ref={flatRef}
          data={messages}
          keyExtractor={item => item.id}
          renderItem={renderItem}
          contentContainerStyle={styles.listContent}
          ListEmptyComponent={
            <View style={styles.empty}>
              <Text style={styles.emptyIcon}>🎤</Text>
              <Text style={styles.emptyTitle}>Pas encore de messages</Text>
              <Text style={styles.emptyBody}>
                Maintenez le bouton pour parler{'\n'}en Darija avec votre chauffeur
              </Text>
            </View>
          }
          onContentSizeChange={() => flatRef.current?.scrollToEnd({ animated: false })}
        />
      )}

      {/* Séparateur + VoiceMicButton */}
      <View style={styles.footer}>
        <View style={styles.divider} />
        <VoiceMicButton
          missionId={missionId}
          senderProfileId={currentProfileId}
          onMessageSent={onMessageSent}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container:  { flex: 1, backgroundColor: '#FAFAFA' },
  center:     { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header: {
    padding:         14,
    backgroundColor: '#FFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  headerTitle: { fontSize: 15, fontWeight: '700', color: '#222' },
  headerSub:   { fontSize: 12, color: '#888', marginTop: 2 },
  listContent: { padding: 12, flexGrow: 1 },
  msgRow:      { marginVertical: 4 },
  msgRowLeft:  { alignItems: 'flex-start' },
  msgRowRight: { alignItems: 'flex-end' },
  msgBubble: {
    flexDirection:  'row',
    alignItems:     'center',
    gap:            8,
    padding:        10,
    borderRadius:   12,
    maxWidth:       '80%',
  },
  msgBubbleOther: { backgroundColor: '#F0F0F0' },
  msgBubbleOwn:   { backgroundColor: (COLORS.primary ?? '#1A73E8') + '20' },
  playIcon:    { fontSize: 18 },
  progressBar: {
    flex:            1,
    height:          4,
    backgroundColor: '#DDD',
    borderRadius:    2,
    overflow:        'hidden',
  },
  progressFill: { height: '100%', backgroundColor: COLORS.primary ?? '#1A73E8' },
  time:        { fontSize: 10, color: '#999', minWidth: 50 },
  empty:       { flex: 1, alignItems: 'center', justifyContent: 'center', marginTop: 80, gap: 10 },
  emptyIcon:   { fontSize: 48 },
  emptyTitle:  { fontSize: 16, fontWeight: '700', color: '#444' },
  emptyBody:   { fontSize: 13, color: '#888', textAlign: 'center', lineHeight: 20 },
  footer:      { backgroundColor: '#FFF' },
  divider:     { height: 1, backgroundColor: '#E0E0E0' },
});
ENDOFFILE

mkdir -p supabase/functions/check-document-reminders
cat > supabase/functions/check-document-reminders/index.ts << 'ENDOFFILE'
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
ENDOFFILE

mkdir -p supabase/functions/send-push-notification
cat > supabase/functions/send-push-notification/index.ts << 'ENDOFFILE'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/*
 * Edge Function : send-push-notification
 * Rôle : récupère les tokens FCM/APNs du profil et envoie la notification push
 *        via l'API Expo Push Notifications (compatible FCM + APNs)
 */

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

serve(async (req) => {
  try {
    const {
      profile_id,
      notification_id,
      type,
      title,
      body,
      data = {},
      channel_id = 'ftm_default',
    } = await req.json();

    if (!profile_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: profile_id, title, body' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Récupérer les tokens du profil
    const { data: tokens, error: tokensError } = await supabase
      .from('push_tokens')
      .select('token, platform')
      .eq('profile_id', profile_id);

    if (tokensError) {
      console.error('[FTM-DEBUG] Push - Fetch tokens error', tokensError.message);
      return new Response(
        JSON.stringify({ error: tokensError.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    if (!tokens || tokens.length === 0) {
      console.log('[FTM-DEBUG] Push - No tokens for profile', { profile_id });
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: 'No push tokens registered' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Préparer les messages pour l'API Expo Push
    const messages = tokens.map((t: { token: string; platform: string }) => ({
      to:         t.token,
      title,
      body,
      data:       { ...data, type, notification_id, channel_id },
      sound:      'default',
      channelId:  channel_id,
      priority:   type.includes('mission') ? 'high' : 'normal',
    }));

    // Envoyer via Expo Push API
    const expoPushResp = await fetch('https://exp.host/--/api/v2/push/send', {
      method:  'POST',
      headers: {
        'Content-Type':  'application/json',
        'Accept':        'application/json',
        'Accept-Encoding': 'gzip, deflate',
      },
      body: JSON.stringify(messages),
    });

    const expoPushData = await expoPushResp.json();

    const sentCount = messages.length;
    console.log('[FTM-DEBUG] Push - Dispatched successfully', {
      notification_id, profile_id, type, sentCount,
    });

    return new Response(
      JSON.stringify({ success: true, sent: sentCount, expoPushData }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('[FTM-DEBUG] Push - send-push-notification exception', msg);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
ENDOFFILE

mkdir -p supabase/functions/register-push-token
cat > supabase/functions/register-push-token/index.ts << 'ENDOFFILE'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/*
 * Edge Function : register-push-token
 * Rôle : enregistre ou met à jour le token FCM/APNs d'un device
 *
 * Table attendue dans Supabase :
 *   CREATE TABLE push_tokens (
 *     id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
 *     profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
 *     token      TEXT NOT NULL,
 *     platform   VARCHAR(10) NOT NULL, -- 'android' | 'ios'
 *     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
 *     updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
 *     UNIQUE(profile_id, token)
 *   );
 */

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

serve(async (req) => {
  try {
    const { profile_id, token, platform } = await req.json();

    if (!profile_id || !token || !platform) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: profile_id, token, platform' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log('[FTM-DEBUG] Push - Registering device token', {
      profile_id,
      platform,
      tokenPreview: token.substring(0, 20) + '...',
    });

    // Upsert : insert ou update si le token existe déjà
    const { error } = await supabase
      .from('push_tokens')
      .upsert(
        {
          profile_id,
          token,
          platform,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'profile_id,token' }
      );

    if (error) {
      console.error('[FTM-DEBUG] Push - Token registration error', error.message);
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log('[FTM-DEBUG] Push - Token registered successfully', {
      profile_id,
      platform,
    });

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('[FTM-DEBUG] Push - register-push-token exception', msg);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
ENDOFFILE

echo "✅ Fichiers P6 créés"