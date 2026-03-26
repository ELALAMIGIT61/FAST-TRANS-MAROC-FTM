// /frontend/src/screens/auth/OTPVerificationScreen.tsx
// FTM — Vérification du code OTP (6 chiffres)
 
import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  StyleSheet,
  Alert,
} from 'react-native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RouteProp } from '@react-navigation/native';
import { COLORS, FONT_SIZES, RADIUS, SPACING } from '../../constants/theme';
import { handleVerifyOTP, handleSendOTP } from '../../services/authService';
import { t } from '../../services/i18nService';
import type { AuthStackParamList } from '../../navigation/RootNavigator';
 
const OTP_LENGTH = 6;
const RESEND_COUNTDOWN = 60;
 
type Props = {
  navigation: NativeStackNavigationProp<AuthStackParamList, 'OTPVerification'>;
  route: RouteProp<AuthStackParamList, 'OTPVerification'>;
};
 
export default function OTPVerificationScreen({ navigation, route }: Props) {
  const { formattedPhone } = route.params;
 
  const [digits, setDigits] = useState<string[]>(Array(OTP_LENGTH).fill(''));
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [countdown, setCountdown] = useState(RESEND_COUNTDOWN);
 
  const inputRefs = useRef<(TextInput | null)[]>(Array(OTP_LENGTH).fill(null));
 
  // Countdown pour renvoyer le code
  useEffect(() => {
    if (countdown <= 0) return;
    const timer = setTimeout(() => setCountdown(c => c - 1), 1000);
    return () => clearTimeout(timer);
  }, [countdown]);
 
  function handleDigitChange(text: string, index: number) {
    const cleaned = text.replace(/\D/g, '').slice(-1);
    const updated = [...digits];
    updated[index] = cleaned;
    setDigits(updated);
 
    if (cleaned && index < OTP_LENGTH - 1) {
      inputRefs.current[index + 1]?.focus();
    }
 
    // Auto-submit si 6 chiffres complets
    if (cleaned && index === OTP_LENGTH - 1) {
      const code = [...updated.slice(0, OTP_LENGTH - 1), cleaned].join('');
      if (code.length === OTP_LENGTH) {
        onPressVerify([...updated.slice(0, OTP_LENGTH - 1), cleaned]);
      }
    }
  }
 
  function handleKeyPress(key: string, index: number) {
    if (key === 'Backspace' && !digits[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  }
 
  async function onPressVerify(overrideDigits?: string[]) {
    const code = (overrideDigits ?? digits).join('');
    if (code.length < OTP_LENGTH) return;
 
    setErrorMessage(null);
    setIsLoading(true);
 
    const result = await handleVerifyOTP(formattedPhone, code);
 
    setIsLoading(false);
 
    if (result.error) {
      setErrorMessage(result.error);
      setDigits(Array(OTP_LENGTH).fill(''));
      inputRefs.current[0]?.focus();
      return;
    }
 
    if (result.isNew) {
      navigation.replace('ProfileSetup', {
        authUserId: result.user?.id ?? '',
        formattedPhone,
      });
    } else {
      // Navigation gérée par RootNavigator via onAuthStateChange
    }
  }
 
  async function onPressResend() {
    if (countdown > 0) return;
    const result = await handleSendOTP(formattedPhone);
    if (result.error) {
      Alert.alert('Erreur', result.error);
    } else {
      setCountdown(RESEND_COUNTDOWN);
      setDigits(Array(OTP_LENGTH).fill(''));
      inputRefs.current[0]?.focus();
    }
  }
 
  const otpCode = digits.join('');
  const canVerify = otpCode.length === OTP_LENGTH && !isLoading;
 
  return (
    <View style={styles.container}>
      {/* Retour */}
      <TouchableOpacity style={styles.backButton} onPress={() => navigation.goBack()}>
        <Text style={styles.backText}>← Retour</Text>
      </TouchableOpacity>
 
      <Text style={styles.title}>Code envoyé au</Text>
      <Text style={styles.phone}>{formattedPhone}</Text>
 
      {/* 6 cases OTP */}
      <View style={styles.otpRow}>
        {Array(OTP_LENGTH).fill(null).map((_, i) => (
          <TextInput
            key={i}
            ref={ref => { inputRefs.current[i] = ref; }}
            style={[styles.otpInput, digits[i] ? styles.otpInputFilled : null]}
            keyboardType="number-pad"
            maxLength={1}
            value={digits[i]}
            onChangeText={text => handleDigitChange(text, i)}
            onKeyPress={({ nativeEvent }) => handleKeyPress(nativeEvent.key, i)}
            selectTextOnFocus
          />
        ))}
      </View>
 
      {/* Message d'erreur */}
      {errorMessage && (
        <Text style={styles.errorText}>{errorMessage}</Text>
      )}
 
      {/* Bouton confirmer */}
      <TouchableOpacity
        style={[styles.button, !canVerify && styles.buttonDisabled]}
        onPress={() => onPressVerify()}
        disabled={!canVerify}
        activeOpacity={0.8}
      >
        {isLoading ? (
          <ActivityIndicator color={COLORS.white} />
        ) : (
          <Text style={styles.buttonText}>{t('verify_otp')}</Text>
        )}
      </TouchableOpacity>
 
      {/* Renvoyer */}
      <TouchableOpacity
        onPress={onPressResend}
        disabled={countdown > 0}
        style={styles.resendContainer}
      >
        <Text style={[styles.resendText, countdown > 0 && styles.resendDisabled]}>
          {countdown > 0 ? `Renvoyer dans ${countdown}s` : 'Renvoyer le code'}
        </Text>
      </TouchableOpacity>
    </View>
  );
}
 
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
    paddingHorizontal: SPACING.lg,
    paddingTop: 60,
  },
  backButton: {
    marginBottom: SPACING.xl,
  },
  backText: {
    color: COLORS.primary,
    fontSize: FONT_SIZES.md,
  },
  title: {
    fontSize: FONT_SIZES.lg,
    color: COLORS.textMuted,
    textAlign: 'center',
  },
  phone: {
    fontSize: FONT_SIZES.xl,
    color: COLORS.textDark,
    fontWeight: '700',
    textAlign: 'center',
    marginBottom: SPACING.xl,
  },
  otpRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: SPACING.sm,
    marginBottom: SPACING.lg,
  },
  otpInput: {
    width: 48,
    height: 56,
    borderRadius: RADIUS.input,
    borderWidth: 2,
    borderColor: '#E0E0E0',
    backgroundColor: COLORS.white,
    textAlign: 'center',
    fontSize: FONT_SIZES.xl,
    color: COLORS.textDark,
    fontWeight: '700',
  },
  otpInputFilled: {
    borderColor: COLORS.primary,
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
    marginBottom: SPACING.lg,
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
  resendContainer: {
    alignItems: 'center',
  },
  resendText: {
    color: COLORS.primary,
    fontSize: FONT_SIZES.sm,
    fontWeight: '600',
  },
  resendDisabled: {
    color: COLORS.textMuted,
  },
});
