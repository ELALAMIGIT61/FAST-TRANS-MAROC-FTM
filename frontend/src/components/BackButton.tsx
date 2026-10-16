import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';
import type { StyleProp, ViewStyle } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { COLORS, SPACING } from '../constants/theme';

/*
 * Session 2.21 (16/10/2026) : bouton « ← Retour » commun.
 * Les piles de navigation n'affichent pas d'en-tête (headerShown: false),
 * donc aucun retour natif sur le web.
 * Le bouton revient à l'écran précédent ; s'il n'y en a pas (arrivée par une
 * notification, page rechargée), il ramène au premier écran de la pile,
 * c'est-à-dire à l'accueil du rôle.
 */
export default function BackButton({ style }: { style?: StyleProp<ViewStyle> }) {
  const navigation = useNavigation<any>();

  const onPress = () => {
    if (navigation.canGoBack()) {
      navigation.goBack();
      return;
    }
    const home = navigation.getState()?.routeNames?.[0];
    if (home) navigation.navigate(home);
  };

  return (
    <TouchableOpacity
      onPress={onPress}
      style={[styles.button, style]}
      accessibilityRole="button"
      accessibilityLabel="Retour"
    >
      <Text style={styles.text}>← Retour</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    alignSelf: 'flex-start',
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.sm,
  },
  text: {
    color: COLORS.primary,
    fontSize: 16,
    fontWeight: '600',
  },
});
