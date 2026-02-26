# SPEC NATIVELY — Fast Trans Maroc (FTM)
# PARTIE P6 : Notifications Push & Chat Audio Darija
# Fichier : docs/SPEC_NATIVELY_P6.md
# Version : 1.0 | Backend : Supabase | App : Natively.dev
# =====================================================================
# PRÉREQUIS : P1 (Auth + profiles), P2 (document_reminders),
#             P3 (missions Realtime), P5 (wallet notifications)
# TABLES SQL : notifications, document_reminders, profiles, drivers
# STORAGE    : bucket "voice-messages"
# NATIVELY   : Push Notifications + Microphone + Audio Playback
# =====================================================================

---

## 1. CONTEXTE & ARCHITECTURE NOTIFICATIONS

```
ARCHITECTURE GLOBALE DES NOTIFICATIONS FTM

                    ┌─────────────────────────────────┐
                    │     SOURCES D'ÉVÉNEMENTS        │
                    └─────────────────────────────────┘
                           │              │
          ┌────────────────┤              ├────────────────┐
          ▼                ▼              ▼                ▼
    Triggers SQL     Edge Functions   Realtime        App (P5)
    (commission,     (cron J-30/      (missions,      (wallet
     mission status)  J-15/J-7)       wallet)          low)
          │                │              │                │
          └────────────────┴──────────────┴────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────┐
                    │  INSERT notifications    │
                    │  (table Supabase)        │
                    └──────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
          Realtime (app ouverte)       Push FCM/APNs
          → Badge + In-App Banner      (app fermée/bg)
          → Marquer is_read=true       → Notification système
```

---

## 2. STRUCTURE SQL DE RÉFÉRENCE

### 2.1 Table notifications

```sql
-- TABLE: notifications — Source de vérité
CREATE TABLE notifications (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,

    -- Contenu affiché
    title      VARCHAR(255) NOT NULL,
    body       TEXT         NOT NULL,

    -- Type pour le routing dans l'app
    type       VARCHAR(50)  NOT NULL,
    -- Types FTM :
    -- 'new_mission'         → Nouvelle mission disponible (Driver)
    -- 'mission_accepted'    → Mission acceptée par un driver (Client)
    -- 'mission_started'     → Chauffeur est arrivé (Client)
    -- 'mission_completed'   → Mission terminée (Client + Driver)
    -- 'mission_cancelled'   → Mission annulée (Client ou Driver)
    -- 'wallet_low_balance'  → Solde wallet insuffisant (Driver)
    -- 'document_expiry'     → Document expirant bientôt (Driver)
    -- 'document_rejected'   → Document refusé par Admin (Driver)
    -- 'document_verified'   → Document validé par Admin (Driver)
    -- 'parcel_status'       → Changement statut colis (Client e-commerce)

    -- Données additionnelles pour deep link in-app
    data       JSONB,
    -- Ex: { "mission_id": "...", "screen": "MissionTrackingScreen" }
    --     { "document_type": "driver_license", "screen": "DocumentStatusScreen" }
    --     { "wallet_id": "...", "screen": "WalletTopupScreen" }

    -- Statut lecture
    is_read    BOOLEAN                  DEFAULT false,
    read_at    TIMESTAMP WITH TIME ZONE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- INDEX critiques pour performance
CREATE INDEX idx_notifications_profile ON notifications(profile_id);
CREATE INDEX idx_notifications_unread
    ON notifications(profile_id, is_read) WHERE is_read = false;
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);
```

### 2.2 Table document_reminders (rappel)

```sql
-- TABLE: document_reminders — rappel pour P6
CREATE TABLE document_reminders (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id     UUID REFERENCES drivers(id) ON DELETE CASCADE NOT NULL,
    document_type VARCHAR(50) NOT NULL,
    -- 'driver_license' | 'insurance' | 'technical_inspection'
    expiry_date   DATE NOT NULL,

    -- Flags envoi rappels (mis à true après envoi)
    reminder_30_days_sent BOOLEAN DEFAULT false,
    reminder_15_days_sent BOOLEAN DEFAULT false,
    reminder_7_days_sent  BOOLEAN DEFAULT false,

    created_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## 3. CONFIGURATION PUSH NOTIFICATIONS — NATIVELY

### 3.1 Permissions & Setup Natively

```javascript
// /services/pushNotificationService.js

/**
 * CONFIGURATION NATIVELY (Dashboard Natively.dev) :
 *
 * ANDROID :
 *   ✅ Firebase Cloud Messaging (FCM) activé
 *   Fichier google-services.json uploadé dans Natively
 *   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
 *   (Android 13+ exige permission explicite)
 *
 * iOS :
 *   ✅ Push Notifications capability activée
 *   APNs certificates configurés dans Natively
 *   Info.plist : NSUserNotificationUsageDescription
 *
 * NATIVELY CONFIG BLOCK :
 *   notifications: {
 *     enabled: true,
 *     fcm: true,
 *     apns: true,
 *     default_channel: "ftm_default",
 *     channels: [
 *       {
 *         id: "ftm_missions",
 *         name: "Missions FTM",
 *         importance: "high",     // Heads-up notification
 *         sound: "mission_alert", // Son personnalisé
 *         vibration: true,
 *       },
 *       {
 *         id: "ftm_wallet",
 *         name: "Wallet FTM",
 *         importance: "high",
 *         sound: "default",
 *       },
 *       {
 *         id: "ftm_documents",
 *         name: "Documents FTM",
 *         importance: "default",
 *         sound: "default",
 *       }
 *     ]
 *   }
 */
```

### 3.2 Service Push Notification

```javascript
// /services/pushNotificationService.js

import { supabase } from '../lib/supabaseClient';

/**
 * DEMANDER LA PERMISSION PUSH (Android 13+ et iOS)
 */
export async function requestPushPermission() {
  console.log('[FTM-DEBUG] Push - Requesting push permission');

  const { status } = await NativelyPush.requestPermission();

  console.log('[FTM-DEBUG] Push - Permission result', { status });

  if (status !== 'granted') {
    console.log('[FTM-DEBUG] Push - Permission denied', { status });
    return { granted: false };
  }

  const token = await NativelyPush.getToken();

  console.log('[FTM-DEBUG] Push - Token obtained', {
    tokenPreview: token?.substring(0, 20) + '...',
  });

  return { granted: true, token };
}

/**
 * ENREGISTRER LE TOKEN FCM/APNs DU DEVICE
 */
export async function registerPushToken(profileId, token, platform) {
  console.log('[FTM-DEBUG] Push - Registering device token', {
    profileId,
    platform,
    tokenPreview: token?.substring(0, 20) + '...',
  });

  const { error } = await supabase.functions.invoke('register-push-token', {
    body: { profile_id: profileId, token, platform },
  });

  if (error) {
    console.log('[FTM-DEBUG] Push - Token registration error', {
      error: error.message,
    });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Push - Token registered successfully', {
    profileId,
    platform,
  });

  return { success: true };
}

/**
 * INSÉRER UNE NOTIFICATION EN BASE
 * Point d'entrée unique pour toutes les notifs FTM
 */
export async function insertNotification(profileId, type, title, body, data = {}) {
  console.log('[FTM-DEBUG] Push - Inserting notification', {
    profileId,
    type,
    title,
  });

  const { data: notif, error } = await supabase
    .from('notifications')
    .insert({
      profile_id: profileId,
      type,
      title,
      body,
      data,
      is_read: false,
    })
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Push - Insert notification error', {
      error: error.message,
      type,
    });
    return { error };
  }

  console.log('[FTM-DEBUG] Push - Notification inserted', {
    notificationId: notif.id,
    profileId,
    type,
  });

  // Déclencher l'envoi Push via Edge Function
  await dispatchPushNotification(profileId, type, title, body, data, notif.id);

  return { success: true, notification: notif };
}

/**
 * DISPATCHER L'ENVOI PUSH VERS L'EDGE FUNCTION
 */
async function dispatchPushNotification(profileId, type, title, body, data, notifId) {
  console.log('[FTM-DEBUG] Push - Dispatching push notification', {
    profileId,
    type,
    notifId,
  });

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
      console.log('[FTM-DEBUG] Push - Dispatch error', {
        error: error.message, type, notifId,
      });
    } else {
      console.log('[FTM-DEBUG] Push - Dispatched successfully', { notifId, type });
    }
  } catch (err) {
    console.log('[FTM-DEBUG] Push - Dispatch exception', { err: err.message });
  }
}

/**
 * MAPPING TYPE → CHANNEL ANDROID
 */
function getChannelForType(type) {
  const channelMap = {
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

/**
 * MARQUER UNE NOTIFICATION COMME LUE
 */
export async function markNotificationRead(notificationId, profileId) {
  console.log('[FTM-DEBUG] Push - Marking notification as read', { notificationId });

  const { error } = await supabase
    .from('notifications')
    .update({ is_read: true, read_at: new Date().toISOString() })
    .eq('id',         notificationId)
    .eq('profile_id', profileId);

  if (error) {
    console.log('[FTM-DEBUG] Push - Mark read error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Push - Notification marked as read', { notificationId });
  return { success: true };
}

/**
 * MARQUER TOUTES LES NOTIFICATIONS COMME LUES
 */
export async function markAllNotificationsRead(profileId) {
  console.log('[FTM-DEBUG] Push - Marking all notifications as read', { profileId });

  const { error } = await supabase
    .from('notifications')
    .update({ is_read: true, read_at: new Date().toISOString() })
    .eq('profile_id', profileId)
    .eq('is_read',    false);

  if (error) {
    console.log('[FTM-DEBUG] Push - Mark all read error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Push - All notifications marked as read', { profileId });
  return { success: true };
}

/**
 * RÉCUPÉRER LES NOTIFICATIONS (paginées)
 */
export async function getNotifications(profileId, page = 0, unreadOnly = false) {
  const PAGE_SIZE = 30;
  const from      = page * PAGE_SIZE;
  const to        = from + PAGE_SIZE - 1;

  console.log('[FTM-DEBUG] Push - Fetching notifications', {
    profileId, page, unreadOnly,
  });

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

  const unreadCount = data?.filter(n => !n.is_read).length || 0;

  console.log('[FTM-DEBUG] Push - Notifications fetched', {
    profileId,
    total:   count,
    fetched: data?.length,
    unread:  unreadCount,
  });

  return {
    success:       true,
    notifications: data || [],
    totalCount:    count,
    unreadCount,
    hasMore:       (from + PAGE_SIZE) < count,
  };
}

/**
 * ÉCOUTER LES NOUVELLES NOTIFICATIONS EN TEMPS RÉEL
 */
export function subscribeToNotifications(profileId, onNewNotification) {
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
        const notif = payload.new;
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

/**
 * HANDLER GLOBAL — Notifications reçues
 * À configurer dans App.js au démarrage
 */
export function setupPushHandlers(navigate) {
  console.log('[FTM-DEBUG] Push - Setting up push handlers');

  // 1. App EN PREMIER PLAN → Banner In-App
  NativelyPush.onForegroundNotification((notification) => {
    console.log('[FTM-DEBUG] Push - Foreground notification received', {
      type:  notification.data?.type,
      title: notification.title,
    });
    showInAppBanner({
      icon:     NOTIF_ICONS[notification.data?.type] || '🔔',
      title:    notification.title,
      body:     notification.body,
      onTap:    () => handleNotificationTap(notification, navigate),
      duration: 4000,
    });
  });

  // 2. App EN ARRIÈRE-PLAN ou FERMÉE → Tap notification système
  NativelyPush.onBackgroundNotificationTap((notification) => {
    console.log('[FTM-DEBUG] Push - Background notification tapped', {
      type:   notification.data?.type,
      screen: notification.data?.screen,
    });
    handleNotificationTap(notification, navigate);
  });

  // 3. Cold start depuis une notification
  NativelyPush.getInitialNotification().then((notification) => {
    if (notification) {
      console.log('[FTM-DEBUG] Push - App opened from notification', {
        type:   notification.data?.type,
        screen: notification.data?.screen,
      });
      handleNotificationTap(notification, navigate);
    }
  });

  console.log('[FTM-DEBUG] Push - Push handlers configured');
}
```

---

## 4. NOTIFICATIONS MÉTIER PAR TYPE

```javascript
// /services/notificationTemplates.js

import { insertNotification } from './pushNotificationService';

export const NOTIF_ICONS = {
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

// ─── MISSIONS ─────────────────────────────────────────────────────────

export async function notifyNewMission(driverProfileId, mission) {
  console.log('[FTM-DEBUG] Push - Notify new mission', {
    driverProfileId,
    missionId:     mission.id,
    missionNumber: mission.mission_number,
  });
  return insertNotification(
    driverProfileId, 'new_mission',
    '🚚 Nouvelle mission disponible !',
    `${mission.pickup_city} → ${mission.dropoff_city} | Commission : ${mission.commission_amount} DH`,
    { mission_id: mission.id, mission_number: mission.mission_number, screen: 'NewMissionModal' }
  );
}

export async function notifyMissionAccepted(clientProfileId, mission, driverName) {
  console.log('[FTM-DEBUG] Push - Notify mission accepted', {
    clientProfileId, missionId: mission.id, driverName,
  });
  return insertNotification(
    clientProfileId, 'mission_accepted',
    '✅ Chauffeur trouvé !',
    `${driverName} a accepté votre mission ${mission.mission_number}. Il arrive bientôt.`,
    { mission_id: mission.id, screen: 'MissionTrackingScreen' }
  );
}

export async function notifyMissionStarted(clientProfileId, mission) {
  console.log('[FTM-DEBUG] Push - Notify mission started', {
    clientProfileId, missionId: mission.id,
  });
  return insertNotification(
    clientProfileId, 'mission_started',
    '🚛 Chargement en cours',
    `Votre mission ${mission.mission_number} a démarré. Trajet en cours vers ${mission.dropoff_city}.`,
    { mission_id: mission.id, screen: 'MissionTrackingScreen' }
  );
}

export async function notifyMissionCompleted(clientProfileId, driverProfileId, mission) {
  console.log('[FTM-DEBUG] Push - Notify mission completed', {
    clientProfileId, driverProfileId, missionId: mission.id,
  });
  await insertNotification(
    clientProfileId, 'mission_completed',
    '🏁 Mission terminée !',
    `Mission ${mission.mission_number} livrée à ${mission.dropoff_city}. Évaluez votre chauffeur.`,
    { mission_id: mission.id, screen: 'RatingScreen' }
  );
  return insertNotification(
    driverProfileId, 'mission_completed',
    '💰 Commission prélevée',
    `Mission ${mission.mission_number} clôturée. Commission de ${mission.commission_amount} DH déduite.`,
    { mission_id: mission.id, screen: 'WalletDashboardScreen' }
  );
}

export async function notifyMissionCancelled(profileId, mission, cancelledBy) {
  const byLabel = cancelledBy === 'client' ? 'le client' : 'le chauffeur';
  console.log('[FTM-DEBUG] Push - Notify mission cancelled', {
    profileId, missionId: mission.id, cancelledBy,
  });
  return insertNotification(
    profileId, 'mission_cancelled',
    '❌ Mission annulée',
    `La mission ${mission.mission_number} a été annulée par ${byLabel}.`,
    { mission_id: mission.id, screen: 'ClientHomeStack' }
  );
}

// ─── DOCUMENTS ────────────────────────────────────────────────────────

export async function notifyDocumentExpiry(driverProfileId, documentType, expiryDate, daysLeft) {
  const docLabels = {
    driver_license:       'Permis de conduire',
    insurance:            'Assurance',
    technical_inspection: 'Visite technique',
  };
  const docLabel = docLabels[documentType] || documentType;
  let urgency = daysLeft <= 7 ? '🔴 URGENT — ' : daysLeft <= 15 ? '🟠 ' : '🟡 ';

  console.log('[FTM-DEBUG] Push - Notify document expiry', {
    driverProfileId, documentType, expiryDate, daysLeft,
  });

  return insertNotification(
    driverProfileId, 'document_expiry',
    `${urgency}${docLabel} expire dans ${daysLeft} jours`,
    `Votre ${docLabel} expire le ${expiryDate}. Renouvelez-le pour rester actif sur FTM.`,
    { document_type: documentType, expiry_date: expiryDate, days_left: daysLeft, screen: 'DocumentStatusScreen' }
  );
}

export async function notifyDocumentVerified(driverProfileId, documentType) {
  const docLabels = {
    driver_license: 'Permis de conduire', vehicle_registration: 'Carte grise',
    insurance: 'Assurance', technical_inspection: 'Visite technique',
  };
  console.log('[FTM-DEBUG] Push - Notify document verified', { driverProfileId, documentType });
  return insertNotification(
    driverProfileId, 'document_verified',
    '✅ Document validé',
    `Votre ${docLabels[documentType]} a été approuvé. Continuez à accepter des missions.`,
    { document_type: documentType, screen: 'DocumentStatusScreen' }
  );
}

export async function notifyDocumentRejected(driverProfileId, documentType, reason) {
  const docLabels = {
    driver_license: 'Permis de conduire', vehicle_registration: 'Carte grise',
    insurance: 'Assurance', technical_inspection: 'Visite technique',
  };
  console.log('[FTM-DEBUG] Push - Notify document rejected', {
    driverProfileId, documentType, reason,
  });
  return insertNotification(
    driverProfileId, 'document_rejected',
    '❌ Document refusé — Action requise',
    `Votre ${docLabels[documentType]} a été refusé : "${reason}". Re-uploadez un document valide.`,
    { document_type: documentType, reason, screen: 'DocumentStatusScreen' }
  );
}
```

---

## 5. CRON — RAPPELS DOCUMENTS J-30 / J-15 / J-7

```javascript
// supabase/functions/check-document-reminders/index.ts
// Edge Function déclenchée chaque matin à 08:00 par pg_cron

/**
 * PLANIFICATION CRON Supabase Dashboard → Database → Cron Jobs :
 *
 * select cron.schedule(
 *   'check-document-reminders',
 *   '0 8 * * *',   -- tous les jours à 08:00
 *   $$
 *     select net.http_post(
 *       url := 'https://[project].supabase.co/functions/v1/check-document-reminders',
 *       headers := '{"Authorization": "Bearer [SERVICE_ROLE_KEY]"}'::jsonb
 *     )
 *   $$
 * );
 */

export async function checkDocumentReminders() {
  const today   = new Date();
  const results = { sent: 0, errors: 0 };

  console.log('[FTM-DEBUG] Reminders - CRON started', {
    timestamp: today.toISOString(),
  });

  // ─── HELPER : Traiter une vague de rappels ─────────────────────
  async function processReminders(reminders, flagColumn, label) {
    console.log(`[FTM-DEBUG] Reminders - ${label} candidates`, {
      count: reminders?.length || 0,
    });

    for (const reminder of (reminders || [])) {
      const daysLeft = Math.ceil(
        (new Date(reminder.expiry_date) - today) / (1000 * 60 * 60 * 24)
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
      } catch (err) {
        console.log(`[FTM-DEBUG] Reminders - ${label} error`, {
          reminderId: reminder.id, err: err.message,
        });
        results.errors++;
      }
    }
  }

  // ─── J-30 ──────────────────────────────────────────────────────
  const date30 = new Date(today); date30.setDate(today.getDate() + 30);
  const { data: r30 } = await supabase
    .from('document_reminders')
    .select('id, document_type, expiry_date, drivers(id, profile_id)')
    .lte('expiry_date', date30.toISOString().split('T')[0])
    .gte('expiry_date', today.toISOString().split('T')[0])
    .eq('reminder_30_days_sent', false);
  await processReminders(r30, 'reminder_30_days_sent', 'J-30');

  // ─── J-15 ──────────────────────────────────────────────────────
  const date15 = new Date(today); date15.setDate(today.getDate() + 15);
  const { data: r15 } = await supabase
    .from('document_reminders')
    .select('id, document_type, expiry_date, drivers(id, profile_id)')
    .lte('expiry_date', date15.toISOString().split('T')[0])
    .gte('expiry_date', today.toISOString().split('T')[0])
    .eq('reminder_15_days_sent', false);
  await processReminders(r15, 'reminder_15_days_sent', 'J-15');

  // ─── J-7 ───────────────────────────────────────────────────────
  const date7 = new Date(today); date7.setDate(today.getDate() + 7);
  const { data: r7 } = await supabase
    .from('document_reminders')
    .select('id, document_type, expiry_date, drivers(id, profile_id)')
    .lte('expiry_date', date7.toISOString().split('T')[0])
    .gte('expiry_date', today.toISOString().split('T')[0])
    .eq('reminder_7_days_sent', false);
  await processReminders(r7, 'reminder_7_days_sent', 'J-7');

  console.log('[FTM-DEBUG] Reminders - CRON completed', {
    totalSent:   results.sent,
    totalErrors: results.errors,
    timestamp:   new Date().toISOString(),
  });

  return results;
}
```

---

## 6. MODULE CHAT AUDIO DARIJA

### 6.1 Configuration Storage — Bucket "voice-messages"

```javascript
/**
 * BUCKET SUPABASE STORAGE : voice-messages
 *
 * Configuration Dashboard :
 *   Nom         : voice-messages
 *   Public      : false (URLs signées uniquement)
 *   MIME autorisés : audio/m4a, audio/wav, audio/mpeg, audio/aac, audio/mp4
 *   Taille max  : 10 MB par fichier (~ 5 min de voix)
 *
 * Structure des chemins :
 * voice-messages/
 * └── missions/
 *     └── {mission_id}/
 *         └── {sender_profile_id}_{timestamp}.m4a
 *
 * NATIVELY CONFIG :
 *   Android : <uses-permission android:name="android.permission.RECORD_AUDIO"/>
 *   iOS     : NSMicrophoneUsageDescription
 *             → "FTM utilise le micro pour les messages vocaux Darija"
 */
```

```sql
-- Policies RLS Storage voice-messages
CREATE POLICY "Mission participants can upload voice"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'voice-messages'
  AND EXISTS (
    SELECT 1 FROM missions m
    WHERE m.id::text = (storage.foldername(name))[2]
    AND (
      m.client_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
      OR m.driver_id IN (
        SELECT id FROM drivers WHERE profile_id IN (
          SELECT id FROM profiles WHERE user_id = auth.uid()
        )
      )
    )
  )
);

CREATE POLICY "Mission participants can read voice"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'voice-messages'
  AND EXISTS (
    SELECT 1 FROM missions m
    WHERE m.id::text = (storage.foldername(name))[2]
    AND (
      m.client_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
      OR m.driver_id IN (
        SELECT id FROM drivers WHERE profile_id IN (
          SELECT id FROM profiles WHERE user_id = auth.uid()
        )
      )
    )
  )
);
```

### 6.2 Service Audio

```javascript
// /services/audioService.js

import { supabase } from '../lib/supabaseClient';

/**
 * DEMANDER LA PERMISSION MICROPHONE
 */
export async function requestMicrophonePermission() {
  console.log('[FTM-DEBUG] Audio - Requesting microphone permission');

  const { status } = await NativelyAudio.requestMicrophonePermission();

  console.log('[FTM-DEBUG] Audio - Microphone permission result', { status });

  if (status !== 'granted') {
    return {
      granted: false,
      error: 'Permission microphone refusée. Activez-la dans les réglages.',
    };
  }
  return { granted: true };
}

/**
 * DÉMARRER UN ENREGISTREMENT
 * Format M4A/AAC : optimal mobile — qualité vocale, taille réduite
 * Durée max : 120 secondes
 */
export async function startRecording() {
  console.log('[FTM-DEBUG] Audio - Starting recording');

  const perms = await requestMicrophonePermission();
  if (!perms.granted) return { error: perms.error };

  try {
    await NativelyAudio.startRecording({
      format:      'aac',   // → fichier .m4a
      sampleRate:  22050,   // 22 kHz — suffisant pour la voix
      channels:    1,       // Mono
      bitRate:     64000,   // 64 kbps
      maxDuration: 120,     // 2 minutes max
    });

    console.log('[FTM-DEBUG] Audio - Recording started', {
      format: 'aac/m4a', sampleRate: '22050 Hz', maxDuration: '120s',
    });
    return { success: true };

  } catch (err) {
    console.log('[FTM-DEBUG] Audio - Start recording error', { err: err.message });
    return { error: 'Impossible de démarrer l\'enregistrement.' };
  }
}

/**
 * ARRÊTER L'ENREGISTREMENT
 */
export async function stopRecording() {
  console.log('[FTM-DEBUG] Audio - Stopping recording');

  try {
    const result = await NativelyAudio.stopRecording();

    console.log('[FTM-DEBUG] Audio - Recording stopped', {
      duration: result.duration + 's',
      fileSize: (result.size / 1024).toFixed(1) + ' KB',
      mimeType: result.mimeType,
    });

    if (result.duration < 1) {
      console.log('[FTM-DEBUG] Audio - Recording too short', { duration: result.duration });
      return { error: 'Message trop court. Maintenez appuyé pour enregistrer.' };
    }

    return {
      success:  true,
      uri:      result.uri,
      duration: result.duration,
      size:     result.size,
      mimeType: result.mimeType,
    };

  } catch (err) {
    console.log('[FTM-DEBUG] Audio - Stop recording error', { err: err.message });
    return { error: 'Erreur lors de l\'arrêt de l\'enregistrement.' };
  }
}

/**
 * UPLOADER UN MESSAGE VOCAL VERS SUPABASE STORAGE
 */
export async function uploadVoiceMessage(missionId, senderProfileId, localUri, mimeType, duration) {
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

    // URL signée 7 jours
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

  } catch (err) {
    console.log('[FTM-DEBUG] Audio - Upload exception', { err: err.message });
    return { error: 'Erreur réseau lors de l\'envoi du message.' };
  }
}

/**
 * LIRE UN MESSAGE VOCAL
 */
export async function playVoiceMessage(url, onProgress, onComplete) {
  console.log('[FTM-DEBUG] Audio - Playing voice message', {
    url: url.substring(0, 60) + '...',
  });

  try {
    await NativelyAudio.playFromUrl(url, {
      onProgress: (p) => { if (onProgress) onProgress(p); },
      onComplete: () => {
        console.log('[FTM-DEBUG] Audio - Playback completed');
        if (onComplete) onComplete();
      },
      onError: (err) => {
        console.log('[FTM-DEBUG] Audio - Playback error', { err });
      },
    });
    console.log('[FTM-DEBUG] Audio - Playback started');
    return { success: true };
  } catch (err) {
    console.log('[FTM-DEBUG] Audio - Play exception', { err: err.message });
    return { error: 'Impossible de lire le message.' };
  }
}

/**
 * ARRÊTER LA LECTURE
 */
export async function stopPlayback() {
  console.log('[FTM-DEBUG] Audio - Stopping playback');
  await NativelyAudio.stopPlayback();
}

/**
 * CHARGER LES MESSAGES VOCAUX D'UNE MISSION
 */
export async function loadVoiceMessages(missionId) {
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

  // Générer les URLs signées + parser les métadonnées du nom de fichier
  const messagesWithUrls = await Promise.all(
    (data || []).map(async (file) => {
      const { data: signed } = await supabase.storage
        .from('voice-messages')
        .createSignedUrl(`missions/${missionId}/${file.name}`, 3600);

      const [senderPart, tsPart] = file.name.split('_');
      const tsMs = tsPart?.split('.')[0];

      return {
        id:        file.id,
        fileName:  file.name,
        url:       signed?.signedUrl,
        sender:    senderPart,
        timestamp: tsMs ? new Date(parseInt(tsMs)) : null,
        size:      file.metadata?.size || 0,
      };
    })
  );

  console.log('[FTM-DEBUG] Audio - Voice messages loaded', {
    missionId, count: messagesWithUrls.length,
  });

  return { success: true, messages: messagesWithUrls };
}
```

---

## 7. ÉCRANS NOTIFICATIONS & CHAT AUDIO

### 7.1 Composant — Cloche de Notification (Header Badge)

```javascript
// /components/NotificationBell.js
// Composant réutilisable dans le header de toutes les pages

/**
 * UI — NotificationBell
 *
 * LAYOUT :
 *   🔔 [Badge rouge arrondi]
 *      "3" ou "99+" si > 99
 *
 * COMPORTEMENT :
 * - Badge masqué si unreadCount === 0
 * - Tap → NotificationCenterScreen
 * - subscribeToNotifications() actif en permanence
 * - Nouvelle notif → counter++ + NativelyHaptics.light()
 */
```

### 7.2 Centre de Notifications

```javascript
// /screens/notifications/NotificationCenterScreen.js

/**
 * DEEP LINK — Navigation depuis une notification
 */
async function handleNotificationTap(notification, navigate) {
  console.log('[FTM-DEBUG] Push - Notification tapped', {
    notifId: notification.id,
    type:    notification.type,
    screen:  notification.data?.screen,
  });

  await markNotificationRead(notification.id, notification.profile_id);

  const screenMap = {
    MissionTrackingScreen: () => navigate('MissionTracking',  { missionId: notification.data.mission_id }),
    NewMissionModal:       () => navigate('DriverHome',       { openMission: notification.data.mission_id }),
    WalletDashboardScreen: () => navigate('WalletDashboard'),
    WalletTopupScreen:     () => navigate('WalletTopup'),
    DocumentStatusScreen:  () => navigate('DocumentStatus',   { highlight: notification.data.document_type }),
    RatingScreen:          () => navigate('Rating',           { missionId: notification.data.mission_id }),
  };

  const fn = screenMap[notification.data?.screen];
  if (fn) {
    fn();
    console.log('[FTM-DEBUG] Push - Navigated from notification', {
      screen: notification.data.screen,
    });
  }
}

/**
 * UI — NotificationCenterScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────────┐
 * │  ← Notifications         [Tout lire]│
 * │                                      │
 * │  ┌──────────────────────────────┐   │
 * │  │ 🚚 Nouvelle mission !        │   │  ← Fond #EBF3FF si non-lu
 * │  │ Casa → Marrakech — 25 DH    │   │  ← Point bleu (COLORS.primary)
 * │  │ Il y a 5 minutes            │   │
 * │  └──────────────────────────────┘   │
 * │  ┌──────────────────────────────┐   │
 * │  │ ⚠️ Permis expire dans 15j    │   │  ← Fond blanc si lu
 * │  │ Renouvelez avant le 10/03   │   │
 * │  └──────────────────────────────┘   │
 * │  ┌──────────────────────────────┐   │
 * │  │ 💸 Wallet insuffisant        │   │
 * │  │ Rechargez 40 DH min.        │   │
 * │  └──────────────────────────────┘   │
 * │  [Charger plus...]                  │
 * └──────────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - Non-lue : fond #EBF3FF + point bleu gauche
 * - Lue     : fond blanc, pas de point
 * - Tap → handleNotificationTap() + deep link
 * - [Tout lire] → markAllNotificationsRead()
 * - Pull-to-refresh pour recharger
 */
```

### 7.3 Bouton Micro — VoiceMicButton

```javascript
// /components/VoiceMicButton.js
// Bouton flottant orange — intégré dans MissionTrackingScreen
// et MissionActiveScreen pendant les missions actives

/**
 * ÉTAT GÉRÉ DANS LE PARENT :
 * - recordingState : 'idle' | 'recording' | 'uploading' | 'error'
 * - recordingTime  : number (secondes, max 120)
 */

/**
 * CYCLE PRESS & HOLD COMPLET
 */
export async function handleVoiceMessage(
  missionId,
  senderProfileId,
  setRecordingState,
  setRecordingTime,
  onMessageSent
) {
  let timerRef = null;

  async function onPressIn() {
    console.log('[FTM-DEBUG] Audio - Press in — starting voice recording', {
      missionId, senderProfileId,
    });

    setRecordingState('recording');
    NativelyHaptics.medium();

    let seconds = 0;
    timerRef = setInterval(() => {
      seconds++;
      setRecordingTime(seconds);
      if (seconds >= 120) {
        clearInterval(timerRef);
        onPressOut();
      }
    }, 1000);

    const result = await startRecording();
    if (result.error) {
      clearInterval(timerRef);
      setRecordingState('error');
      NativelyHaptics.error();
      setTimeout(() => setRecordingState('idle'), 2000);
    }
  }

  async function onPressOut() {
    if (timerRef) clearInterval(timerRef);
    setRecordingState('uploading');

    const stopResult = await stopRecording();
    if (stopResult.error) {
      setRecordingState('error');
      NativelyHaptics.error();
      setTimeout(() => setRecordingState('idle'), 2000);
      return;
    }

    const uploadResult = await uploadVoiceMessage(
      missionId, senderProfileId,
      stopResult.uri, stopResult.mimeType, stopResult.duration
    );

    if (uploadResult.error) {
      setRecordingState('error');
      NativelyHaptics.error();
      setTimeout(() => setRecordingState('idle'), 2000);
      return;
    }

    NativelyHaptics.light();
    setRecordingState('idle');
    setRecordingTime(0);

    if (onMessageSent) {
      onMessageSent({
        url:       uploadResult.url,
        duration:  uploadResult.duration,
        filePath:  uploadResult.filePath,
        sender:    senderProfileId,
        timestamp: new Date().toISOString(),
      });
    }

    console.log('[FTM-DEBUG] Audio - Voice message sent successfully', {
      missionId, duration: stopResult.duration + 's',
    });
  }

  return { onPressIn, onPressOut };
}

/**
 * UI — VoiceMicButton (3 états visuels)
 *
 * ÉTAT 'idle' :
 * ┌──────────────────────────────────────┐
 * │    ┌─────────────┐                  │
 * │    │      🎤      │ ← Cercle 64px   │
 * │    │             │   COLORS.cta     │
 * │    └─────────────┘   (#F39C12)      │
 * │  "Maintenir pour parler en Darija"  │
 * └──────────────────────────────────────┘
 *
 * ÉTAT 'recording' (pulse animation) :
 * ┌──────────────────────────────────────┐
 * │  ●  ●  ●  (ondes sonores animées)   │
 * │    ┌─────────────┐                  │
 * │    │      🎤      │ ← COLORS.alert  │
 * │    └─────────────┘   (#DC3545)      │
 * │         00:07                       │
 * │    "Relâchez pour envoyer"          │
 * └──────────────────────────────────────┘
 *
 * ÉTAT 'uploading' :
 * ┌──────────────────────────────────────┐
 * │    ┌─────────────┐                  │
 * │    │  [Spinner]  │ ← Gris, rotation │
 * │    └─────────────┘                  │
 * │         "Envoi..."                  │
 * └──────────────────────────────────────┘
 *
 * FEEDBACKS HAPTIQUES :
 * - PressIn  → NativelyHaptics.medium()  (démarrage)
 * - PressOut → NativelyHaptics.light()   (envoi confirmé)
 * - Erreur   → NativelyHaptics.error()   (double vibration)
 */
```

### 7.4 Interface Chat Audio (Fil de Messages)

```javascript
// /screens/mission/VoiceChatScreen.js
// Intégré dans MissionTrackingScreen et MissionActiveScreen

/**
 * UI — VoiceChatScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────────┐
 * │  💬 Chat vocal — Mission FTM...047  │
 * │  "Messages vocaux en Darija"        │
 * │                                      │
 * │  ┌──────────────────────────────┐   │  ← Message CLIENT (gauche)
 * │  │ [🎤]  ▶ ────────────── 0:23  │   │     Fond #F0F0F0
 * │  │  Il y a 5 min                │   │
 * │  └──────────────────────────────┘   │
 * │                                      │
 * │       ┌──────────────────────────┐  │  ← Message DRIVER (droite)
 * │       │ [🎤]  ▶ ──────── 0:15   │  │     Fond COLORS.primary/10
 * │       │  Il y a 3 min            │  │
 * │       └──────────────────────────┘  │
 * │                                      │
 * │  ─────────────────────────────────  │
 * │  [       🎤 Maintenir pour         ]│  ← VoiceMicButton
 * │  [       parler en Darija          ]│     COLORS.cta (#F39C12)
 * └──────────────────────────────────────┘
 *
 * LECTURE :
 * - Tap sur un message → playVoiceMessage(url)
 * - Barre de progression animée pendant la lecture
 * - Bouton ▶ devient ⏸ en cours de lecture
 * - stopPlayback() si tap sur un autre message
 *
 * ÉTAT VIDE :
 * ┌──────────────────────────────────────┐
 * │  🎤                                  │
 * │  "Pas encore de messages"           │
 * │  "Maintenez le bouton pour parler   │
 * │   en Darija avec votre chauffeur"   │
 * └──────────────────────────────────────┘
 */
```

---

## 8. ARBORESCENCE DES FICHIERS — PÉRIMÈTRE P6

```
src/
├── services/
│   ├── pushNotificationService.js  ← registerPushToken, requestPushPermission,
│   │                                  insertNotification, dispatchPushNotification,
│   │                                  markNotificationRead, markAllNotificationsRead,
│   │                                  getNotifications, subscribeToNotifications,
│   │                                  setupPushHandlers
│   ├── notificationTemplates.js    ← notifyNewMission, notifyMissionAccepted/Started/
│   │                                  Completed/Cancelled, notifyDocumentExpiry/
│   │                                  Verified/Rejected, NOTIF_ICONS
│   └── audioService.js             ← requestMicrophonePermission, startRecording,
│                                      stopRecording, uploadVoiceMessage,
│                                      playVoiceMessage, stopPlayback, loadVoiceMessages
├── components/
│   ├── NotificationBell.js         ← Cloche header + badge unread count
│   └── VoiceMicButton.js           ← Press & hold + états visuels + haptiques
├── screens/
│   ├── notifications/
│   │   └── NotificationCenterScreen.js  ← Liste + deep link + mark read
│   └── mission/
│       └── VoiceChatScreen.js           ← Fil messages vocaux + playback
supabase/
└── functions/
    ├── check-document-reminders/   ← CRON J-30 / J-15 / J-7
    │   └── index.ts
    ├── send-push-notification/     ← Dispatch FCM (Android) / APNs (iOS)
    │   └── index.ts
    └── register-push-token/        ← Stockage tokens device par profil
        └── index.ts
```

---

## 9. RÉCAPITULATIF DES LOGS DE DEBUG (P6)

| Action | Log FTM-DEBUG |
|--------|---------------|
| Permission Push | `[FTM-DEBUG] Push - Requesting push permission` |
| Résultat permission | `[FTM-DEBUG] Push - Permission result` |
| Token obtenu | `[FTM-DEBUG] Push - Token obtained` |
| Enregistrement token | `[FTM-DEBUG] Push - Registering device token` |
| Token enregistré | `[FTM-DEBUG] Push - Token registered successfully` |
| Insertion notification | `[FTM-DEBUG] Push - Inserting notification` |
| Notification insérée | `[FTM-DEBUG] Push - Notification inserted` |
| Dispatch Push | `[FTM-DEBUG] Push - Dispatching push notification` |
| Dispatch OK | `[FTM-DEBUG] Push - Dispatched successfully` |
| Mark lue | `[FTM-DEBUG] Push - Marking notification as read` |
| Lue confirmée | `[FTM-DEBUG] Push - Notification marked as read` |
| Mark toutes lues | `[FTM-DEBUG] Push - Marking all notifications as read` |
| Fetch notifications | `[FTM-DEBUG] Push - Fetching notifications` |
| Notifications chargées | `[FTM-DEBUG] Push - Notifications fetched` |
| Sub. notifications | `[FTM-DEBUG] Push - Subscribing to notifications` |
| Nouvelle notification | `[FTM-DEBUG] Push - New notification received` |
| Notification tappée | `[FTM-DEBUG] Push - Notification tapped` |
| Deep link navigué | `[FTM-DEBUG] Push - Navigated from notification` |
| Foreground notif | `[FTM-DEBUG] Push - Foreground notification received` |
| Background tap | `[FTM-DEBUG] Push - Background notification tapped` |
| Cold start notif | `[FTM-DEBUG] Push - App opened from notification` |
| Push handlers OK | `[FTM-DEBUG] Push - Push handlers configured` |
| Notify nouvelle mission | `[FTM-DEBUG] Push - Notify new mission` |
| Notify mission acceptée | `[FTM-DEBUG] Push - Notify mission accepted` |
| Notify mission démarrée | `[FTM-DEBUG] Push - Notify mission started` |
| Notify mission terminée | `[FTM-DEBUG] Push - Notify mission completed` |
| Notify mission annulée | `[FTM-DEBUG] Push - Notify mission cancelled` |
| Notify doc. expiration | `[FTM-DEBUG] Push - Notify document expiry` |
| Notify doc. validé | `[FTM-DEBUG] Push - Notify document verified` |
| Notify doc. refusé | `[FTM-DEBUG] Push - Notify document rejected` |
| CRON démarré | `[FTM-DEBUG] Reminders - CRON started` |
| J-30 candidats | `[FTM-DEBUG] Reminders - J-30 candidates` |
| J-30 envoyé | `[FTM-DEBUG] Reminders - J-30 sent` |
| J-15 candidats | `[FTM-DEBUG] Reminders - J-15 candidates` |
| J-15 envoyé | `[FTM-DEBUG] Reminders - J-15 sent` |
| J-7 candidats | `[FTM-DEBUG] Reminders - J-7 candidates` |
| J-7 envoyé | `[FTM-DEBUG] Reminders - J-7 sent` |
| CRON terminé | `[FTM-DEBUG] Reminders - CRON completed` |
| Permission micro | `[FTM-DEBUG] Audio - Requesting microphone permission` |
| Résultat micro | `[FTM-DEBUG] Audio - Microphone permission result` |
| Démarrage enreg. | `[FTM-DEBUG] Audio - Starting recording` |
| Enreg. démarré | `[FTM-DEBUG] Audio - Recording started` |
| Arrêt enreg. | `[FTM-DEBUG] Audio - Stopping recording` |
| Enreg. arrêté | `[FTM-DEBUG] Audio - Recording stopped` |
| Enreg. trop court | `[FTM-DEBUG] Audio - Recording too short` |
| Upload message | `[FTM-DEBUG] Audio - Uploading voice message` |
| Upload OK | `[FTM-DEBUG] Audio - Voice message uploaded successfully` |
| Lecture démarrée | `[FTM-DEBUG] Audio - Playback started` |
| Lecture terminée | `[FTM-DEBUG] Audio - Playback completed` |
| Arrêt lecture | `[FTM-DEBUG] Audio - Stopping playback` |
| Chargement messages | `[FTM-DEBUG] Audio - Loading voice messages` |
| Messages chargés | `[FTM-DEBUG] Audio - Voice messages loaded` |
| Press In micro | `[FTM-DEBUG] Audio - Press in — starting voice recording` |
| Message envoyé | `[FTM-DEBUG] Audio - Voice message sent successfully` |

---

## 10. CHECKLIST DE VALIDATION P6

**Push Notifications :**
- [ ] FCM configuré dans Natively (google-services.json uploadé)
- [ ] APNs configuré dans Natively (certificat uploadé)
- [ ] `registerPushToken()` : token visible dans la Edge Function `register-push-token`
- [ ] `insertNotification()` : entrée visible dans table `notifications` Supabase
- [ ] Notification reçue sur **device physique** (simulateur ne reçoit pas les Push)
- [ ] Deep link `new_mission` → `DriverHome` avec la mission ouverte
- [ ] Deep link `document_expiry` → `DocumentStatusScreen` avec document en surbrillance
- [ ] Deep link `wallet_low_balance` → `WalletTopupScreen`
- [ ] `subscribeToNotifications()` : badge mis à jour < 1s sans relancer l'app
- [ ] `markAllNotificationsRead()` : badge tombe à 0 instantanément

**Rappels Documents :**
- [ ] CRON `check-document-reminders` planifié à 08:00 dans Supabase Dashboard
- [ ] Test J-30 : insérer date d'expiration à +30 jours → notif dans l'heure du CRON
- [ ] Flags `reminder_30/15/7_days_sent` : `true` après envoi — pas de doublon
- [ ] Urgence visuelle : 🔴 J-7, 🟠 J-15, 🟡 J-30

**Chat Audio Darija :**
- [ ] Bucket `voice-messages` créé (privé, 10MB max, audio/*)
- [ ] Policies RLS Storage : seuls client + driver de la mission peuvent accéder
- [ ] Permission micro demandée et accordée sur device réel
- [ ] `startRecording()` → `stopRecording()` : fichier .m4a créé localement
- [ ] `uploadVoiceMessage()` : fichier visible dans Storage → `missions/{id}/`
- [ ] URL signée 7 jours générée et fonctionnelle
- [ ] `playVoiceMessage()` : lecture audio fonctionnelle sur device réel
- [ ] `VoiceMicButton` : orange → rouge au démarrage, timer s'incrémente
- [ ] Auto-stop à 120 secondes
- [ ] Message < 1s : message d'erreur affiché, `recordingState` revient à `idle`
- [ ] Tous les `console.log('[FTM-DEBUG]...')` visibles dans Debug Console Codespaces

---

## 11. LIAISON AVEC LA PARTIE SUIVANTE

| Partie | Dépendance de P6 |
|--------|-----------------|
| **P7** | Admin valide/rejette documents → `notifyDocumentVerified()` / `notifyDocumentRejected()` |
| **P7** | Admin `topupWallet()` → peut déclencher `notifyWalletLowBalance()` si solde encore bas |
| **P7** | Admin peut consulter toutes les notifications dans le dashboard global |

---

*FTM Spec P6 — Fin du fichier*
*Prochaine étape : SPEC_NATIVELY_P7.md — Admin Dashboard & Sécurité RLS*
