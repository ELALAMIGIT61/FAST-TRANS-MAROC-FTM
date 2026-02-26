# SPEC NATIVELY — Fast Trans Maroc (FTM)
# PARTIE P2 : Profils, Documents & Onboarding Driver
# Fichier : docs/SPEC_NATIVELY_P2.md
# Version : 1.0 | Backend : Supabase | App : Natively.dev
# =====================================================================
# PRÉREQUIS : P1 validée (supabaseClient.js, profiles créé, session active)
# TABLES SQL : drivers, document_reminders
# STORAGE SUPABASE : bucket "driver-documents"
# =====================================================================

---

## 1. CONTEXTE & FLUX GÉNÉRAL

Après la création du profil (P1), deux chemins distincts :

```
ProfileSetupScreen (P1)
       │
       ├── role === 'client'  ──→ ClientHomeStack (P3)
       │
       └── role === 'driver'  ──→ [P2 — OnboardingDriverStack]
                                        │
                                        ├── Step 1 : Infos Véhicule
                                        ├── Step 2 : Documents Légaux
                                        ├── Step 3 : Upload Fichiers
                                        └── Step 4 : Confirmation (en attente vérification)
```

**Règle métier** : Un chauffeur ne peut accepter des missions que si `drivers.is_verified = true`
(colonne GENERATED — vraie seulement si les 4 documents ont le statut `'verified'`)

---

## 2. STRUCTURE SQL DE RÉFÉRENCE (TABLE: drivers)

```sql
-- TABLE: drivers — Source de vérité complète pour P2
-- Toutes les colonnes utilisées dans cette partie :

CREATE TABLE drivers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,

    -- STEP 1 : Informations véhicule
    vehicle_category    vehicle_category NOT NULL,  -- 'vul' | 'n2_medium' | 'n2_large'
    vehicle_brand       VARCHAR(100),
    vehicle_model       VARCHAR(100),
    license_plate       VARCHAR(20) UNIQUE NOT NULL,
    vehicle_capacity_kg INTEGER CHECK (vehicle_capacity_kg > 0),

    -- STEP 2 : Documents légaux (numéros + dates expiration)
    driver_license_number        VARCHAR(50) UNIQUE NOT NULL,
    driver_license_expiry        DATE NOT NULL,
    driver_license_verified      verification_status DEFAULT 'pending',

    vehicle_registration_number  VARCHAR(50) UNIQUE NOT NULL,
    vehicle_registration_verified verification_status DEFAULT 'pending',

    insurance_number             VARCHAR(50) NOT NULL,
    insurance_expiry             DATE NOT NULL,
    insurance_verified           verification_status DEFAULT 'pending',

    technical_inspection_expiry  DATE NOT NULL,
    technical_inspection_verified verification_status DEFAULT 'pending',

    -- STEP 3 : URLs fichiers (Supabase Storage)
    driver_license_url           TEXT,
    vehicle_registration_url     TEXT,
    insurance_url                TEXT,
    technical_inspection_url     TEXT,

    -- Statut global calculé automatiquement
    is_verified BOOLEAN GENERATED ALWAYS AS (
        driver_license_verified = 'verified' AND
        vehicle_registration_verified = 'verified' AND
        insurance_verified = 'verified' AND
        technical_inspection_verified = 'verified'
    ) STORED,

    is_available  BOOLEAN DEFAULT false,
    current_location          GEOGRAPHY(POINT, 4326),
    last_location_update      TIMESTAMP WITH TIME ZONE,
    total_missions            INTEGER DEFAULT 0,
    rating_average            DECIMAL(3,2) DEFAULT 0,
    total_reviews             INTEGER DEFAULT 0,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- TABLE: document_reminders — Rappels expiration
CREATE TABLE document_reminders (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id     UUID REFERENCES drivers(id) ON DELETE CASCADE NOT NULL,
    document_type VARCHAR(50) NOT NULL,  -- 'driver_license' | 'insurance' | 'technical_inspection'
    expiry_date   DATE NOT NULL,
    reminder_30_days_sent BOOLEAN DEFAULT false,
    reminder_15_days_sent BOOLEAN DEFAULT false,
    reminder_7_days_sent  BOOLEAN DEFAULT false,
    created_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ENUM: verification_status
-- 'pending'  → soumis, en attente de validation Admin
-- 'verified' → approuvé par Admin
-- 'rejected' → refusé par Admin (motif à afficher)
-- 'expired'  → date d'expiration dépassée
```

---

## 3. CONFIGURATION SUPABASE STORAGE

### 3.1 Bucket "driver-documents"

```javascript
// À configurer dans le Dashboard Supabase → Storage

/*
  Bucket name  : driver-documents
  Public       : false  (accès privé, URLs signées uniquement)
  Allowed MIME : image/jpeg, image/png, application/pdf
  Max file size: 5 MB par fichier

  Structure des chemins :
  driver-documents/
  └── {driver_id}/
      ├── driver_license.{jpg|pdf}
      ├── vehicle_registration.{jpg|pdf}
      ├── insurance.{jpg|pdf}
      └── technical_inspection.{jpg|pdf}
*/
```

### 3.2 Policy Storage (RLS Bucket)

```sql
-- Politique : un chauffeur peut uploader uniquement dans son propre dossier
CREATE POLICY "Drivers upload own documents"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'driver-documents'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Politique : un chauffeur peut lire ses propres documents
CREATE POLICY "Drivers read own documents"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'driver-documents'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Politique : Admin peut tout lire
CREATE POLICY "Admin read all documents"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'driver-documents'
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);
```

---

## 4. SERVICE UPLOAD DOCUMENTS

```javascript
// /services/documentService.js

import { supabase } from '../lib/supabaseClient';

/**
 * TYPES DE DOCUMENTS SUPPORTÉS
 * Chaque type correspond à une colonne *_url et *_verified dans drivers
 */
export const DOCUMENT_TYPES = {
  DRIVER_LICENSE:        'driver_license',
  VEHICLE_REGISTRATION:  'vehicle_registration',
  INSURANCE:             'insurance',
  TECHNICAL_INSPECTION:  'technical_inspection',
};

/**
 * LABELS BILINGUES PAR TYPE DE DOCUMENT
 */
export const DOCUMENT_LABELS = {
  driver_license: {
    fr: 'Permis de conduire',
    ar: 'رخصة السياقة',
    icon: '🪪',
  },
  vehicle_registration: {
    fr: 'Carte grise',
    ar: 'بطاقة تقنية',
    icon: '📄',
  },
  insurance: {
    fr: 'Assurance',
    ar: 'التأمين',
    icon: '🛡️',
  },
  technical_inspection: {
    fr: 'Visite technique',
    ar: 'المعاينة التقنية',
    icon: '🔧',
  },
};

/**
 * UPLOAD D'UN DOCUMENT VERS SUPABASE STORAGE
 * @param {string} driverId   - UUID du driver (dossier dans le bucket)
 * @param {string} docType    - Clé DOCUMENT_TYPES
 * @param {File|Blob} file    - Fichier sélectionné (image ou PDF)
 * @param {string} mimeType   - 'image/jpeg' | 'image/png' | 'application/pdf'
 * @returns {string} publicUrl - URL signée du document uploadé
 */
export async function uploadDocument(driverId, docType, file, mimeType) {
  console.log('[FTM-DEBUG] Document - Upload start', {
    driverId,
    docType,
    mimeType,
    fileSize: file?.size,
  });

  // Validation taille (5 MB max)
  if (file.size > 5 * 1024 * 1024) {
    console.log('[FTM-DEBUG] Document - File too large', { size: file.size });
    return { error: 'Fichier trop volumineux (max 5 MB).' };
  }

  const extension = mimeType === 'application/pdf' ? 'pdf' : 'jpg';
  const filePath  = `${driverId}/${docType}.${extension}`;

  // Upload (écrase si existe déjà — upsert)
  const { data, error: uploadError } = await supabase.storage
    .from('driver-documents')
    .upload(filePath, file, {
      contentType: mimeType,
      upsert: true,
    });

  if (uploadError) {
    console.log('[FTM-DEBUG] Document - Upload error', {
      docType,
      error: uploadError.message,
    });
    return { error: `Erreur upload ${docType}: ${uploadError.message}` };
  }

  console.log('[FTM-DEBUG] Document - Upload success', {
    docType,
    path: data.path,
  });

  // Générer une URL signée valable 1 an (pour affichage Admin)
  const { data: signedData, error: signError } = await supabase.storage
    .from('driver-documents')
    .createSignedUrl(filePath, 365 * 24 * 3600); // 1 an en secondes

  if (signError) {
    console.log('[FTM-DEBUG] Document - Signed URL error', { error: signError.message });
    return { error: 'Document uploadé mais URL non générée.' };
  }

  console.log('[FTM-DEBUG] Document - Signed URL created', {
    docType,
    url: signedData.signedUrl.substring(0, 60) + '...',
  });

  return { success: true, url: signedData.signedUrl, path: filePath };
}

/**
 * MISE À JOUR DE L'URL DANS LA TABLE drivers
 * Appelée après chaque upload réussi
 */
export async function saveDocumentUrl(driverId, docType, url) {
  const columnMap = {
    driver_license:       'driver_license_url',
    vehicle_registration: 'vehicle_registration_url',
    insurance:            'insurance_url',
    technical_inspection: 'technical_inspection_url',
  };

  const column = columnMap[docType];
  if (!column) {
    console.log('[FTM-DEBUG] Document - Unknown docType', { docType });
    return { error: 'Type de document inconnu.' };
  }

  console.log('[FTM-DEBUG] Document - Saving URL to drivers', { driverId, column });

  const { error } = await supabase
    .from('drivers')
    .update({ [column]: url })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Document - Save URL error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Document - URL saved successfully', { driverId, docType });
  return { success: true };
}
```

---

## 5. SERVICE ONBOARDING DRIVER

```javascript
// /services/driverService.js

import { supabase } from '../lib/supabaseClient';

/**
 * ÉTAPE 1 : Créer l'entrée driver (infos véhicule)
 * Appelée à la soumission du Step 1 du formulaire
 */
export async function createDriverProfile(profileId, vehicleData) {
  console.log('[FTM-DEBUG] Driver - Creating driver profile', {
    profileId,
    vehicleCategory: vehicleData.vehicle_category,
    licensePlate:    vehicleData.license_plate,
  });

  const { data, error } = await supabase
    .from('drivers')
    .insert({
      profile_id:          profileId,
      vehicle_category:    vehicleData.vehicle_category,    // 'vul' | 'n2_medium' | 'n2_large'
      vehicle_brand:       vehicleData.vehicle_brand,
      vehicle_model:       vehicleData.vehicle_model,
      license_plate:       vehicleData.license_plate.toUpperCase(),
      vehicle_capacity_kg: vehicleData.vehicle_capacity_kg,
      is_available:        false, // Indisponible jusqu'à vérification
    })
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Driver - Create error', { error: error.message });
    // Erreur 23505 = contrainte UNIQUE (plaque déjà enregistrée)
    if (error.code === '23505') {
      return { error: 'Cette plaque d\'immatriculation est déjà enregistrée.' };
    }
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Driver - Profile created', {
    driverId: data.id,
    category: data.vehicle_category,
  });

  // Créer le wallet immédiatement (solde 0)
  await createDriverWallet(data.id);

  return { success: true, driver: data };
}

/**
 * Créer le wallet du chauffeur dès l'onboarding
 * (La table wallet est liée à drivers, pas à profiles)
 */
async function createDriverWallet(driverId) {
  console.log('[FTM-DEBUG] Wallet - Creating wallet for driver', { driverId });

  const { error } = await supabase
    .from('wallet')
    .insert({
      driver_id:       driverId,
      balance:         0,
      minimum_balance: 100.00,
      total_earned:    0,
      total_commissions: 0,
    });

  if (error) {
    console.log('[FTM-DEBUG] Wallet - Creation error', { error: error.message });
  } else {
    console.log('[FTM-DEBUG] Wallet - Created successfully', { driverId });
  }
}

/**
 * ÉTAPE 2 : Sauvegarder les documents légaux (numéros + dates)
 */
export async function saveDriverDocuments(driverId, docsData) {
  console.log('[FTM-DEBUG] Driver - Saving legal documents', {
    driverId,
    docs: Object.keys(docsData),
  });

  const { error } = await supabase
    .from('drivers')
    .update({
      driver_license_number:       docsData.driver_license_number,
      driver_license_expiry:       docsData.driver_license_expiry,     // Format: 'YYYY-MM-DD'

      vehicle_registration_number: docsData.vehicle_registration_number,

      insurance_number:            docsData.insurance_number,
      insurance_expiry:            docsData.insurance_expiry,           // Format: 'YYYY-MM-DD'

      technical_inspection_expiry: docsData.technical_inspection_expiry, // Format: 'YYYY-MM-DD'
    })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Driver - Save documents error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Driver - Legal documents saved', { driverId });

  // Créer les rappels d'expiration dans document_reminders
  await createDocumentReminders(driverId, docsData);

  return { success: true };
}

/**
 * Créer les entrées de rappel pour chaque document avec date d'expiration
 */
async function createDocumentReminders(driverId, docsData) {
  console.log('[FTM-DEBUG] Reminders - Creating document reminders', { driverId });

  const reminders = [
    { document_type: 'driver_license',       expiry_date: docsData.driver_license_expiry },
    { document_type: 'insurance',            expiry_date: docsData.insurance_expiry },
    { document_type: 'technical_inspection', expiry_date: docsData.technical_inspection_expiry },
  ].filter(r => r.expiry_date); // Filtrer les dates nulles

  const rows = reminders.map(r => ({
    driver_id:              driverId,
    document_type:          r.document_type,
    expiry_date:            r.expiry_date,
    reminder_30_days_sent:  false,
    reminder_15_days_sent:  false,
    reminder_7_days_sent:   false,
  }));

  const { error } = await supabase
    .from('document_reminders')
    .upsert(rows, { onConflict: 'driver_id,document_type' });

  if (error) {
    console.log('[FTM-DEBUG] Reminders - Creation error', { error: error.message });
  } else {
    console.log('[FTM-DEBUG] Reminders - Created', { count: rows.length, driverId });
  }
}

/**
 * Récupérer le profil complet driver (avec statuts de vérification)
 */
export async function getDriverProfile(profileId) {
  console.log('[FTM-DEBUG] Driver - Fetching driver profile', { profileId });

  const { data, error } = await supabase
    .from('drivers')
    .select(`
      id,
      profile_id,
      vehicle_category,
      vehicle_brand,
      vehicle_model,
      license_plate,
      vehicle_capacity_kg,
      driver_license_number,
      driver_license_expiry,
      driver_license_verified,
      driver_license_url,
      vehicle_registration_number,
      vehicle_registration_verified,
      vehicle_registration_url,
      insurance_number,
      insurance_expiry,
      insurance_verified,
      insurance_url,
      technical_inspection_expiry,
      technical_inspection_verified,
      technical_inspection_url,
      is_verified,
      is_available,
      total_missions,
      rating_average
    `)
    .eq('profile_id', profileId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Driver - Fetch error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Driver - Profile fetched', {
    driverId:   data.id,
    isVerified: data.is_verified,
    verificationStatus: {
      license:      data.driver_license_verified,
      registration: data.vehicle_registration_verified,
      insurance:    data.insurance_verified,
      inspection:   data.technical_inspection_verified,
    },
  });

  return { success: true, driver: data };
}
```

---

## 6. ÉCRANS D'ONBOARDING DRIVER (4 STEPS)

### 6.1 Step 1 — Informations Véhicule

```javascript
// /screens/driver/onboarding/VehicleInfoScreen.js

/**
 * ÉTAT LOCAL
 * - vehicleCategory : 'vul' | 'n2_medium' | 'n2_large' | null
 * - vehicleBrand    : string
 * - vehicleModel    : string
 * - licensePlate    : string
 * - capacityKg      : string (converti en integer)
 * - isLoading       : boolean
 */

/**
 * UI — VehicleInfoScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────┐
 * │  ← Étape 1 sur 4                │
 * │  [ProgressBar 25% — primary]    │
 * │                                  │
 * │  "Votre véhicule"               │
 * │                                  │
 * │  CATÉGORIE (sélection obligatoire)│
 * │  ┌──────────┐┌──────────┐┌────┐ │
 * │  │ 🚐 VUL  ││ 🚛 N2   ││🚚 N2│ │
 * │  │≤3.5T    ││3.5-7.5T  ││7.5T│ │
 * │  │ 25 DH   ││ 40 DH   ││50DH│ │
 * │  └──────────┘└──────────┘└────┘ │
 * │  (Card sélectionnée = bordure    │
 * │   COLORS.primary + fond léger)  │
 * │                                  │
 * │  [Input] Marque (ex: Mercedes)  │
 * │  [Input] Modèle (ex: Sprinter)  │
 * │  [Input] Plaque (ex: 12345-A-1) │
 * │  [Input] Capacité max (kg)      │
 * │                                  │
 * │  [Bouton "Suivant →"]           │
 * │  (COLORS.primary, désactivé     │
 * │   si catégorie ou plaque vides) │
 * └──────────────────────────────────┘
 *
 * GRILLE TARIFAIRE AFFICHÉE :
 * - VUL (≤ 3,5T)        → Commission : 25 DH
 * - N2 Medium (3.5-7.5T) → Commission : 40 DH
 * - N2 Large (7.5-12T)   → Commission : 50 DH
 *
 * COMPORTEMENT :
 * - Plaque : uppercase automatique, regex validation /^[0-9]{1,6}-[A-Z]-[0-9]+$/
 * - Capacité : clavier numérique
 * - Au "Suivant" : appel createDriverProfile() → navigation Step 2
 */

const VEHICLE_CATEGORIES = [
  {
    value:       'vul',
    label_fr:    'VUL',
    label_ar:    'مركبة خفيفة',
    description: '≤ 3,5 tonnes',
    commission:  '25 DH',
    icon:        '🚐',
  },
  {
    value:       'n2_medium',
    label_fr:    'N2 Moyen',
    label_ar:    'شاحنة متوسطة',
    description: '3,5 – 7,5 tonnes',
    commission:  '40 DH',
    icon:        '🚛',
  },
  {
    value:       'n2_large',
    label_fr:    'N2 Grand',
    label_ar:    'شاحنة كبيرة',
    description: '7,5 – 12 tonnes',
    commission:  '50 DH',
    icon:        '🚚',
  },
];
```

### 6.2 Step 2 — Documents Légaux (Numéros & Dates)

```javascript
// /screens/driver/onboarding/LegalDocumentsScreen.js

/**
 * ÉTAT LOCAL
 * - driverLicenseNumber   : string
 * - driverLicenseExpiry   : Date
 * - registrationNumber    : string
 * - insuranceNumber       : string
 * - insuranceExpiry       : Date
 * - technicalExpiry       : Date
 * - isLoading             : boolean
 */

/**
 * HELPER : Convertir Date en string 'YYYY-MM-DD' pour Supabase
 */
function formatDateForSQL(date) {
  if (!date) return null;
  return date.toISOString().split('T')[0];
}

/**
 * VALIDATION : Vérifier que les dates ne sont pas déjà expirées
 */
function validateExpiryDate(date, documentLabel) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  if (date < today) {
    console.log('[FTM-DEBUG] Document - Expired date detected', {
      documentLabel,
      expiry: date.toISOString(),
    });
    return `${documentLabel} est déjà expiré(e). Renouvelez-le avant de vous inscrire.`;
  }
  return null;
}

/**
 * UI — LegalDocumentsScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────┐
 * │  ← Étape 2 sur 4                │
 * │  [ProgressBar 50% — primary]    │
 * │                                  │
 * │  "Documents légaux"             │
 * │                                  │
 * │  🪪 PERMIS DE CONDUIRE          │
 * │  [Input] Numéro de permis       │
 * │  [DatePicker] Date d'expiration │
 * │                                  │
 * │  📄 CARTE GRISE                 │
 * │  [Input] Numéro d'immatriculation│
 * │  (pas de date — liée au véhicule)│
 * │                                  │
 * │  🛡️ ASSURANCE                   │
 * │  [Input] Numéro de police       │
 * │  [DatePicker] Date d'expiration │
 * │                                  │
 * │  🔧 VISITE TECHNIQUE            │
 * │  [DatePicker] Date d'expiration │
 * │                                  │
 * │  [Bouton "Suivant →"]           │
 * └──────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - DatePicker natif Natively (format DD/MM/YYYY affiché, YYYY-MM-DD envoyé)
 * - Validation anti-date-passée sur chaque champ date
 * - Champ expiré → bordure COLORS.alert + message d'erreur
 * - Au "Suivant" : appel saveDriverDocuments() → navigation Step 3
 */
```

### 6.3 Step 3 — Upload des Fichiers Documents

```javascript
// /screens/driver/onboarding/DocumentUploadScreen.js

import { uploadDocument, saveDocumentUrl } from '../../../services/documentService';

/**
 * ÉTAT LOCAL
 * - uploadStatus : {
 *     driver_license:       { status: 'idle'|'uploading'|'done'|'error', url: null }
 *     vehicle_registration: { status: 'idle'|'uploading'|'done'|'error', url: null }
 *     insurance:            { status: 'idle'|'uploading'|'done'|'error', url: null }
 *     technical_inspection: { status: 'idle'|'uploading'|'done'|'error', url: null }
 *   }
 * - isLoading : boolean
 */

const INITIAL_UPLOAD_STATUS = {
  driver_license:       { status: 'idle', url: null },
  vehicle_registration: { status: 'idle', url: null },
  insurance:            { status: 'idle', url: null },
  technical_inspection: { status: 'idle', url: null },
};

/**
 * FUNCTION : Sélectionner et uploader un document
 * Utilise le picker natif Natively (caméra ou galerie ou fichier)
 */
async function handleDocumentPick(driverId, docType, setUploadStatus) {
  console.log('[FTM-DEBUG] Document - Pick initiated', { driverId, docType });

  // Natively Native Picker — image ou PDF
  // Options : { mediaType: 'mixed', allowPDF: true }
  const pickerResult = await NativelyFilePicker.pick({
    mediaType: 'mixed',
    allowedTypes: ['image/jpeg', 'image/png', 'application/pdf'],
  });

  if (!pickerResult || pickerResult.cancelled) {
    console.log('[FTM-DEBUG] Document - Pick cancelled', { docType });
    return;
  }

  console.log('[FTM-DEBUG] Document - File picked', {
    docType,
    fileName: pickerResult.name,
    mimeType: pickerResult.type,
    size:     pickerResult.size,
  });

  // Passer en état "uploading"
  setUploadStatus(prev => ({
    ...prev,
    [docType]: { status: 'uploading', url: null },
  }));

  // Upload vers Supabase Storage
  const result = await uploadDocument(
    driverId,
    docType,
    pickerResult.file,
    pickerResult.type
  );

  if (result.error) {
    console.log('[FTM-DEBUG] Document - Upload failed', { docType, error: result.error });
    setUploadStatus(prev => ({
      ...prev,
      [docType]: { status: 'error', url: null },
    }));
    return;
  }

  // Sauvegarder l'URL dans la table drivers
  await saveDocumentUrl(driverId, docType, result.url);

  setUploadStatus(prev => ({
    ...prev,
    [docType]: { status: 'done', url: result.url },
  }));

  console.log('[FTM-DEBUG] Document - Upload complete', { docType, url: result.url });
}

/**
 * FUNCTION : Vérifier si tous les documents sont uploadés
 */
function allDocumentsUploaded(uploadStatus) {
  return Object.values(uploadStatus).every(doc => doc.status === 'done');
}

/**
 * UI — DocumentUploadScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────┐
 * │  ← Étape 3 sur 4                │
 * │  [ProgressBar 75% — primary]    │
 * │                                  │
 * │  "Uploadez vos documents"       │
 * │  "Format : Photo ou PDF (5MB)"  │
 * │                                  │
 * │  ┌────────────────────────────┐  │
 * │  │ 🪪 Permis de conduire      │  │
 * │  │ [📷 Prendre photo]         │  │
 * │  │ [📁 Choisir fichier]       │  │
 * │  │ Statut: ✅ Uploadé         │  │  ← COLORS.success si done
 * │  └────────────────────────────┘  │
 * │  (Répété pour les 4 documents)  │
 * │                                  │
 * │  [Bouton "Soumettre ma demande"] │
 * │  (COLORS.primary, désactivé     │
 * │   tant que 4/4 non uploadés)    │
 * └──────────────────────────────────┘
 *
 * STATUTS VISUELS PAR DOCUMENT :
 * - 'idle'      → Fond COLORS.background, icône upload grise
 * - 'uploading' → Spinner + "Upload en cours..."
 * - 'done'      → Coche ✅ verte (COLORS.success) + nom fichier
 * - 'error'     → Croix ❌ rouge (COLORS.alert) + "Réessayer"
 *
 * COMPORTEMENT :
 * - Bouton "Soumettre" actif seulement si allDocumentsUploaded() === true
 * - Au submit : navigation vers Step 4 (confirmation)
 */
```

### 6.4 Step 4 — Confirmation (En Attente de Vérification)

```javascript
// /screens/driver/onboarding/PendingVerificationScreen.js

/**
 * Écran final de l'onboarding.
 * Le chauffeur voit le récapitulatif et attend la validation Admin.
 *
 * DONNÉES AFFICHÉES :
 * - Récapitulatif des 4 documents avec statut 'pending'
 * - Estimation du délai de vérification (ex: "24-48h ouvrables")
 * - Indication sur le solde wallet minimum requis (100 DH)
 *
 * ABONNEMENT REALTIME :
 * Écouter les changements sur la table drivers pour notifier
 * le chauffeur dès que son statut change (pending → verified/rejected)
 */

async function subscribeToVerificationStatus(driverId, onStatusChange) {
  console.log('[FTM-DEBUG] Driver - Subscribing to verification updates', { driverId });

  const channel = supabase
    .channel(`driver-verification-${driverId}`)
    .on(
      'postgres_changes',
      {
        event:  'UPDATE',
        schema: 'public',
        table:  'drivers',
        filter: `id=eq.${driverId}`,
      },
      (payload) => {
        console.log('[FTM-DEBUG] Driver - Verification status update received', {
          driverId,
          newValues: {
            is_verified:                      payload.new.is_verified,
            driver_license_verified:          payload.new.driver_license_verified,
            vehicle_registration_verified:    payload.new.vehicle_registration_verified,
            insurance_verified:               payload.new.insurance_verified,
            technical_inspection_verified:    payload.new.technical_inspection_verified,
          },
        });
        onStatusChange(payload.new);
      }
    )
    .subscribe();

  return channel;
}

/**
 * UI — PendingVerificationScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────┐
 * │  [Étape 4 sur 4 — 100%]         │
 * │                                  │
 * │  ⏳ (Icône sablier animé)       │
 * │  "Dossier soumis avec succès !" │
 * │                                  │
 * │  STATUT DE VOS DOCUMENTS :      │
 * │  🪪 Permis       🟡 En attente  │
 * │  📄 Carte grise  🟡 En attente  │
 * │  🛡️ Assurance    🟡 En attente  │
 * │  🔧 Visite tech  🟡 En attente  │
 * │                                  │
 * │  ℹ️ "Vous serez notifié par SMS  │
 * │  dès validation de votre dossier"│
 * │                                  │
 * │  💰 "Pensez à recharger votre   │
 * │  wallet (min. 100 DH) pour      │
 * │  commencer à accepter missions" │
 * │                                  │
 * │  [Bouton "Recharger mon wallet"] │
 * │  (COLORS.cta — Jaune)           │
 * └──────────────────────────────────┘
 *
 * COMPORTEMENT REALTIME :
 * - Quand is_verified passe à true  → Afficher banner ✅ vert
 *   + naviguer vers DriverHomeStack
 * - Si un document est 'rejected'   → Afficher le motif en rouge
 *   + bouton "Re-uploader ce document"
 */
```

---

## 7. ÉCRAN PROFIL DRIVER — STATUTS DE VÉRIFICATION

```javascript
// /screens/driver/DocumentStatusScreen.js
// Accessible depuis DriverHomeStack → Mon Profil → Documents

/**
 * Affiche le statut en temps réel de chaque document
 * avec possibilité de re-soumettre en cas de rejet
 */

function getStatusConfig(status) {
  const configs = {
    pending: {
      label_fr: 'En attente',
      label_ar: 'في الانتظار',
      color:    '#F39C12', // COLORS.cta — Ambre
      icon:     '🟡',
    },
    verified: {
      label_fr: 'Vérifié',
      label_ar: 'تم التحقق',
      color:    '#28A745', // COLORS.success — Vert
      icon:     '✅',
    },
    rejected: {
      label_fr: 'Refusé',
      label_ar: 'مرفوض',
      color:    '#DC3545', // COLORS.alert — Rouge
      icon:     '❌',
    },
    expired: {
      label_fr: 'Expiré',
      label_ar: 'منتهي الصلاحية',
      color:    '#DC3545',
      icon:     '⚠️',
    },
  };
  return configs[status] || configs.pending;
}

/**
 * UI — DocumentStatusScreen
 *
 * LAYOUT (par document) :
 * ┌─────────────────────────────────────┐
 * │  🪪 Permis de conduire             │
 * │  N° : 12345AB          ✅ Vérifié  │
 * │  Expire : 15/06/2028               │
 * │  [Voir document] ← lien URL signée │
 * ├─────────────────────────────────────┤
 * │  🛡️ Assurance                      │
 * │  N° : POL-987654        ❌ Refusé  │
 * │  Motif : "Document illisible"      │
 * │  [Re-uploader]  ← COLORS.alert    │
 * └─────────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - Statut 'rejected' → afficher le motif de rejet (champ à ajouter en Admin P7)
 * - Statut 'expired'  → afficher "Renouvelez ce document pour rester actif"
 * - "Voir document"   → ouvrir URL signée dans le browser natif Natively
 * - "Re-uploader"     → relancer handleDocumentPick() pour ce docType uniquement
 */

async function reuploadDocument(driverId, docType, setUploadStatus) {
  console.log('[FTM-DEBUG] Document - Re-upload initiated', { driverId, docType });

  // Remettre le statut verified à 'pending' côté Supabase
  const verifiedColumnMap = {
    driver_license:       'driver_license_verified',
    vehicle_registration: 'vehicle_registration_verified',
    insurance:            'insurance_verified',
    technical_inspection: 'technical_inspection_verified',
  };

  const column = verifiedColumnMap[docType];
  const { error } = await supabase
    .from('drivers')
    .update({ [column]: 'pending' })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Document - Reset status error', { error: error.message });
    return;
  }

  console.log('[FTM-DEBUG] Document - Status reset to pending', { driverId, docType });

  // Relancer le flux d'upload
  await handleDocumentPick(driverId, docType, setUploadStatus);
}
```

---

## 8. RAPPELS D'EXPIRATION (document_reminders)

```javascript
// /services/reminderService.js
// Ce service est typiquement appelé par un CRON Supabase Edge Function
// Ici on documente aussi la lecture côté app

/**
 * Vérifier les rappels à envoyer (appelé par Edge Function quotidienne)
 * Logique : J-30, J-15, J-7 avant expiration
 */
export async function checkAndSendReminders() {
  console.log('[FTM-DEBUG] Reminders - Checking expiring documents', {
    timestamp: new Date().toISOString(),
  });

  const today     = new Date();
  const in30Days  = new Date(today); in30Days.setDate(today.getDate() + 30);
  const in15Days  = new Date(today); in15Days.setDate(today.getDate() + 15);
  const in7Days   = new Date(today); in7Days.setDate(today.getDate() + 7);

  // Récupérer les rappels non encore envoyés pour J-30
  const { data: reminders30, error } = await supabase
    .from('document_reminders')
    .select('*, drivers(profile_id)')
    .lte('expiry_date', in30Days.toISOString().split('T')[0])
    .gte('expiry_date', today.toISOString().split('T')[0])
    .eq('reminder_30_days_sent', false);

  if (error) {
    console.log('[FTM-DEBUG] Reminders - Fetch error', { error: error.message });
    return;
  }

  console.log('[FTM-DEBUG] Reminders - Found reminders to send', {
    count30: reminders30?.length,
  });

  // Pour chaque rappel : insérer une notification + marquer comme envoyé
  for (const reminder of (reminders30 || [])) {
    const daysLeft = Math.ceil(
      (new Date(reminder.expiry_date) - today) / (1000 * 60 * 60 * 24)
    );

    // Insérer dans notifications (P6)
    await supabase.from('notifications').insert({
      profile_id: reminder.drivers.profile_id,
      title:      `Document expirant dans ${daysLeft} jours`,
      body:       `Votre ${reminder.document_type} expire le ${reminder.expiry_date}. Renouvelez-le pour rester actif.`,
      type:       'document_expiry',
      data:       { document_type: reminder.document_type, expiry_date: reminder.expiry_date },
    });

    // Marquer le rappel comme envoyé
    await supabase
      .from('document_reminders')
      .update({ reminder_30_days_sent: true })
      .eq('id', reminder.id);

    console.log('[FTM-DEBUG] Reminders - Reminder sent', {
      reminderId:   reminder.id,
      documentType: reminder.document_type,
      daysLeft,
    });
  }
}
```

---

## 9. ARBORESCENCE DES FICHIERS — PÉRIMÈTRE P2

```
src/
├── services/
│   ├── driverService.js       ← createDriverProfile, saveDriverDocuments, getDriverProfile
│   ├── documentService.js     ← uploadDocument, saveDocumentUrl, DOCUMENT_TYPES
│   └── reminderService.js     ← checkAndSendReminders
├── screens/
│   ├── driver/
│   │   ├── onboarding/
│   │   │   ├── VehicleInfoScreen.js          ← Step 1 : Catégorie + véhicule
│   │   │   ├── LegalDocumentsScreen.js       ← Step 2 : Numéros + dates
│   │   │   ├── DocumentUploadScreen.js       ← Step 3 : Upload fichiers
│   │   │   └── PendingVerificationScreen.js  ← Step 4 : En attente Admin
│   │   └── DocumentStatusScreen.js           ← Suivi vérifications post-onboarding
```

---

## 10. RÉCAPITULATIF DES LOGS DE DEBUG (P2)

| Action | Log FTM-DEBUG |
|--------|---------------|
| Création profil driver | `[FTM-DEBUG] Driver - Creating driver profile` |
| Erreur plaque unique | `[FTM-DEBUG] Driver - Create error` |
| Création wallet | `[FTM-DEBUG] Wallet - Creating wallet for driver` |
| Sauvegarde documents légaux | `[FTM-DEBUG] Driver - Saving legal documents` |
| Date expirée détectée | `[FTM-DEBUG] Document - Expired date detected` |
| Création rappels | `[FTM-DEBUG] Reminders - Created` |
| Sélection fichier | `[FTM-DEBUG] Document - Pick initiated` |
| Upload start | `[FTM-DEBUG] Document - Upload start` |
| Upload success | `[FTM-DEBUG] Document - Upload complete` |
| Upload error | `[FTM-DEBUG] Document - Upload failed` |
| URL sauvegardée | `[FTM-DEBUG] Document - URL saved successfully` |
| Subscription realtime | `[FTM-DEBUG] Driver - Subscribing to verification updates` |
| Status update reçu | `[FTM-DEBUG] Driver - Verification status update received` |
| Re-upload initié | `[FTM-DEBUG] Document - Re-upload initiated` |
| Status reset pending | `[FTM-DEBUG] Document - Status reset to pending` |
| Rappels check | `[FTM-DEBUG] Reminders - Checking expiring documents` |
| Rappel envoyé | `[FTM-DEBUG] Reminders - Reminder sent` |

---

## 11. CHECKLIST DE VALIDATION P2

- [ ] Bucket `driver-documents` créé dans Supabase Storage (privé, 5MB max)
- [ ] Policies RLS Storage : driver upload dans son dossier uniquement
- [ ] Insertion dans `drivers` réussie avec `profile_id` correct
- [ ] `wallet` créé automatiquement à la création du driver
- [ ] Upload fichier visible dans Storage → `{driver_id}/driver_license.jpg`
- [ ] URL signée stockée dans `drivers.driver_license_url`
- [ ] Entrées créées dans `document_reminders` (3 lignes par driver)
- [ ] Realtime : changement `is_verified` reçu dans PendingVerificationScreen
- [ ] Écran DocumentStatusScreen : statuts corrects (pending/verified/rejected/expired)
- [ ] Tous les `console.log('[FTM-DEBUG]...')` visibles dans Debug Console Codespaces

---

## 12. LIAISON AVEC LES PARTIES SUIVANTES

| Partie | Dépendance de P2 |
|--------|-----------------|
| **P3** | `drivers.id` + `drivers.is_verified = true` → accepter missions + GPS tracking |
| **P5** | `wallet.driver_id` créé en P2 → opérations financières |
| **P6** | `document_reminders` → Push notifications expiration |
| **P7** | Admin consulte `drivers.*_verified` → valide/rejette via dashboard |

---

*FTM Spec P2 — Fin du fichier*
*Prochaine étape : SPEC_NATIVELY_P3.md — Missions, Géolocalisation PostGIS & Background Location*
