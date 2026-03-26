#!/bin/bash
 
mkdir -p frontend/src/constants
mkdir -p frontend/src/lib
mkdir -p frontend/src/services
mkdir -p frontend/src/screens/auth
mkdir -p frontend/src/navigation
mkdir -p frontend/src/types
 
cat > frontend/package.json << 'ENDOFFILE'
{
  "name": "fast-trans-maroc",
  "version": "1.0.0",
  "main": "node_modules/expo/AppEntry.js",
  "scripts": {
    "start": "expo start",
    "android": "expo start --android",
    "ios": "expo start --ios",
    "web": "expo start --web",
    "lint": "eslint . --ext .ts,.tsx"
  },
  "dependencies": {
    "@expo/vector-icons": "^14.0.0",
    "@react-native-async-storage/async-storage": "1.21.0",
    "@react-navigation/native": "^6.1.9",
    "@react-navigation/native-stack": "^6.9.17",
    "@supabase/supabase-js": "^2.39.0",
    "expo": "~50.0.0",
    "expo-constants": "~15.4.5",
    "expo-font": "~11.10.2",
    "expo-linking": "~6.2.2",
    "expo-router": "~3.4.0",
    "expo-splash-screen": "~0.26.3",
    "expo-status-bar": "~1.11.1",
    "react": "18.2.0",
    "react-native": "0.73.4",
    "react-native-safe-area-context": "4.8.2",
    "react-native-screens": "~3.29.0",
    "react-native-url-polyfill": "^2.0.0"
  },
  "devDependencies": {
    "@babel/core": "^7.20.0",
    "@types/react": "~18.2.45",
    "@types/react-native": "~0.73.0",
    "typescript": "^5.3.0"
  },
  "private": true
}
ENDOFFILE
 
cat > frontend/tsconfig.json << 'ENDOFFILE'
{
  "extends": "expo/tsconfig.base",
  "compilerOptions": {
    "strict": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
ENDOFFILE
 
cat > frontend/src/constants/theme.ts << 'ENDOFFILE'
// /frontend/src/constants/theme.ts
// FTM — Design System Tokens
 
export const COLORS = {
  primary:    '#0056B3', // Bleu Royal — Actions principales, headers
  cta:        '#F39C12', // Jaune Ambre — Boutons CTA, bouton micro audio
  success:    '#28A745', // Vert — Validation, statut "verified"
  alert:      '#DC3545', // Rouge — Erreurs, alertes, rejets
  background: '#F8F9FA', // Gris très clair — Fond des écrans
  white:      '#FFFFFF',
  textDark:   '#1A1A2E',
  textMuted:  '#6C757D',
} as const;
 
export const FONTS = {
  regular: 'Inter-Regular',
  medium:  'Inter-Medium',
  bold:    'Inter-Bold',
  arabic:  'Cairo-Regular',
} as const;
 
export const FONT_SIZES = {
  xs:   12,
  sm:   14,
  md:   16,
  lg:   18,
  xl:   22,
  xxl:  28,
} as const;
 
export const RADIUS = {
  card:   12,
  button:  8,
  input:   8,
  chip:   20,
} as const;
 
export const SPACING = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
} as const;
ENDOFFILE
 
cat > frontend/src/types/database.ts << 'ENDOFFILE'
// /frontend/src/types/database.ts
// FTM — Types TypeScript pour Supabase
 
export type UserRole = 'client' | 'driver' | 'admin';
export type LanguagePreference = 'fr' | 'ar';
 
export interface Profile {
  id: string;
  user_id: string;
  phone_number: string;
  full_name: string;
  role: UserRole;
  language_preference: LanguagePreference;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}
 
export interface AuthResult {
  success?: boolean;
  error?: string;
}
 
export interface OTPSendResult extends AuthResult {
  formattedPhone?: string;
}
 
export interface ProfileResult extends AuthResult {
  profile?: Profile | null;
  isNew?: boolean;
  phone?: string;
  user?: {
    id: string;
    phone?: string;
  };
}
 
export type AppRoute =
  | 'AuthStack'
  | 'ProfileSetupScreen'
  | 'AccountSuspendedScreen'
  | 'ClientHomeStack'
  | 'DriverHomeStack'
  | 'AdminStack';
ENDOFFILE
 
cat > frontend/src/lib/supabaseClient.ts << 'ENDOFFILE'
// /frontend/src/lib/supabaseClient.ts
// FTM — Initialisation du client Supabase
 
import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';
 
const SUPABASE_URL = process.env.EXPO_PUBLIC_SUPABASE_URL as string;
const SUPABASE_ANON_KEY = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY as string;
 
if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  throw new Error(
    '[FTM] Variables EXPO_PUBLIC_SUPABASE_URL et EXPO_PUBLIC_SUPABASE_ANON_KEY manquantes dans .env'
  );
}
 
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
});
 
console.log('[FTM-DEBUG] Supabase client initialized', {
  url: SUPABASE_URL,
  timestamp: new Date().toISOString(),
});
ENDOFFILE
 
cat > frontend/src/services/i18nService.ts << 'ENDOFFILE'
// /frontend/src/services/i18nService.ts
// FTM — Gestion bilingue Français / Arabe (RTL)
 
import { I18nManager } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import type { LanguagePreference } from '../types/database';
 
type TranslationKey =
  | 'welcome'
  | 'phone_label'
  | 'send_otp'
  | 'verify_otp'
  | 'your_name'
  | 'you_are'
  | 'client'
  | 'driver'
  | 'start'
  | 'error_generic'
  | 'error_phone'
  | 'error_otp';
 
type Translations = Record<TranslationKey, string>;
 
const TRANSLATIONS: Record<LanguagePreference, Translations> = {
  fr: {
    welcome:       'Bienvenue sur Fast Trans Maroc',
    phone_label:   'Votre numéro de téléphone',
    send_otp:      'Envoyer le code',
    verify_otp:    'Confirmer',
    your_name:     'Votre nom complet',
    you_are:       'Vous êtes :',
    client:        'Client',
    driver:        'Chauffeur',
    start:         'Commencer',
    error_generic: 'Une erreur est survenue. Réessayez.',
    error_phone:   'Numéro invalide. Format : 06XXXXXXXX',
    error_otp:     'Code incorrect ou expiré.',
  },
  ar: {
    welcome:       'مرحباً بك في فاست ترانس المغرب',
    phone_label:   'رقم هاتفك',
    send_otp:      'إرسال الرمز',
    verify_otp:    'تأكيد',
    your_name:     'اسمك الكامل',
    you_are:       'أنت :',
    client:        'عميل',
    driver:        'سائق',
    start:         'ابدأ',
    error_generic: 'حدث خطأ ما. حاول مجدداً.',
    error_phone:   'رقم غير صالح.',
    error_otp:     'رمز غير صحيح أو منتهي الصلاحية.',
  },
};
 
let currentLang: LanguagePreference = 'fr';
 
export function t(key: TranslationKey): string {
  return TRANSLATIONS[currentLang]?.[key] ?? TRANSLATIONS['fr'][key] ?? key;
}
 
export function getCurrentLanguage(): LanguagePreference {
  return currentLang;
}
 
export async function setLanguage(lang: LanguagePreference): Promise<void> {
  console.log('[FTM-DEBUG] i18n - Language switch', { from: currentLang, to: lang });
 
  currentLang = lang;
 
  const isRTL = lang === 'ar';
  I18nManager.forceRTL(isRTL);
 
  await AsyncStorage.setItem('ftm_language', lang);
 
  console.log('[FTM-DEBUG] i18n - Language applied', { lang, isRTL });
}
 
export async function loadSavedLanguage(): Promise<void> {
  try {
    const saved = await AsyncStorage.getItem('ftm_language');
    if (saved === 'fr' || saved === 'ar') {
      await setLanguage(saved);
      console.log('[FTM-DEBUG] i18n - Restored language from storage', { lang: saved });
    }
  } catch (err) {
    console.log('[FTM-DEBUG] i18n - Load language error', { err });
  }
}
ENDOFFILE
 
cat > frontend/src/services/authService.ts << 'ENDOFFILE'
// /frontend/src/services/authService.ts
// FTM — OTP, gestion profil, déconnexion
 
import { supabase } from '../lib/supabaseClient';
import type { Profile, OTPSendResult, ProfileResult } from '../types/database';
 
// ─────────────────────────────────────────────
// Formatage numéro marocain
// ─────────────────────────────────────────────
 
export function formatMoroccanPhone(rawPhone: string): string {
  let cleaned = rawPhone.replace(/\s+/g, '').replace(/-/g, '');
 
  if (cleaned.startsWith('+212')) return cleaned;
  if (cleaned.startsWith('00212')) return '+' + cleaned.slice(2);
  if (cleaned.startsWith('0')) return '+212' + cleaned.slice(1);
  return '+212' + cleaned;
}
 
// ─────────────────────────────────────────────
// Envoi OTP
// ─────────────────────────────────────────────
 
export async function handleSendOTP(phoneNumber: string): Promise<OTPSendResult> {
  console.log('[FTM-DEBUG] Auth - Sending OTP', { rawPhone: phoneNumber });
 
  const formattedPhone = formatMoroccanPhone(phoneNumber);
 
  if (formattedPhone.length < 12) {
    console.log('[FTM-DEBUG] Auth - Invalid phone format', { formattedPhone });
    return { error: 'Numéro invalide. Format attendu: 06XXXXXXXX' };
  }
 
  try {
    const { data, error } = await supabase.auth.signInWithOtp({
      phone: formattedPhone,
    });
 
    if (error) {
      console.log('[FTM-DEBUG] Auth - OTP send error', {
        error: error.message,
        phone: formattedPhone,
      });
      return { error: error.message };
    }
 
    console.log('[FTM-DEBUG] Auth - OTP sent successfully', { phone: formattedPhone, data });
    return { success: true, formattedPhone };
  } catch (err) {
    console.log('[FTM-DEBUG] Auth - OTP send exception', { err });
    return { error: 'Erreur réseau. Vérifiez votre connexion.' };
  }
}
 
// ─────────────────────────────────────────────
// Vérification OTP
// ─────────────────────────────────────────────
 
export async function handleVerifyOTP(
  formattedPhone: string,
  otpCode: string
): Promise<ProfileResult> {
  console.log('[FTM-DEBUG] Auth - Verifying OTP', {
    phone: formattedPhone,
    codeLength: otpCode.length,
  });
 
  try {
    const { data, error } = await supabase.auth.verifyOtp({
      phone: formattedPhone,
      token: otpCode,
      type: 'sms',
    });
 
    if (error) {
      console.log('[FTM-DEBUG] Auth - OTP verification error', { error: error.message });
      return { error: 'Code incorrect ou expiré. Réessayez.' };
    }
 
    if (!data.user) {
      return { error: 'Utilisateur introuvable après vérification.' };
    }
 
    console.log('[FTM-DEBUG] Auth - OTP verified, session created', {
      userId: data.user.id,
      sessionExpiry: data.session?.expires_at,
    });
 
    const profileResult = await getOrCreateProfile(data.user, formattedPhone);
    return profileResult;
  } catch (err) {
    console.log('[FTM-DEBUG] Auth - OTP verification exception', { err });
    return { error: 'Erreur lors de la vérification.' };
  }
}
 
// ─────────────────────────────────────────────
// Récupérer ou initialiser le profil
// ─────────────────────────────────────────────
 
export async function getOrCreateProfile(
  authUser: { id: string },
  formattedPhone: string
): Promise<ProfileResult> {
  console.log('[FTM-DEBUG] Profile - Fetching profile', { userId: authUser.id });
 
  const { data: existingProfile, error: fetchError } = await supabase
    .from('profiles')
    .select('*')
    .eq('user_id', authUser.id)
    .single();
 
  if (fetchError && fetchError.code !== 'PGRST116') {
    console.log('[FTM-DEBUG] Profile - Fetch error', { error: fetchError });
    return { error: fetchError.message };
  }
 
  if (existingProfile) {
    console.log('[FTM-DEBUG] Profile - Existing profile found', {
      profileId: existingProfile.id,
      role: existingProfile.role,
      isActive: existingProfile.is_active,
    });
    return { success: true, profile: existingProfile as Profile, isNew: false };
  }
 
  console.log('[FTM-DEBUG] Profile - No profile found, needs creation', { userId: authUser.id });
  return { success: true, profile: null, isNew: true, phone: formattedPhone };
}
 
// ─────────────────────────────────────────────
// Création du profil (nouvel utilisateur)
// ─────────────────────────────────────────────
 
export async function handleCreateProfile(
  authUserId: string,
  formattedPhone: string,
  fullName: string,
  role: 'client' | 'driver'
): Promise<ProfileResult> {
  console.log('[FTM-DEBUG] Profile - Creating new profile', {
    userId: authUserId,
    phone: formattedPhone,
    role,
    fullName,
  });
 
  const { data, error } = await supabase
    .from('profiles')
    .insert({
      user_id:             authUserId,
      phone_number:        formattedPhone,
      full_name:           fullName,
      role,
      language_preference: 'fr',
      is_active:           true,
    })
    .select()
    .single();
 
  if (error) {
    console.log('[FTM-DEBUG] Profile - Creation error', { error: error.message });
    return { error: 'Impossible de créer le profil.' };
  }
 
  console.log('[FTM-DEBUG] Profile - Created successfully', {
    profileId: data.id,
    role: data.role,
    createdAt: data.created_at,
  });
 
  return { success: true, profile: data as Profile };
}
 
// ─────────────────────────────────────────────
// Déconnexion
// ─────────────────────────────────────────────
 
export async function handleSignOut(): Promise<{ success?: boolean; error?: string }> {
  console.log('[FTM-DEBUG] Auth - Sign out initiated');
 
  const { error } = await supabase.auth.signOut();
 
  if (error) {
    console.log('[FTM-DEBUG] Auth - Sign out error', { error: error.message });
    return { error: error.message };
  }
 
  console.log('[FTM-DEBUG] Auth - Signed out successfully');
  return { success: true };
}
ENDOFFILE
 
cat > frontend/src/screens/auth/PhoneInputScreen.tsx << 'ENDOFFILE'
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
ENDOFFILE
 
cat > frontend/src/screens/auth/OTPVerificationScreen.tsx << 'ENDOFFILE'
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
ENDOFFILE
 
cat > frontend/src/screens/auth/ProfileSetupScreen.tsx << 'ENDOFFILE'
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
ENDOFFILE
 
cat > frontend/src/navigation/RootNavigator.tsx << 'ENDOFFILE'
// /frontend/src/navigation/RootNavigator.tsx
// FTM — Navigation racine + initialisation + routing selon rôle
 
import React, { useEffect, useState } from 'react';
import { View, ActivityIndicator, StyleSheet } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
 
import { supabase } from '../lib/supabaseClient';
import { loadSavedLanguage } from '../services/i18nService';
import { COLORS } from '../constants/theme';
 
import PhoneInputScreen from '../screens/auth/PhoneInputScreen';
import OTPVerificationScreen from '../screens/auth/OTPVerificationScreen';
import ProfileSetupScreen from '../screens/auth/ProfileSetupScreen';
 
import type { AppRoute, Profile } from '../types/database';
 
// ─────────────────────────────────────────────
// Types de navigation
// ─────────────────────────────────────────────
 
export type AuthStackParamList = {
  PhoneInput:      undefined;
  OTPVerification: { formattedPhone: string };
  ProfileSetup:    { authUserId: string; formattedPhone: string };
};
 
const AuthStack = createNativeStackNavigator<AuthStackParamList>();
 
// ─────────────────────────────────────────────
// Écrans placeholder pour les stacks post-auth
// ─────────────────────────────────────────────
 
import { Text } from 'react-native';
 
function PlaceholderScreen({ label }: { label: string }) {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: COLORS.background }}>
      <Text style={{ fontSize: 18, color: COLORS.textMuted }}>{label} — À implémenter (P2+)</Text>
    </View>
  );
}
 
// ─────────────────────────────────────────────
// Initialisation de l'app
// ─────────────────────────────────────────────
 
async function initializeApp(): Promise<{ route: AppRoute; profile?: Profile }> {
  console.log('[FTM-DEBUG] App - Initializing', { timestamp: new Date().toISOString() });
 
  await loadSavedLanguage();
 
  const { data: { session }, error } = await supabase.auth.getSession();
 
  console.log('[FTM-DEBUG] App - Session check', {
    hasSession: !!session,
    userId: session?.user?.id,
    error: error?.message,
  });
 
  if (!session) {
    return { route: 'AuthStack' };
  }
 
  const { data: profile } = await supabase
    .from('profiles')
    .select('id, role, full_name, is_active, language_preference')
    .eq('user_id', session.user.id)
    .single();
 
  console.log('[FTM-DEBUG] App - Profile loaded', {
    profileId: profile?.id,
    role: profile?.role,
    isActive: profile?.is_active,
  });
 
  if (!profile) return { route: 'ProfileSetupScreen' };
  if (!profile.is_active) return { route: 'AccountSuspendedScreen' };
 
  switch (profile.role) {
    case 'client': return { route: 'ClientHomeStack', profile };
    case 'driver': return { route: 'DriverHomeStack', profile };
    case 'admin':  return { route: 'AdminStack', profile };
    default:       return { route: 'AuthStack' };
  }
}
 
// ─────────────────────────────────────────────
// Composant principal
// ─────────────────────────────────────────────
 
export default function RootNavigator() {
  const [isLoading, setIsLoading] = useState(true);
  const [initialRoute, setInitialRoute] = useState<AppRoute>('AuthStack');
 
  useEffect(() => {
    initializeApp().then(({ route }) => {
      setInitialRoute(route);
      setIsLoading(false);
    });
 
    // Écouter les changements de session
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      console.log('[FTM-DEBUG] Auth - State change', {
        event,
        userId: session?.user?.id,
        timestamp: new Date().toISOString(),
      });
 
      if (event === 'SIGNED_OUT') {
        setInitialRoute('AuthStack');
      }
 
      if (event === 'TOKEN_REFRESHED') {
        console.log('[FTM-DEBUG] Auth - Token refreshed successfully');
      }
    });
 
    return () => subscription.unsubscribe();
  }, []);
 
  if (isLoading) {
    return (
      <View style={styles.splash}>
        <ActivityIndicator size="large" color={COLORS.primary} />
      </View>
    );
  }
 
  const showAuth =
    initialRoute === 'AuthStack' ||
    initialRoute === 'ProfileSetupScreen';
 
  return (
    <NavigationContainer>
      {showAuth ? (
        <AuthStack.Navigator screenOptions={{ headerShown: false }}>
          <AuthStack.Screen name="PhoneInput"      component={PhoneInputScreen} />
          <AuthStack.Screen name="OTPVerification" component={OTPVerificationScreen} />
          <AuthStack.Screen name="ProfileSetup"    component={ProfileSetupScreen} />
        </AuthStack.Navigator>
      ) : (
        /* Placeholder pour les stacks P2+ */
        <View style={{ flex: 1 }}>
          <PlaceholderScreen
            label={
              initialRoute === 'ClientHomeStack' ? 'Client Home (P3)'
              : initialRoute === 'DriverHomeStack' ? 'Driver Home (P2)'
              : initialRoute === 'AdminStack' ? 'Admin (P7)'
              : 'Compte suspendu'
            }
          />
        </View>
      )}
    </NavigationContainer>
  );
}
 
const styles = StyleSheet.create({
  splash: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.background,
  },
});
ENDOFFILE
 
echo "✅ Fichiers P1 créés"