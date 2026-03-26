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
