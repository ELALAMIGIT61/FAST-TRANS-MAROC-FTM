// /frontend/src/screens/auth/PhoneInputScreen.tsx
// FTM — Saisie numéro téléphone + envoi OTP
 
import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { COLORS, FONT_SIZES, RADIUS, SPACING } from '../../constants/theme';
import { handleSendOTP } from '../../services/authService';
import { t } from '../../services/i18nService';
import type { AuthStackParamList } from '../../navigation/RootNavigator';
 
type Props = {
  navigation: NativeStackNavigationProp<AuthStackParamList, 'PhoneInput'>;
};
 
export default function PhoneInputScreen({ navigation }: Props) {
  const [phoneNumber, setPhoneNumber] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
 
  const canSubmit = phoneNumber.trim().length >= 9 && !isLoading;
 
  async function onPressSend() {
    setErrorMessage(null);
    setIsLoading(true);
 
    const result = await handleSendOTP(phoneNumber);
 
    setIsLoading(false);
 
    if (result.error) {
      setErrorMessage(result.error);
      return;
    }
 
    if (result.formattedPhone) {
      navigation.navigate('OTPVerification', { formattedPhone: result.formattedPhone });
    }
  }
 
  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      {/* Logo placeholder */}
      <View style={styles.logoContainer}>
        <Text style={styles.logoText}>🚚 FTM</Text>
      </View>
 
      <Text style={styles.title}>{t('welcome')}</Text>
      <Text style={styles.subtitle}>Fast Trans Maroc | فاست ترانس المغرب</Text>
 
      {/* Champ téléphone */}
      <View style={styles.phoneRow}>
        <View style={styles.prefixBox}>
          <Text style={styles.flag}>🇲🇦</Text>
          <Text style={styles.prefix}>+212</Text>
        </View>
        <TextInput
          style={styles.input}
          placeholder="6XXXXXXXX"
          placeholderTextColor={COLORS.textMuted}
          keyboardType="phone-pad"
          maxLength={10}
          value={phoneNumber}
          onChangeText={setPhoneNumber}
          returnKeyType="done"
          onSubmitEditing={canSubmit ? onPressSend : undefined}
        />
      </View>
 
      {/* Message d'erreur */}
      {errorMessage && (
        <Text style={styles.errorText}>{errorMessage}</Text>
      )}
 
      {/* Bouton envoi */}
      <TouchableOpacity
        style={[styles.button, !canSubmit && styles.buttonDisabled]}
        onPress={onPressSend}
        disabled={!canSubmit}
        activeOpacity={0.8}
      >
        {isLoading ? (
          <ActivityIndicator color={COLORS.white} />
        ) : (
          <Text style={styles.buttonText}>{t('send_otp')}</Text>
        )}
      </TouchableOpacity>
    </KeyboardAvoidingView>
  );
}
 
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
    paddingHorizontal: SPACING.lg,
    justifyContent: 'center',
  },
  logoContainer: {
    alignItems: 'center',
    marginBottom: SPACING.xl,
  },
  logoText: {
    fontSize: 48,
  },
  title: {
    fontSize: FONT_SIZES.xl,
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
  phoneRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.md,
    gap: SPACING.sm,
  },
  prefixBox: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.input,
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.md,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    gap: 4,
  },
  flag: {
    fontSize: 18,
  },
  prefix: {
    fontSize: FONT_SIZES.md,
    color: COLORS.textMuted,
    fontWeight: '600',
  },
  input: {
    flex: 1,
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.input,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.md,
    fontSize: FONT_SIZES.md,
    color: COLORS.textDark,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    height: 52,
  },
  errorText: {
    color: COLORS.alert,
    fontSize: FONT_SIZES.sm,
    marginBottom: SPACING.sm,
    textAlign: 'center',
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
