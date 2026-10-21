import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';
import type { StyleProp, ViewStyle } from 'react-native';
import { COLORS, SPACING } from '../constants/theme';
import { signOutAndUnregisterDevice as handleSignOut } from '../services/pushSetup';
import { confirmAction, showMessage } from '../utils/dialogs';

/*
 * Session 2.21 (16/10/2026) : bouton « Déconnexion » commun, pour les écrans
 * où l'utilisateur n'a pas accès à l'accueil de son rôle (inscription
 * chauffeur, dossier en attente, compte suspendu).
 * Même confirmation que sur les écrans d'accueil. Après la déconnexion,
 * le navigateur principal ramène automatiquement à l'écran de connexion.
 */
export default function LogoutButton({ style }: { style?: StyleProp<ViewStyle> }) {
  const onPress = async () => {
    const ok = await confirmAction(
      'Déconnexion',
      'Voulez-vous vraiment vous déconnecter ?',
      { confirmLabel: 'Se déconnecter', destructive: true },
    );
    if (!ok) return;
    const result = await handleSignOut();
    if (result.error) showMessage('Erreur', result.error);
  };

  return (
    <TouchableOpacity
      onPress={onPress}
      style={[styles.button, style]}
      accessibilityRole="button"
      accessibilityLabel="Déconnexion"
    >
      <Text style={styles.text}>Déconnexion</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    alignSelf: 'flex-end',
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.sm,
  },
  text: {
    color: COLORS.alert,
    fontSize: 15,
    fontWeight: '600',
  },
});
