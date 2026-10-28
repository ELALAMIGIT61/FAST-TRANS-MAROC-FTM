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

// Session 3.4 (correction 7) : si l'application vient d'etre ouverte par le
// toucher d'une notification, les ecrans ne sont pas encore prets. Au lieu
// d'abandonner, on attend qu'ils le soient (10 secondes au plus). Un meme
// ecran demande deux fois de suite (deux chemins de detection) n'est ouvert
// qu'une fois.
let lastNavigation: { key: string; at: number } | null = null;
const HOME_ROUTES = ['ClientHome', 'DriverHome'];

function navigate(screen: string, params?: Record<string, unknown>): void {
  const key = screen + JSON.stringify(params ?? {});
  const now = Date.now();
  if (lastNavigation && lastNavigation.key === key && now - lastNavigation.at < 3000) return;
  lastNavigation = { key, at: now };

  // A1 (correction 31) : ouvrir un ecran directement depuis une notification
  // echouait (retour a l'accueil), alors que la mise a jour de l'accueil
  // fonctionne (notification « Nouvelle mission »). Pour le client et le
  // chauffeur, on passe donc par leur accueil, qui ouvre lui-meme l'ecran
  // demande (parametres pendingScreen / pendingParams).
  const go = () => {
    const home = navigationRef.getRootState()?.routeNames?.[0];
    if (home && HOME_ROUTES.includes(home) && screen !== home) {
      navigationRef.dispatch(
        CommonActions.navigate({
          name: home,
          params: { pendingScreen: screen, pendingParams: params ?? {}, pendingAt: Date.now() },
          merge: true,
        })
      );
      return;
    }
    navigationRef.dispatch(CommonActions.navigate({ name: screen, params }));
  };
  if (navigationRef.isReady()) {
    go();
    return;
  }
  console.log('[FTM-DEBUG] Push - Navigation not ready, waiting', { screen });
  waitForNavigation(10000).then((ready) => {
    if (ready) go();
    else console.log('[FTM-DEBUG] Push - Navigation still not ready, abandoned', { screen });
  });
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

// Session 3.4 (correction 7) : ecoute posee des le demarrage de l'application,
// avant meme la connexion, pour ne pas manquer le toucher qui l'a ouverte.
// La reponse est gardee de cote jusqu'a ce que l'utilisateur soit sur son espace.
let earlyResponse: Notifications.NotificationResponse | null = null;
if (Platform.OS !== 'web') {
  Notifications.addNotificationResponseReceivedListener((response) => {
    if (!handlersInstalled) earlyResponse = response;
  });
}
let registeredProfileId: string | null = null;
let registeredToken: string | null = null;

// A appeler quand un utilisateur connecte arrive sur son espace.
export async function setupDevicePush(): Promise<void> {
  if (Platform.OS === 'web') return;

  if (!handlersInstalled) {
    setupPushHandlers(navigate);
    handlersInstalled = true;
  }

  // Session 3.4 (correction 7) : application ouverte par le toucher d'une
  // notification alors qu'elle etait fermee. Verifie EN PREMIER et a part :
  // une erreur plus loin (autorisation, inscription) ne doit pas l'empecher.
  if (!initialResponseChecked) {
    initialResponseChecked = true;
    try {
      const response = earlyResponse ?? (await Notifications.getLastNotificationResponseAsync());
      earlyResponse = null;
      if (response && (await waitForNavigation(10000))) {
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
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      console.log('[FTM-DEBUG] Push - Initial notification error', { error: msg });
    }
  }

  try {

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
