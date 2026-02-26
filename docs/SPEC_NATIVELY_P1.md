# SPEC NATIVELY — Fast Trans Maroc (FTM)
# PARTIE P1 : Fondations, Configuration & Authentification OTP
# Fichier : docs/SPEC_NATIVELY_P1.md
# Version : 1.0 | Backend : Supabase | App : Natively.dev
# =====================================================================
# RÈGLE D'OR : Ce fichier est autonome. Il couvre exclusivement P1.
# Les parties P2→P7 feront l'objet de fichiers séparés.
# =====================================================================

---

## 0. CONTEXTE GLOBAL DE L'APPLICATION

**Nom** : Fast Trans Maroc (FTM)  
**Plateforme** : Application mobile (Android & iOS) générée via Natively.dev  
**Backend** : Supabase (PostgreSQL + Auth + Storage + Realtime)  
**Marché** : Maroc — Interface bilingue Arabe/Français, paiement Cash, OTP téléphone  
**Rôles utilisateurs** : `client` | `driver` | `admin` (ENUM `user_role`)

---

## 1. DESIGN SYSTEM — CONFIGURATION UI GLOBALE

> Ces tokens doivent être définis comme constantes globales dans le projet Natively.

### 1.1 Palette de Couleurs

```javascript
// /constants/theme.js
export const COLORS = {
  primary:    '#0056B3', // Bleu Royal — Actions principales, headers
  cta:        '#F39C12', // Jaune Ambre — Boutons CTA, bouton micro audio
  success:    '#28A745', // Vert — Validation, statut "verified"
  alert:      '#DC3545', // Rouge — Erreurs, alertes, rejets
  background: '#F8F9FA', // Gris très clair — Fond des écrans
  white:      '#FFFFFF',
  textDark:   '#1A1A2E',
  textMuted:  '#6C757D',
};
```

### 1.2 Typographie

```javascript
// /constants/theme.js (suite)
export const FONTS = {
  regular: 'Inter-Regular',    // Fallback: Roboto-Regular
  medium:  'Inter-Medium',
  bold:    'Inter-Bold',
  // Support Arabe : activer RTL layout via I18nManager
  arabic:  'Cairo-Regular',   // Police recommandée pour l'Arabe
};

export const FONT_SIZES = {
  xs:   12,
  sm:   14,
  md:   16,
  lg:   18,
  xl:   22,
  xxl:  28,
};
```

### 1.3 Dimensions & Arrondis

```javascript
export const RADIUS = {
  card:   12, // Cards, modales, containers
  button:  8, // Boutons principaux
  input:   8, // Champs de saisie
  chip:   20, // Tags, badges de statut
};

export const SPACING = {
  xs: 4, sm: 8, md: 16, lg: 24, xl: 32,
};
```

### 1.4 Composants de Base (Référence Natively)

```javascript
// Bouton Principal (CTA)
// - Couleur fond : COLORS.primary (#0056B3)
// - Couleur texte : COLORS.white
// - Border radius : RADIUS.button (8px)
// - Hauteur : 52px
// - Ombre portée : elevation 4

// Bouton CTA secondaire (ex: Confirmer)
// - Couleur fond : COLORS.cta (#F39C12)
// - Couleur texte : COLORS.white

// Card Container
// - Fond : COLORS.white
// - Border radius : RADIUS.card (12px)
// - Ombre : elevation 2
// - Padding interne : SPACING.md (16px)

// Bouton Micro Audio (Chat Darija)
// - Forme : Cercle, diamètre 64px
// - Couleur : COLORS.cta (#F39C12) — orange vif
// - Icône : microphone blanc centré
// - Position : flottant, bottom-center
```

---

## 2. CONFIGURATION SUPABASE

### 2.1 Variables d'Environnement

> Référence fichier : `.env.example` dans l'arborescence GitHub

```bash
# .env.example
SUPABASE_URL=https://VOTRE_PROJECT_ID.supabase.co
SUPABASE_ANON_KEY=VOTRE_ANON_KEY_PUBLIQUE
SUPABASE_SERVICE_ROLE_KEY=VOTRE_SERVICE_ROLE_KEY  # Backend uniquement, jamais exposé
```

### 2.2 Initialisation du Client Supabase

```javascript
// /lib/supabaseClient.js
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false, // Mobile app — pas de deep link OAuth
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
```

---

## 3. AUTHENTIFICATION OTP — TÉLÉPHONE MAROCAIN

### 3.1 Logique Métier

- **Méthode** : OTP SMS via Supabase Auth (provider Phone)
- **Format téléphone Maroc** : `+212XXXXXXXXX` (9 chiffres après indicatif)
- **Flux** : Saisie numéro → Envoi OTP → Vérification code → Création/récupération session
- **Table SQL concernée** : `auth.users` (Supabase interne) + `profiles`

### 3.2 Écran 1 — Saisie du Numéro de Téléphone

```javascript
// /screens/auth/PhoneInputScreen.js

import { supabase } from '../../lib/supabaseClient';
import { COLORS, RADIUS, FONTS } from '../../constants/theme';

/**
 * ÉTAT LOCAL
 * - phoneNumber : string (ex: "0612345678" saisi par l'user)
 * - isLoading : boolean
 * - errorMessage : string | null
 */

/**
 * FONCTION : Formater le numéro en format international Maroc
 * Entrée : "0612345678" ou "612345678" ou "+212612345678"
 * Sortie : "+212612345678"
 */
function formatMoroccanPhone(rawPhone) {
  let cleaned = rawPhone.replace(/\s+/g, '').replace(/-/g, '');
  
  if (cleaned.startsWith('+212')) {
    return cleaned; // Déjà au bon format
  }
  if (cleaned.startsWith('00212')) {
    return '+' + cleaned.slice(2);
  }
  if (cleaned.startsWith('0')) {
    return '+212' + cleaned.slice(1);
  }
  return '+212' + cleaned;
}

/**
 * FONCTION PRINCIPALE : Envoyer l'OTP
 */
async function handleSendOTP(phoneNumber) {
  console.log('[FTM-DEBUG] Auth - Sending OTP', { rawPhone: phoneNumber });
  
  const formattedPhone = formatMoroccanPhone(phoneNumber);
  
  // Validation basique
  if (formattedPhone.length < 12) {
    console.log('[FTM-DEBUG] Auth - Invalid phone format', { formattedPhone });
    return { error: 'Numéro invalide. Format attendu: 06XXXXXXXX' };
  }
  
  try {
    const { data, error } = await supabase.auth.signInWithOtp({
      phone: formattedPhone,
    });
    
    if (error) {
      console.log('[FTM-DEBUG] Auth - OTP send error', { error: error.message, phone: formattedPhone });
      return { error: error.message };
    }
    
    console.log('[FTM-DEBUG] Auth - OTP sent successfully', { phone: formattedPhone, data });
    return { success: true, formattedPhone };
    
  } catch (err) {
    console.log('[FTM-DEBUG] Auth - OTP send exception', { err });
    return { error: 'Erreur réseau. Vérifiez votre connexion.' };
  }
}

/**
 * UI — PhoneInputScreen
 * 
 * LAYOUT :
 * ┌─────────────────────────────┐
 * │  [Logo FTM]                 │
 * │  Titre : "Bienvenue sur FTM"│
 * │  Sous-titre bilingue AR/FR  │
 * │                             │
 * │  [Flag 🇲🇦] [+212] [Input]  │
 * │                             │
 * │  [Bouton "Envoyer le code"] │
 * │   (COLORS.primary, 52px)    │
 * └─────────────────────────────┘
 * 
 * COMPORTEMENT :
 * - Fond : COLORS.background (#F8F9FA)
 * - Input téléphone : KeyboardType="phone-pad"
 * - Préfixe "+212" non-éditable, affiché en gris
 * - Bouton désactivé si input vide
 * - Loading spinner pendant l'envoi OTP
 * - En cas d'erreur : message en COLORS.alert (#DC3545)
 * - Navigation vers OTPVerificationScreen au succès
 */
```

### 3.3 Écran 2 — Vérification du Code OTP

```javascript
// /screens/auth/OTPVerificationScreen.js

/**
 * PROPS reçues de PhoneInputScreen :
 * - formattedPhone : string (ex: "+212612345678")
 */

/**
 * ÉTAT LOCAL
 * - otpCode : string (6 chiffres)
 * - isLoading : boolean
 * - errorMessage : string | null
 * - countdown : number (60 secondes pour renvoyer)
 */

/**
 * FONCTION : Vérifier l'OTP et créer la session
 */
async function handleVerifyOTP(formattedPhone, otpCode) {
  console.log('[FTM-DEBUG] Auth - Verifying OTP', { phone: formattedPhone, codeLength: otpCode.length });
  
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
    
    console.log('[FTM-DEBUG] Auth - OTP verified, session created', {
      userId: data.user?.id,
      sessionExpiry: data.session?.expires_at,
    });
    
    // Vérifier si le profil existe déjà
    const profile = await getOrCreateProfile(data.user, formattedPhone);
    
    return { success: true, user: data.user, profile };
    
  } catch (err) {
    console.log('[FTM-DEBUG] Auth - OTP verification exception', { err });
    return { error: 'Erreur lors de la vérification.' };
  }
}

/**
 * UI — OTPVerificationScreen
 *
 * LAYOUT :
 * ┌─────────────────────────────┐
 * │  ← Retour                  │
 * │  "Code envoyé au +212..."  │
 * │                             │
 * │  [  ] [  ] [  ] [  ] [  ] [  ]  │
 * │  (6 cases OTP séparées)    │
 * │                             │
 * │  [Bouton "Confirmer"]      │
 * │  (COLORS.primary)          │
 * │                             │
 * │  "Renvoyer dans 58s"       │
 * │  (lien actif après 60s)    │
 * └─────────────────────────────┘
 *
 * COMPORTEMENT :
 * - 6 inputs numériques, auto-focus sur le suivant
 * - Auto-submit quand 6 chiffres saisis
 * - Countdown 60s avant possibilité de renvoyer
 * - En cas d'erreur : shake animation + COLORS.alert
 */
```

---

## 4. GESTION DU PROFIL (TABLE: profiles)

### 4.1 Structure SQL de référence

```sql
-- TABLE: profiles (Source de vérité)
-- Colonnes utilisées dans P1 :
--   id            UUID PRIMARY KEY
--   user_id       UUID REFERENCES auth.users(id)
--   phone_number  VARCHAR(20) UNIQUE NOT NULL
--   full_name     VARCHAR(255) NOT NULL
--   role          user_role ('client' | 'driver' | 'admin')
--   language_preference  VARCHAR(2) DEFAULT 'fr' ('fr' | 'ar')
--   is_active     BOOLEAN DEFAULT true
--   created_at    TIMESTAMP WITH TIME ZONE
--   updated_at    TIMESTAMP WITH TIME ZONE
```

### 4.2 Fonction : Récupérer ou Créer le Profil

```javascript
// /services/authService.js

/**
 * Après vérification OTP réussie :
 * 1. Cherche un profil existant lié à auth.user.id
 * 2. Si absent → crée un profil minimal
 * 3. Retourne le profil et détermine la navigation
 */
async function getOrCreateProfile(authUser, formattedPhone) {
  console.log('[FTM-DEBUG] Profile - Fetching profile', { userId: authUser.id });
  
  // 1. Chercher profil existant
  const { data: existingProfile, error: fetchError } = await supabase
    .from('profiles')
    .select('*')
    .eq('user_id', authUser.id)
    .single();
  
  if (fetchError && fetchError.code !== 'PGRST116') {
    // PGRST116 = "Row not found" — cas normal pour un nouvel utilisateur
    console.log('[FTM-DEBUG] Profile - Fetch error', { error: fetchError });
    throw fetchError;
  }
  
  if (existingProfile) {
    console.log('[FTM-DEBUG] Profile - Existing profile found', {
      profileId: existingProfile.id,
      role: existingProfile.role,
      isActive: existingProfile.is_active,
    });
    return { profile: existingProfile, isNew: false };
  }
  
  // 2. Nouveau profil — navigation vers écran de complétion
  console.log('[FTM-DEBUG] Profile - No profile found, needs creation', { userId: authUser.id });
  return { profile: null, isNew: true, phone: formattedPhone };
}
```

### 4.3 Écran 3 — Complétion du Profil (Nouvel Utilisateur)

```javascript
// /screens/auth/ProfileSetupScreen.js

/**
 * Affiché uniquement si isNew === true
 * L'utilisateur choisit son rôle et saisit son nom complet
 */

/**
 * ÉTAT LOCAL
 * - fullName : string
 * - selectedRole : 'client' | 'driver'
 * - isLoading : boolean
 */

async function handleCreateProfile(authUserId, formattedPhone, fullName, role) {
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
      role:                role,            // 'client' ou 'driver'
      language_preference: 'fr',            // défaut FR, modifiable dans Réglages
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
  
  return { success: true, profile: data };
}

/**
 * LOGIQUE DE NAVIGATION POST-CRÉATION :
 * - role === 'client' → HomeClientScreen
 * - role === 'driver' → OnboardingDriverScreen (P2)
 * - role === 'admin'  → AdminDashboard (P7)
 */

/**
 * UI — ProfileSetupScreen
 *
 * LAYOUT :
 * ┌─────────────────────────────┐
 * │  "Créez votre profil"      │
 * │                             │
 * │  [Input] Votre nom complet │
 * │                             │
 * │  Vous êtes :               │
 * │  [🧑 Client] [🚚 Chauffeur] │
 * │  (Sélection toggle)        │
 * │                             │
 * │  [Bouton "Commencer"]      │
 * │  (COLORS.primary)          │
 * └─────────────────────────────┘
 *
 * COMPORTEMENT :
 * - Toggle rôle : card sélectionnée = bordure COLORS.primary
 * - Card Chauffeur : icône camion + "Devenez transporteur FTM"
 * - Card Client : icône personne + "Expédiez facilement"
 * - Bouton désactivé si fullName vide ou rôle non sélectionné
 */
```

---

## 5. SWITCH BILINGUE ARABE / FRANÇAIS

### 5.1 Logique du Switch de Langue

```javascript
// /services/i18nService.js

/**
 * FTM supporte 2 langues :
 * - 'fr' : Français (LTR — gauche à droite)
 * - 'ar' : Arabe (RTL — droite à gauche)
 * 
 * La préférence est stockée dans :
 * - profiles.language_preference (persistance Supabase)
 * - AsyncStorage (accès hors-ligne rapide)
 */

import { I18nManager } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

const TRANSLATIONS = {
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

let currentLang = 'fr';

export function t(key) {
  return TRANSLATIONS[currentLang]?.[key] || TRANSLATIONS['fr'][key] || key;
}

export async function setLanguage(lang) {
  console.log('[FTM-DEBUG] i18n - Language switch', { from: currentLang, to: lang });
  
  currentLang = lang;
  
  // Activer/désactiver RTL selon la langue
  const isRTL = lang === 'ar';
  I18nManager.forceRTL(isRTL);
  
  // Persister localement
  await AsyncStorage.setItem('ftm_language', lang);
  
  // Persister dans Supabase si profil connecté
  // (Fait dans /screens/settings/LanguageScreen.js — voir P7)
  
  console.log('[FTM-DEBUG] i18n - Language applied', { lang, isRTL });
}

export async function loadSavedLanguage() {
  try {
    const saved = await AsyncStorage.getItem('ftm_language');
    if (saved) {
      await setLanguage(saved);
      console.log('[FTM-DEBUG] i18n - Restored language from storage', { lang: saved });
    }
  } catch (err) {
    console.log('[FTM-DEBUG] i18n - Load language error', { err });
  }
}
```

---

## 6. GESTION DE SESSION & NAVIGATION RACINE

### 6.1 Vérification de Session au Démarrage

```javascript
// /App.js ou /navigation/RootNavigator.js

/**
 * AU DÉMARRAGE DE L'APP :
 * 1. Charger la langue sauvegardée (loadSavedLanguage)
 * 2. Vérifier session Supabase active
 * 3. Si session active → charger profil → router vers bon écran
 * 4. Si pas de session → AuthStack (PhoneInputScreen)
 */

async function initializeApp() {
  console.log('[FTM-DEBUG] App - Initializing', { timestamp: new Date().toISOString() });
  
  // 1. Langue
  await loadSavedLanguage();
  
  // 2. Session
  const { data: { session }, error } = await supabase.auth.getSession();
  
  console.log('[FTM-DEBUG] App - Session check', {
    hasSession: !!session,
    userId: session?.user?.id,
    error: error?.message,
  });
  
  if (!session) {
    return { route: 'AuthStack' };
  }
  
  // 3. Profil
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
  
  // 4. Router selon rôle
  switch (profile.role) {
    case 'client': return { route: 'ClientHomeStack' };
    case 'driver': return { route: 'DriverHomeStack' };
    case 'admin':  return { route: 'AdminStack' };
    default:       return { route: 'AuthStack' };
  }
}

// Écouter les changements de session (déconnexion auto)
supabase.auth.onAuthStateChange((event, session) => {
  console.log('[FTM-DEBUG] Auth - State change', {
    event,
    userId: session?.user?.id,
    timestamp: new Date().toISOString(),
  });
  
  if (event === 'SIGNED_OUT') {
    // Rediriger vers AuthStack
    // navigateToAuth();
  }
  
  if (event === 'TOKEN_REFRESHED') {
    console.log('[FTM-DEBUG] Auth - Token refreshed successfully');
  }
});
```

### 6.2 Fonction de Déconnexion

```javascript
// /services/authService.js (suite)

async function handleSignOut() {
  console.log('[FTM-DEBUG] Auth - Sign out initiated');
  
  const { error } = await supabase.auth.signOut();
  
  if (error) {
    console.log('[FTM-DEBUG] Auth - Sign out error', { error: error.message });
    return { error };
  }
  
  // Nettoyer le stockage local si nécessaire
  // await AsyncStorage.removeItem('ftm_driver_location'); // (P3)
  
  console.log('[FTM-DEBUG] Auth - Signed out successfully');
  return { success: true };
}
```

---

## 7. ARBORESCENCE DES FICHIERS — PÉRIMÈTRE P1

```
src/
├── constants/
│   └── theme.js              ← Couleurs, fonts, radius, spacing
├── lib/
│   └── supabaseClient.js     ← Init client Supabase
├── services/
│   ├── authService.js        ← OTP, getOrCreateProfile, signOut
│   └── i18nService.js        ← t(), setLanguage(), loadSavedLanguage()
├── screens/
│   └── auth/
│       ├── PhoneInputScreen.js       ← Saisie téléphone + envoi OTP
│       ├── OTPVerificationScreen.js  ← Vérification code + session
│       └── ProfileSetupScreen.js     ← Création profil (nom + rôle)
└── navigation/
    └── RootNavigator.js      ← Init app + routing selon rôle
```

---

## 8. RÉCAPITULATIF DES LOGS DE DEBUG (P1)

| Action | Log FTM-DEBUG |
|--------|---------------|
| Init Supabase | `[FTM-DEBUG] Supabase client initialized` |
| Envoi OTP | `[FTM-DEBUG] Auth - Sending OTP` |
| Succès OTP envoyé | `[FTM-DEBUG] Auth - OTP sent successfully` |
| Erreur OTP envoi | `[FTM-DEBUG] Auth - OTP send error` |
| Vérification OTP | `[FTM-DEBUG] Auth - Verifying OTP` |
| Session créée | `[FTM-DEBUG] Auth - OTP verified, session created` |
| Profil existant | `[FTM-DEBUG] Profile - Existing profile found` |
| Nouveau profil | `[FTM-DEBUG] Profile - No profile found, needs creation` |
| Création profil | `[FTM-DEBUG] Profile - Creating new profile` |
| Switch langue | `[FTM-DEBUG] i18n - Language switch` |
| Init app | `[FTM-DEBUG] App - Initializing` |
| Check session | `[FTM-DEBUG] App - Session check` |
| Déconnexion | `[FTM-DEBUG] Auth - Sign out initiated` |

---

## 9. CHECKLIST DE VALIDATION P1

Avant de passer à P2, vérifier :

- [ ] Client Supabase initialisé sans erreur dans les logs
- [ ] OTP reçu sur numéro marocain (+212)
- [ ] Session créée et visible dans Supabase Auth Dashboard
- [ ] Profil inséré dans table `profiles` avec bon `role`
- [ ] Switch FR/AR change le sens de lecture (RTL/LTR)
- [ ] Routing post-login correct selon `role` (client/driver/admin)
- [ ] Tous les `console.log('[FTM-DEBUG]...')` visibles dans Debug Console Codespaces

---

## 10. LIAISON AVEC LES PARTIES SUIVANTES

| Partie | Dépendance de P1 |
|--------|-----------------|
| **P2** | `profiles.id` + `profiles.role === 'driver'` → OnboardingDriver |
| **P3** | `profiles.id` → création missions, `drivers.id` → tracking GPS |
| **P5** | `drivers.id` → création wallet après onboarding P2 |
| **P6** | `profiles.id` → notifications push |
| **P7** | `profiles.role === 'admin'` → accès Admin |

---

*FTM Spec P1 — Fin du fichier*  
*Prochaine étape : SPEC_NATIVELY_P2.md — Onboarding Driver & Documents*
