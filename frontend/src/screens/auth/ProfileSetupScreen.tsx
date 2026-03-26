// /frontend/src/screens/auth/ProfileSetupScreen.tsx
// FTM — Création du profil (nom + rôle)
 
import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  StyleSheet,
  ScrollView,
} from 'react-native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RouteProp } from '@react-navigation/native';
import { COLORS, FONT_SIZES, RADIUS, SPACING } from '../../constants/theme';
import { handleCreateProfile } from '../../services/authService';
import { t } from '../../services/i18nService';
import type { AuthStackParamList } from '../../navigation/RootNavigator';
 
type RoleOption = 'client' | 'driver';
 
type Props = {
  navigation: NativeStackNavigationProp<AuthStackParamList, 'ProfileSetup'>;
  route: RouteProp<AuthStackParamList, 'ProfileSetup'>;
};
 
export default function ProfileSetupScreen({ navigation, route }: Props) {
  const { authUserId, formattedPhone } = route.params;
 
  const [fullName, setFullName] = useState('');
  const [selectedRole, setSelectedRole] = useState<RoleOption | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
 
  const canSubmit = fullName.trim().length >= 2 && selectedRole !== null && !isLoading;
 
  async function onPressStart() {
    if (!selectedRole) return;
    setErrorMessage(null);
    setIsLoading(true);
 
    const result = await handleCreateProfile(authUserId, formattedPhone, fullName.trim(), selectedRole);
 
    setIsLoading(false);
 
    if (result.error) {
      setErrorMessage(result.error);
      return;
    }
 
    // Navigation selon rôle — RootNavigator écoute les changements de session
    // On peut forcer ici si nécessaire
    console.log('[FTM-DEBUG] ProfileSetup - Profile created, role:', selectedRole);
  }
 
  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.container}
      keyboardShouldPersistTaps="handled"
    >
      <Text style={styles.title}>Créez votre profil</Text>
      <Text style={styles.subtitle}>Quelques infos pour commencer</Text>
 
      {/* Champ nom complet */}
      <Text style={styles.label}>{t('your_name')}</Text>
      <TextInput
        style={styles.input}
        placeholder="Ex: Youssef Benali"
        placeholderTextColor={COLORS.textMuted}
        value={fullName}
        onChangeText={setFullName}
        autoCapitalize="words"
        returnKeyType="done"
      />
 
      {/* Sélection rôle */}
      <Text style={styles.label}>{t('you_are')}</Text>
      <View style={styles.rolesRow}>
        <TouchableOpacity
          style={[
            styles.roleCard,
            selectedRole === 'client' && styles.roleCardSelected,
          ]}
          onPress={() => setSelectedRole('client')}
          activeOpacity={0.8}
        >
          <Text style={styles.roleIcon}>🧑</Text>
          <Text style={[styles.roleTitle, selectedRole === 'client' && styles.roleTitleSelected]}>
            {t('client')}
          </Text>
          <Text style={styles.roleDesc}>Expédiez facilement</Text>
        </TouchableOpacity>
 
        <TouchableOpacity
          style={[
            styles.roleCard,
            selectedRole === 'driver' && styles.roleCardSelected,
          ]}
          onPress={() => setSelectedRole('driver')}
          activeOpacity={0.8}
        >
          <Text style={styles.roleIcon}>🚚</Text>
          <Text style={[styles.roleTitle, selectedRole === 'driver' && styles.roleTitleSelected]}>
            {t('driver')}
          </Text>
          <Text style={styles.roleDesc}>Devenez transporteur FTM</Text>
        </TouchableOpacity>
      </View>
 
      {/* Message d'erreur */}
      {errorMessage && (
        <Text style={styles.errorText}>{errorMessage}</Text>
      )}
 
      {/* Bouton Commencer */}
      <TouchableOpacity
        style={[styles.button, !canSubmit && styles.buttonDisabled]}
        onPress={onPressStart}
        disabled={!canSubmit}
        activeOpacity={0.8}
      >
        {isLoading ? (
          <ActivityIndicator color={COLORS.white} />
        ) : (
          <Text style={styles.buttonText}>{t('start')}</Text>
        )}
      </TouchableOpacity>
    </ScrollView>
  );
}
 
const styles = StyleSheet.create({
  scroll: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  container: {
    paddingHorizontal: SPACING.lg,
    paddingTop: 60,
    paddingBottom: SPACING.xl,
  },
  title: {
    fontSize: FONT_SIZES.xxl,
    color: COLORS.textDark,
    fontWeight: '700',
    textAlign: 'center',
    marginBottom: SPACING.sm,
  },
  subtitle: {
    fontSize: FONT_SIZES.sm,
    color: COLORS.textMuted,
    textAlign: 'center',
    marginBottom: SPACING.xl,
  },
  label: {
    fontSize: FONT_SIZES.sm,
    color: COLORS.textMuted,
    fontWeight: '600',
    marginBottom: SPACING.sm,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  input: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.input,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.md,
    fontSize: FONT_SIZES.md,
    color: COLORS.textDark,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    height: 52,
    marginBottom: SPACING.lg,
  },
  rolesRow: {
    flexDirection: 'row',
    gap: SPACING.md,
    marginBottom: SPACING.xl,
  },
  roleCard: {
    flex: 1,
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.card,
    padding: SPACING.md,
    alignItems: 'center',
    borderWidth: 2,
    borderColor: '#E0E0E0',
    elevation: 2,
  },
  roleCardSelected: {
    borderColor: COLORS.primary,
    elevation: 4,
  },
  roleIcon: {
    fontSize: 36,
    marginBottom: SPACING.sm,
  },
  roleTitle: {
    fontSize: FONT_SIZES.md,
    fontWeight: '700',
    color: COLORS.textDark,
    marginBottom: 4,
  },
  roleTitleSelected: {
    color: COLORS.primary,
  },
  roleDesc: {
    fontSize: FONT_SIZES.xs,
    color: COLORS.textMuted,
    textAlign: 'center',
  },
  errorText: {
    color: COLORS.alert,
    fontSize: FONT_SIZES.sm,
    textAlign: 'center',
    marginBottom: SPACING.md,
  },
  button: {
    backgroundColor: COLORS.primary,
    borderRadius: RADIUS.button,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 4,
    shadowColor: COLORS.primary,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
  },
  buttonDisabled: {
    opacity: 0.5,
    elevation: 0,
  },
  buttonText: {
    color: COLORS.white,
    fontSize: FONT_SIZES.md,
    fontWeight: '700',
  },
});
