// /frontend/src/services/pushSetup.ts
// FTM — Session 3.4 : equipement du telephone pour les notifications.
//
// Raccorde les fonctions existantes de pushNotificationService.ts :
//  - categories Android (setupNotificationChannels) ;
//  - autorisation et adresse du telephone (requestPushPermission) ;
//  - inscription de l'adresse aupres du serveur (registerPushToken) ;
//  - reaction au toucher d'une notification (setupPushHandlers), y compris
//    quand l'application etait completement fermee.
//
// Sur le web, rien ne se passe : toutes les fonctions sortent immediatement.

import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';
import { CommonActions, createNavigationContainerRef } from '@react-navigation/native';
import {
  setupNotificationChannels,
  requestPushPermission,
  registerPushToken,
  setupPushHandlers,
  handleNotificationTap,
  getCurrentProfileId,
} from './pushNotificationService';
import { supabase } from '../lib/supabaseClient';
import { handleSignOut } from './authService';

// « Telecommande » de navigation : permet d'ouvrir un ecran depuis une
// notification, en dehors des ecrans eux-memes.
export const navigationRef = createNavigationContainerRef<any>();

function navigate(screen: string, params?: Record<string, unknown>): void {
  if (navigationRef.isReady()) {
    navigationRef.dispatch(CommonActions.navigate({ name: screen, params }));
  } else {
    console.log('[FTM-DEBUG] Push - Navigation not ready', { screen });
  }
}

async function waitForNavigation(maxMs = 5000): Promise<boolean> {
  const step = 100;
  for (let waited = 0; waited < maxMs; waited += step) {
    if (navigationRef.isReady()) return true;
    await new Promise((resolve) => setTimeout(resolve, step));
  }
  return navigationRef.isReady();
}

let handlersInstalled = false;
let initialResponseChecked = false;
let registeredProfileId: string | null = null;
let registeredToken: string | null = null;

// A appeler quand un utilisateur connecte arrive sur son espace.
export async function setupDevicePush(): Promise<void> {
  if (Platform.OS === 'web') return;

  try {
    if (!handlersInstalled) {
      setupPushHandlers(navigate);
      handlersInstalled = true;
    }

    // Android : les categories doivent exister avant la demande d'autorisation.
    if (Platform.OS === 'android') {
      await setupNotificationChannels();
    }

    const profileId = await getCurrentProfileId();
    if (!profileId) {
      console.log('[FTM-DEBUG] Push - Device setup skipped (no profile)');
      return;
    }

    if (profileId !== registeredProfileId) {
      const { granted, token } = await requestPushPermission();
      if (granted && token) {
        const result = await registerPushToken(profileId, token, Platform.OS);
        if (result.success) {
          registeredProfileId = profileId;
          registeredToken = token;
        }
      }
    }

    // Application ouverte par le toucher d'une notification alors qu'elle
    // etait fermee : on ouvre l'ecran correspondant une seule fois.
    if (!initialResponseChecked) {
      initialResponseChecked = true;
      const response = await Notifications.getLastNotificationResponseAsync();
      if (response && (await waitForNavigation())) {
        const data = response.notification.request.content.data as Record<string, unknown>;
        console.log('[FTM-DEBUG] Push - App opened from notification', {
          type: data?.type,
          screen: data?.screen,
        });
        await handleNotificationTap(
          {
            id: String(data?.notification_id || ''),
            profile_id: String(data?.profile_id || ''),
            type: String(data?.type || ''),
            data,
          },
          navigate
        );
      }
    }
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Push - Device setup error', { error: msg });
  }
}

// A appeler a la deconnexion : la prochaine connexion reinscrira le telephone.
export function resetDevicePush(): void {
  registeredProfileId = null;
  registeredToken = null;
}

// Session 3.4 : a la deconnexion, le telephone cesse de recevoir les
// notifications de ce compte. La suppression se fait AVANT la deconnexion
// (l'utilisateur doit encore etre identifie : regle push_tokens_delete_own).
// Elle ne bloque jamais la deconnexion : 3 secondes maximum, erreurs ignorees.
async function unregisterDevicePush(): Promise<void> {
  if (Platform.OS === 'web' || !registeredProfileId || !registeredToken) return;
  const profileId = registeredProfileId;
  const token = registeredToken;
  try {
    const removal = supabase
      .from('push_tokens')
      .delete()
      .eq('profile_id', profileId)
      .eq('token', token)
      .then(({ error }) => {
        if (error) console.log('[FTM-DEBUG] Push - Token removal error', { error: error.message });
        else console.log('[FTM-DEBUG] Push - Token removed at sign out', { profileId });
      });
    await Promise.race([removal, new Promise((resolve) => setTimeout(resolve, 3000))]);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Push - Token removal exception', { error: msg });
  }
  resetDevicePush();
}

// Deconnexion utilisee par les boutons « Se deconnecter » de l'application.
export async function signOutAndUnregisterDevice(): Promise<{ success?: boolean; error?: string }> {
  await unregisterDevicePush();
  return handleSignOut();
}
