import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { COLORS, SPACING } from '../../constants/theme';
import LogoutButton from '../../components/LogoutButton';

/*
 * Session 2.21 (16/10/2026) : écran affiché quand le compte a été suspendu
 * par l'administrateur (profiles.is_active = false).
 * Auparavant, cette situation aboutissait à un écran blanc sans issue.
 */
export default function AccountSuspendedScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.emoji}>🚫</Text>
      <Text style={styles.title}>Compte suspendu</Text>
      <Text style={styles.text}>
        Votre compte a été suspendu. Pour plus d'informations, contactez le service Fast Trans Maroc.
      </Text>
      <LogoutButton style={styles.logout} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.lg,
    backgroundColor: COLORS.background,
  },
  emoji: { fontSize: 48, marginBottom: SPACING.md },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: SPACING.sm,
  },
  text: {
    fontSize: 16,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.lg,
  },
  logout: { alignSelf: 'center' },
});
