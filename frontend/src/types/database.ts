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
