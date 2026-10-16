// /frontend/src/utils/dialogs.ts
// FTM — Messages et confirmations compatibles web et téléphone (session 2.19)
//
// Alert.alert (React Native) n'affiche rien dans un navigateur : sur le web,
// les messages restaient invisibles et les actions qui attendaient une
// confirmation ne s'exécutaient jamais. Ces deux fonctions utilisent
// Alert.alert sur téléphone (comportement inchangé) et les fenêtres du
// navigateur sur le web.

import { Alert, Platform } from 'react-native';

/**
 * Affiche un message d'information. `onOk` (facultatif) est appelé quand
 * l'utilisateur a fermé le message.
 */
export function showMessage(title: string, message?: string, onOk?: () => void): void {
  if (Platform.OS === 'web') {
    window.alert(message ? `${title}\n\n${message}` : title);
    if (onOk) onOk();
    return;
  }
  Alert.alert(title, message, onOk ? [{ text: 'OK', onPress: onOk }] : undefined);
}

/**
 * Demande une confirmation. Renvoie true si l'utilisateur confirme,
 * false s'il annule (ou ferme la fenêtre).
 */
export function confirmAction(
  title: string,
  message: string,
  options: { confirmLabel?: string; cancelLabel?: string; destructive?: boolean } = {}
): Promise<boolean> {
  const { confirmLabel = 'Confirmer', cancelLabel = 'Annuler', destructive = false } = options;
  if (Platform.OS === 'web') {
    return Promise.resolve(window.confirm(`${title}\n\n${message}`));
  }
  return new Promise((resolve) => {
    Alert.alert(
      title,
      message,
      [
        { text: cancelLabel, style: 'cancel', onPress: () => resolve(false) },
        { text: confirmLabel, style: destructive ? 'destructive' : 'default', onPress: () => resolve(true) },
      ],
      { cancelable: true, onDismiss: () => resolve(false) }
    );
  });
}
