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
