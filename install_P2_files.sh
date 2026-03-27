#!/bin/bash
mkdir -p frontend/src/services
mkdir -p frontend/src/screens/driver/onboarding

cat > frontend/tsconfig.json << 'ENDOFFILE'
{
  "extends": "expo/tsconfig.base",
  "compilerOptions": {
    "strict": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    },
    "moduleResolution": "bundler",
    "jsx": "react-native",
    "allowJs": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "skipLibCheck": true
  },
  "include": [
    "**/*.ts",
    "**/*.tsx",
    ".expo/types/**/*.d.ts",
    "expo-env.d.ts"
  ]
}
ENDOFFILE

cat > frontend/src/services/documentService.ts << 'ENDOFFILE'
// /services/documentService.ts
// Fast Trans Maroc — P2

import { supabase } from '../lib/supabaseClient';
import * as ImagePicker from 'expo-image-picker';
import * as DocumentPicker from 'expo-document-picker';

export const DOCUMENT_TYPES = {
  DRIVER_LICENSE:       'driver_license',
  VEHICLE_REGISTRATION: 'vehicle_registration',
  INSURANCE:            'insurance',
  TECHNICAL_INSPECTION: 'technical_inspection',
} as const;

export type DocumentType = typeof DOCUMENT_TYPES[keyof typeof DOCUMENT_TYPES];

export const DOCUMENT_LABELS: Record<
  DocumentType,
  { fr: string; ar: string; icon: string }
> = {
  driver_license: {
    fr:   'Permis de conduire',
    ar:   'رخصة السياقة',
    icon: '🪪',
  },
  vehicle_registration: {
    fr:   'Carte grise',
    ar:   'بطاقة تقنية',
    icon: '📄',
  },
  insurance: {
    fr:   'Assurance',
    ar:   'التأمين',
    icon: '🛡️',
  },
  technical_inspection: {
    fr:   'Visite technique',
    ar:   'المعاينة التقنية',
    icon: '🔧',
  },
};

export interface UploadResult {
  success?: boolean;
  url?: string;
  path?: string;
  error?: string;
}

/**
 * Upload a document file to Supabase Storage.
 */
export async function uploadDocument(
  driverId: string,
  docType: DocumentType,
  fileUri: string,
  mimeType: string
): Promise<UploadResult> {
  console.log('[FTM-DEBUG] Document - Upload start', { driverId, docType, mimeType });

  // Fetch the file as a blob
  const response = await fetch(fileUri);
  const blob = await response.blob();

  if (blob.size > 5 * 1024 * 1024) {
    console.log('[FTM-DEBUG] Document - File too large', { size: blob.size });
    return { error: 'Fichier trop volumineux (max 5 MB).' };
  }

  const extension = mimeType === 'application/pdf' ? 'pdf' : 'jpg';
  const filePath  = `${driverId}/${docType}.${extension}`;

  const { data, error: uploadError } = await supabase.storage
    .from('driver-documents')
    .upload(filePath, blob, { contentType: mimeType, upsert: true });

  if (uploadError) {
    console.log('[FTM-DEBUG] Document - Upload error', { docType, error: uploadError.message });
    return { error: `Erreur upload ${docType}: ${uploadError.message}` };
  }

  console.log('[FTM-DEBUG] Document - Upload success', { docType, path: data.path });

  const { data: signedData, error: signError } = await supabase.storage
    .from('driver-documents')
    .createSignedUrl(filePath, 365 * 24 * 3600);

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
 * Save the signed URL into the drivers table.
 */
export async function saveDocumentUrl(
  driverId: string,
  docType: DocumentType,
  url: string
): Promise<{ success?: boolean; error?: string }> {
  const columnMap: Record<DocumentType, string> = {
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
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Document - URL saved successfully', { driverId, docType });
  return { success: true };
}

/**
 * Launch the native picker (camera/gallery/file) and return uri + mimeType.
 * Uses expo-image-picker for images and expo-document-picker for PDFs.
 */
export async function pickDocument(): Promise<{
  uri: string;
  mimeType: string;
  name: string;
} | null> {
  // Ask user via DocumentPicker (supports images + PDF)
  const result = await DocumentPicker.getDocumentAsync({
    type: ['image/jpeg', 'image/png', 'application/pdf'],
    copyToCacheDirectory: true,
  });

  if (result.canceled || !result.assets || result.assets.length === 0) {
    return null;
  }

  const asset = result.assets[0];
  return {
    uri:      asset.uri,
    mimeType: asset.mimeType ?? 'image/jpeg',
    name:     asset.name ?? 'document',
  };
}

/**
 * Launch camera picker via expo-image-picker.
 */
export async function pickImageFromCamera(): Promise<{
  uri: string;
  mimeType: string;
  name: string;
} | null> {
  const permission = await ImagePicker.requestCameraPermissionsAsync();
  if (!permission.granted) return null;

  const result = await ImagePicker.launchCameraAsync({
    mediaTypes: ImagePicker.MediaTypeOptions.Images,
    quality: 0.85,
    allowsEditing: false,
  });

  if (result.canceled || !result.assets || result.assets.length === 0) return null;

  const asset = result.assets[0];
  return {
    uri:      asset.uri,
    mimeType: 'image/jpeg',
    name:     'photo.jpg',
  };
}
ENDOFFILE

cat > frontend/src/services/driverService.ts << 'ENDOFFILE'
// /services/driverService.ts
// Fast Trans Maroc — P2

import { supabase } from '../lib/supabaseClient';

export type VehicleCategory = 'vul' | 'n2_medium' | 'n2_large';

export interface VehicleData {
  vehicle_category:    VehicleCategory;
  vehicle_brand:       string;
  vehicle_model:       string;
  license_plate:       string;
  vehicle_capacity_kg: number;
}

export interface LegalDocsData {
  driver_license_number:       string;
  driver_license_expiry:       string; // 'YYYY-MM-DD'
  vehicle_registration_number: string;
  insurance_number:            string;
  insurance_expiry:            string; // 'YYYY-MM-DD'
  technical_inspection_expiry: string; // 'YYYY-MM-DD'
}

/**
 * STEP 1 — Create driver row + wallet
 */
export async function createDriverProfile(
  profileId: string,
  vehicleData: VehicleData
): Promise<{ success?: boolean; driver?: Record<string, unknown>; error?: string }> {
  console.log('[FTM-DEBUG] Driver - Creating driver profile', {
    profileId,
    vehicleCategory: vehicleData.vehicle_category,
    licensePlate:    vehicleData.license_plate,
  });

  const { data, error } = await supabase
    .from('drivers')
    .insert({
      profile_id:          profileId,
      vehicle_category:    vehicleData.vehicle_category,
      vehicle_brand:       vehicleData.vehicle_brand,
      vehicle_model:       vehicleData.vehicle_model,
      license_plate:       vehicleData.license_plate.toUpperCase(),
      vehicle_capacity_kg: vehicleData.vehicle_capacity_kg,
      is_available:        false,
    })
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Driver - Create error', { error: error.message });
    if (error.code === '23505') {
      return { error: "Cette plaque d'immatriculation est déjà enregistrée." };
    }
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Driver - Profile created', {
    driverId: data.id,
    category: data.vehicle_category,
  });

  await createDriverWallet(data.id as string);

  return { success: true, driver: data as Record<string, unknown> };
}

async function createDriverWallet(driverId: string): Promise<void> {
  console.log('[FTM-DEBUG] Wallet - Creating wallet for driver', { driverId });

  const { error } = await supabase.from('wallet').insert({
    driver_id:         driverId,
    balance:           0,
    minimum_balance:   100.00,
    total_earned:      0,
    total_commissions: 0,
  });

  if (error) {
    console.log('[FTM-DEBUG] Wallet - Creation error', { error: error.message });
  } else {
    console.log('[FTM-DEBUG] Wallet - Created successfully', { driverId });
  }
}

/**
 * STEP 2 — Save legal document numbers & expiry dates
 */
export async function saveDriverDocuments(
  driverId: string,
  docsData: LegalDocsData
): Promise<{ success?: boolean; error?: string }> {
  console.log('[FTM-DEBUG] Driver - Saving legal documents', {
    driverId,
    docs: Object.keys(docsData),
  });

  const { error } = await supabase
    .from('drivers')
    .update({
      driver_license_number:       docsData.driver_license_number,
      driver_license_expiry:       docsData.driver_license_expiry,
      vehicle_registration_number: docsData.vehicle_registration_number,
      insurance_number:            docsData.insurance_number,
      insurance_expiry:            docsData.insurance_expiry,
      technical_inspection_expiry: docsData.technical_inspection_expiry,
    })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Driver - Save documents error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Driver - Legal documents saved', { driverId });
  await createDocumentReminders(driverId, docsData);
  return { success: true };
}

async function createDocumentReminders(
  driverId: string,
  docsData: LegalDocsData
): Promise<void> {
  console.log('[FTM-DEBUG] Reminders - Creating document reminders', { driverId });

  const candidates = [
    { document_type: 'driver_license',       expiry_date: docsData.driver_license_expiry },
    { document_type: 'insurance',            expiry_date: docsData.insurance_expiry },
    { document_type: 'technical_inspection', expiry_date: docsData.technical_inspection_expiry },
  ].filter(r => Boolean(r.expiry_date));

  const rows = candidates.map(r => ({
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
 * Fetch full driver profile by profile_id
 */
export async function getDriverProfile(
  profileId: string
): Promise<{ success?: boolean; driver?: Record<string, unknown>; error?: unknown }> {
  console.log('[FTM-DEBUG] Driver - Fetching driver profile', { profileId });

  const { data, error } = await supabase
    .from('drivers')
    .select(`
      id, profile_id, vehicle_category, vehicle_brand, vehicle_model,
      license_plate, vehicle_capacity_kg,
      driver_license_number, driver_license_expiry, driver_license_verified, driver_license_url,
      vehicle_registration_number, vehicle_registration_verified, vehicle_registration_url,
      insurance_number, insurance_expiry, insurance_verified, insurance_url,
      technical_inspection_expiry, technical_inspection_verified, technical_inspection_url,
      is_verified, is_available, total_missions, rating_average
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
  });

  return { success: true, driver: data as Record<string, unknown> };
}

/**
 * Reset a single document verification status to 'pending' (for re-upload)
 */
export async function resetDocumentStatus(
  driverId: string,
  docType: string
): Promise<{ success?: boolean; error?: string }> {
  const verifiedColumnMap: Record<string, string> = {
    driver_license:       'driver_license_verified',
    vehicle_registration: 'vehicle_registration_verified',
    insurance:            'insurance_verified',
    technical_inspection: 'technical_inspection_verified',
  };

  const column = verifiedColumnMap[docType];
  if (!column) return { error: 'Type de document inconnu.' };

  const { error } = await supabase
    .from('drivers')
    .update({ [column]: 'pending' })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Document - Reset status error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Document - Status reset to pending', { driverId, docType });
  return { success: true };
}
ENDOFFILE

cat > frontend/src/services/reminderService.ts << 'ENDOFFILE'
// /services/reminderService.ts
// Fast Trans Maroc — P2
// Typically called by a Supabase Edge Function (daily CRON)

import { supabase } from '../lib/supabaseClient';

export async function checkAndSendReminders(): Promise<void> {
  console.log('[FTM-DEBUG] Reminders - Checking expiring documents', {
    timestamp: new Date().toISOString(),
  });

  const today    = new Date();
  const in30Days = new Date(today);
  in30Days.setDate(today.getDate() + 30);

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
    count30: reminders30?.length ?? 0,
  });

  for (const reminder of reminders30 ?? []) {
    const daysLeft = Math.ceil(
      (new Date(reminder.expiry_date as string).getTime() - today.getTime()) /
        (1000 * 60 * 60 * 24)
    );

    await supabase.from('notifications').insert({
      profile_id: (reminder.drivers as { profile_id: string }).profile_id,
      title:      `Document expirant dans ${daysLeft} jours`,
      body:       `Votre ${reminder.document_type} expire le ${reminder.expiry_date}. Renouvelez-le pour rester actif.`,
      type:       'document_expiry',
      data:       { document_type: reminder.document_type, expiry_date: reminder.expiry_date },
    });

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
ENDOFFILE

cat > frontend/src/screens/driver/onboarding/VehicleInfoScreen.tsx << 'ENDOFFILE'
// /screens/driver/onboarding/VehicleInfoScreen.tsx
// Fast Trans Maroc — P2 — Step 1

import React, { useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity,
  ScrollView, StyleSheet, ActivityIndicator, Alert,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { createDriverProfile, VehicleCategory } from '../../../services/driverService';
import { supabase } from '../../../lib/supabaseClient';
import { COLORS } from '../../../constants/theme';

type Props = {
  navigation: NativeStackNavigationProp<any>;
};

const VEHICLE_CATEGORIES = [
  {
    value:       'vul' as VehicleCategory,
    label_fr:    'VUL',
    description: '≤ 3,5 tonnes',
    commission:  '25 DH',
    icon:        '🚐',
  },
  {
    value:       'n2_medium' as VehicleCategory,
    label_fr:    'N2 Moyen',
    description: '3,5 – 7,5 tonnes',
    commission:  '40 DH',
    icon:        '🚛',
  },
  {
    value:       'n2_large' as VehicleCategory,
    label_fr:    'N2 Grand',
    description: '7,5 – 12 tonnes',
    commission:  '50 DH',
    icon:        '🚚',
  },
];

const LICENSE_PLATE_REGEX = /^[0-9]{1,6}-[A-Z]-[0-9]+$/;

export default function VehicleInfoScreen({ navigation }: Props) {
  const [vehicleCategory, setVehicleCategory] = useState<VehicleCategory | null>(null);
  const [vehicleBrand,    setVehicleBrand]    = useState('');
  const [vehicleModel,    setVehicleModel]    = useState('');
  const [licensePlate,    setLicensePlate]    = useState('');
  const [capacityKg,      setCapacityKg]      = useState('');
  const [isLoading,       setIsLoading]       = useState(false);

  const isFormValid =
    vehicleCategory !== null &&
    licensePlate.trim().length > 0 &&
    LICENSE_PLATE_REGEX.test(licensePlate.trim().toUpperCase());

  async function handleNext() {
    if (!isFormValid) return;
    setIsLoading(true);

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { setIsLoading(false); return; }

    const { data: profile } = await supabase
      .from('profiles')
      .select('id')
      .eq('user_id', user.id)
      .single();

    if (!profile) { setIsLoading(false); return; }

    const result = await createDriverProfile(profile.id as string, {
      vehicle_category:    vehicleCategory!,
      vehicle_brand:       vehicleBrand.trim(),
      vehicle_model:       vehicleModel.trim(),
      license_plate:       licensePlate.trim().toUpperCase(),
      vehicle_capacity_kg: capacityKg ? parseInt(capacityKg, 10) : 0,
    });

    setIsLoading(false);

    if (result.error) {
      Alert.alert('Erreur', result.error);
      return;
    }

    navigation.navigate('LegalDocuments', { driverId: (result.driver as any).id });
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.step}>Étape 1 sur 4</Text>
      <View style={styles.progressBar}>
        <View style={[styles.progressFill, { width: '25%' }]} />
      </View>

      <Text style={styles.title}>Votre véhicule</Text>

      {/* Category selector */}
      <View style={styles.categoryRow}>
        {VEHICLE_CATEGORIES.map(cat => (
          <TouchableOpacity
            key={cat.value}
            style={[
              styles.categoryCard,
              vehicleCategory === cat.value && styles.categoryCardSelected,
            ]}
            onPress={() => setVehicleCategory(cat.value)}
          >
            <Text style={styles.categoryIcon}>{cat.icon}</Text>
            <Text style={styles.categoryLabel}>{cat.label_fr}</Text>
            <Text style={styles.categoryDesc}>{cat.description}</Text>
            <Text style={styles.categoryCommission}>{cat.commission}</Text>
          </TouchableOpacity>
        ))}
      </View>

      <TextInput
        style={styles.input}
        placeholder="Marque (ex: Mercedes)"
        value={vehicleBrand}
        onChangeText={setVehicleBrand}
      />
      <TextInput
        style={styles.input}
        placeholder="Modèle (ex: Sprinter)"
        value={vehicleModel}
        onChangeText={setVehicleModel}
      />
      <TextInput
        style={styles.input}
        placeholder="Plaque (ex: 12345-A-1)"
        value={licensePlate}
        onChangeText={t => setLicensePlate(t.toUpperCase())}
        autoCapitalize="characters"
      />
      <TextInput
        style={styles.input}
        placeholder="Capacité max (kg)"
        value={capacityKg}
        onChangeText={setCapacityKg}
        keyboardType="numeric"
      />

      <TouchableOpacity
        style={[styles.button, !isFormValid && styles.buttonDisabled]}
        onPress={handleNext}
        disabled={!isFormValid || isLoading}
      >
        {isLoading
          ? <ActivityIndicator color="#fff" />
          : <Text style={styles.buttonText}>Suivant →</Text>
        }
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container:          { padding: 20, paddingBottom: 40 },
  step:               { color: '#888', fontSize: 13, marginBottom: 6 },
  progressBar:        { height: 6, backgroundColor: '#E0E0E0', borderRadius: 3, marginBottom: 24 },
  progressFill:       { height: '100%', backgroundColor: COLORS.primary, borderRadius: 3 },
  title:              { fontSize: 22, fontWeight: '700', marginBottom: 20, color: '#1A1A2E' },
  categoryRow:        { flexDirection: 'row', gap: 10, marginBottom: 20 },
  categoryCard:       {
    flex: 1, borderWidth: 1.5, borderColor: '#DDD', borderRadius: 12,
    padding: 10, alignItems: 'center',
  },
  categoryCardSelected: { borderColor: COLORS.primary, backgroundColor: '#F0F4FF' },
  categoryIcon:       { fontSize: 24 },
  categoryLabel:      { fontWeight: '700', fontSize: 13, marginTop: 4, color: '#1A1A2E' },
  categoryDesc:       { fontSize: 10, color: '#666', textAlign: 'center' },
  categoryCommission: { fontSize: 11, color: COLORS.primary, fontWeight: '600', marginTop: 2 },
  input:              {
    borderWidth: 1, borderColor: '#DDD', borderRadius: 10,
    padding: 14, marginBottom: 14, fontSize: 15, backgroundColor: '#FAFAFA',
  },
  button:             {
    backgroundColor: COLORS.primary, borderRadius: 12,
    padding: 16, alignItems: 'center', marginTop: 8,
  },
  buttonDisabled:     { backgroundColor: '#B0BEC5' },
  buttonText:         { color: '#fff', fontWeight: '700', fontSize: 16 },
});
ENDOFFILE

cat > frontend/src/screens/driver/onboarding/LegalDocumentsScreen.tsx << 'ENDOFFILE'
// /screens/driver/onboarding/LegalDocumentsScreen.tsx
// Fast Trans Maroc — P2 — Step 2

import React, { useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity,
  ScrollView, StyleSheet, ActivityIndicator, Alert, Platform,
} from 'react-native';
import DateTimePicker from '@react-native-community/datetimepicker';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { saveDriverDocuments } from '../../../services/driverService';
import { COLORS } from '../../../constants/theme';

type Props = {
  navigation: NativeStackNavigationProp<any>;
  route:      RouteProp<{ LegalDocuments: { driverId: string } }, 'LegalDocuments'>;
};

function formatDateForSQL(date: Date | null): string | null {
  if (!date) return null;
  return date.toISOString().split('T')[0];
}

function validateExpiryDate(date: Date | null, label: string): string | null {
  if (!date) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  if (date < today) {
    console.log('[FTM-DEBUG] Document - Expired date detected', {
      documentLabel: label, expiry: date.toISOString(),
    });
    return `${label} est déjà expiré(e). Renouvelez-le avant de vous inscrire.`;
  }
  return null;
}

interface DateFieldProps {
  label: string;
  value: Date | null;
  onChange: (d: Date) => void;
  error?: string | null;
}

function DateField({ label, value, onChange, error }: DateFieldProps) {
  const [show, setShow] = useState(false);

  return (
    <View style={{ marginBottom: 14 }}>
      <Text style={dfStyles.label}>{label}</Text>
      <TouchableOpacity
        style={[dfStyles.picker, error ? dfStyles.pickerError : null]}
        onPress={() => setShow(true)}
      >
        <Text style={{ color: value ? '#1A1A2E' : '#999', fontSize: 15 }}>
          {value ? value.toLocaleDateString('fr-FR') : 'Sélectionner une date'}
        </Text>
      </TouchableOpacity>
      {show && (
        <DateTimePicker
          value={value ?? new Date()}
          mode="date"
          display={Platform.OS === 'ios' ? 'spinner' : 'default'}
          minimumDate={new Date()}
          onChange={(_e, d) => { setShow(false); if (d) onChange(d); }}
        />
      )}
      {error ? <Text style={dfStyles.errorText}>{error}</Text> : null}
    </View>
  );
}

const dfStyles = StyleSheet.create({
  label:       { fontSize: 13, color: '#666', marginBottom: 4 },
  picker:      {
    borderWidth: 1, borderColor: '#DDD', borderRadius: 10,
    padding: 14, backgroundColor: '#FAFAFA',
  },
  pickerError: { borderColor: '#DC3545' },
  errorText:   { color: '#DC3545', fontSize: 12, marginTop: 4 },
});

export default function LegalDocumentsScreen({ navigation, route }: Props) {
  const { driverId } = route.params;

  const [licenseNumber,   setLicenseNumber]   = useState('');
  const [licenseExpiry,   setLicenseExpiry]   = useState<Date | null>(null);
  const [regNumber,       setRegNumber]       = useState('');
  const [insuranceNumber, setInsuranceNumber] = useState('');
  const [insuranceExpiry, setInsuranceExpiry] = useState<Date | null>(null);
  const [techExpiry,      setTechExpiry]      = useState<Date | null>(null);
  const [isLoading,       setIsLoading]       = useState(false);

  const licenseExpiryError   = validateExpiryDate(licenseExpiry,   'Le permis de conduire');
  const insuranceExpiryError = validateExpiryDate(insuranceExpiry, "L'assurance");
  const techExpiryError      = validateExpiryDate(techExpiry,      'La visite technique');

  const hasErrors = Boolean(licenseExpiryError || insuranceExpiryError || techExpiryError);
  const isFormValid =
    licenseNumber.trim() && licenseExpiry &&
    regNumber.trim() &&
    insuranceNumber.trim() && insuranceExpiry &&
    techExpiry && !hasErrors;

  async function handleNext() {
    if (!isFormValid) return;
    setIsLoading(true);

    const result = await saveDriverDocuments(driverId, {
      driver_license_number:       licenseNumber.trim(),
      driver_license_expiry:       formatDateForSQL(licenseExpiry)!,
      vehicle_registration_number: regNumber.trim(),
      insurance_number:            insuranceNumber.trim(),
      insurance_expiry:            formatDateForSQL(insuranceExpiry)!,
      technical_inspection_expiry: formatDateForSQL(techExpiry)!,
    });

    setIsLoading(false);

    if (result.error) {
      Alert.alert('Erreur', result.error);
      return;
    }

    navigation.navigate('DocumentUpload', { driverId });
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.step}>Étape 2 sur 4</Text>
      <View style={styles.progressBar}>
        <View style={[styles.progressFill, { width: '50%' }]} />
      </View>

      <Text style={styles.title}>Documents légaux</Text>

      <Text style={styles.sectionTitle}>🪪 Permis de conduire</Text>
      <TextInput
        style={styles.input}
        placeholder="Numéro de permis"
        value={licenseNumber}
        onChangeText={setLicenseNumber}
      />
      <DateField
        label="Date d'expiration"
        value={licenseExpiry}
        onChange={setLicenseExpiry}
        error={licenseExpiryError}
      />

      <Text style={styles.sectionTitle}>📄 Carte grise</Text>
      <TextInput
        style={styles.input}
        placeholder="Numéro d'immatriculation"
        value={regNumber}
        onChangeText={setRegNumber}
      />

      <Text style={styles.sectionTitle}>🛡️ Assurance</Text>
      <TextInput
        style={styles.input}
        placeholder="Numéro de police"
        value={insuranceNumber}
        onChangeText={setInsuranceNumber}
      />
      <DateField
        label="Date d'expiration"
        value={insuranceExpiry}
        onChange={setInsuranceExpiry}
        error={insuranceExpiryError}
      />

      <Text style={styles.sectionTitle}>🔧 Visite technique</Text>
      <DateField
        label="Date d'expiration"
        value={techExpiry}
        onChange={setTechExpiry}
        error={techExpiryError}
      />

      <TouchableOpacity
        style={[styles.button, !isFormValid && styles.buttonDisabled]}
        onPress={handleNext}
        disabled={!isFormValid || isLoading}
      >
        {isLoading
          ? <ActivityIndicator color="#fff" />
          : <Text style={styles.buttonText}>Suivant →</Text>
        }
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container:     { padding: 20, paddingBottom: 40 },
  step:          { color: '#888', fontSize: 13, marginBottom: 6 },
  progressBar:   { height: 6, backgroundColor: '#E0E0E0', borderRadius: 3, marginBottom: 24 },
  progressFill:  { height: '100%', backgroundColor: COLORS.primary, borderRadius: 3 },
  title:         { fontSize: 22, fontWeight: '700', marginBottom: 20, color: '#1A1A2E' },
  sectionTitle:  { fontSize: 15, fontWeight: '700', color: '#1A1A2E', marginBottom: 10, marginTop: 6 },
  input:         {
    borderWidth: 1, borderColor: '#DDD', borderRadius: 10,
    padding: 14, marginBottom: 14, fontSize: 15, backgroundColor: '#FAFAFA',
  },
  button:        {
    backgroundColor: COLORS.primary, borderRadius: 12,
    padding: 16, alignItems: 'center', marginTop: 8,
  },
  buttonDisabled: { backgroundColor: '#B0BEC5' },
  buttonText:    { color: '#fff', fontWeight: '700', fontSize: 16 },
});
ENDOFFILE

cat > frontend/src/screens/driver/onboarding/DocumentUploadScreen.tsx << 'ENDOFFILE'
// /screens/driver/onboarding/DocumentUploadScreen.tsx
// Fast Trans Maroc — P2 — Step 3

import React, { useState } from 'react';
import {
  View, Text, TouchableOpacity, ScrollView,
  StyleSheet, ActivityIndicator, Alert,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import {
  DOCUMENT_TYPES, DOCUMENT_LABELS, DocumentType,
  uploadDocument, saveDocumentUrl,
  pickDocument, pickImageFromCamera,
} from '../../../services/documentService';
import { COLORS } from '../../../constants/theme';

type UploadStatusValue = { status: 'idle' | 'uploading' | 'done' | 'error'; url: string | null };
type UploadStatusMap   = Record<DocumentType, UploadStatusValue>;

const INITIAL_UPLOAD_STATUS: UploadStatusMap = {
  driver_license:       { status: 'idle', url: null },
  vehicle_registration: { status: 'idle', url: null },
  insurance:            { status: 'idle', url: null },
  technical_inspection: { status: 'idle', url: null },
};

type Props = {
  navigation: NativeStackNavigationProp<any>;
  route:      RouteProp<{ DocumentUpload: { driverId: string } }, 'DocumentUpload'>;
};

function allDocumentsUploaded(status: UploadStatusMap): boolean {
  return Object.values(status).every(d => d.status === 'done');
}

export default function DocumentUploadScreen({ navigation, route }: Props) {
  const { driverId } = route.params;
  const [uploadStatus, setUploadStatus] = useState<UploadStatusMap>(INITIAL_UPLOAD_STATUS);

  async function handlePick(docType: DocumentType, fromCamera: boolean) {
    console.log('[FTM-DEBUG] Document - Pick initiated', { driverId, docType });

    const picked = fromCamera ? await pickImageFromCamera() : await pickDocument();
    if (!picked) {
      console.log('[FTM-DEBUG] Document - Pick cancelled', { docType });
      return;
    }

    console.log('[FTM-DEBUG] Document - File picked', {
      docType, fileName: picked.name, mimeType: picked.mimeType,
    });

    setUploadStatus(prev => ({ ...prev, [docType]: { status: 'uploading', url: null } }));

    const result = await uploadDocument(driverId, docType, picked.uri, picked.mimeType);

    if (result.error) {
      console.log('[FTM-DEBUG] Document - Upload failed', { docType, error: result.error });
      setUploadStatus(prev => ({ ...prev, [docType]: { status: 'error', url: null } }));
      Alert.alert('Erreur', result.error);
      return;
    }

    await saveDocumentUrl(driverId, docType, result.url!);
    setUploadStatus(prev => ({ ...prev, [docType]: { status: 'done', url: result.url! } }));
    console.log('[FTM-DEBUG] Document - Upload complete', { docType, url: result.url });
  }

  function getStatusStyle(status: UploadStatusValue['status']) {
    switch (status) {
      case 'done':      return { color: '#28A745' };
      case 'error':     return { color: '#DC3545' };
      case 'uploading': return { color: COLORS.primary };
      default:          return { color: '#999' };
    }
  }

  function getStatusLabel(status: UploadStatusValue['status']): string {
    switch (status) {
      case 'done':      return '✅ Uploadé';
      case 'error':     return '❌ Erreur — Réessayer';
      case 'uploading': return '⏳ Upload en cours...';
      default:          return 'En attente';
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.step}>Étape 3 sur 4</Text>
      <View style={styles.progressBar}>
        <View style={[styles.progressFill, { width: '75%' }]} />
      </View>

      <Text style={styles.title}>Uploadez vos documents</Text>
      <Text style={styles.subtitle}>Format : Photo ou PDF (5 MB max)</Text>

      {(Object.keys(DOCUMENT_TYPES) as Array<keyof typeof DOCUMENT_TYPES>).map(key => {
        const docType = DOCUMENT_TYPES[key];
        const label   = DOCUMENT_LABELS[docType];
        const st      = uploadStatus[docType];

        return (
          <View key={docType} style={styles.card}>
            <Text style={styles.cardTitle}>{label.icon} {label.fr}</Text>
            <Text style={[styles.statusText, getStatusStyle(st.status)]}>
              {getStatusLabel(st.status)}
            </Text>
            {st.status === 'uploading' ? (
              <ActivityIndicator color={COLORS.primary} style={{ marginTop: 10 }} />
            ) : (
              <View style={styles.actionRow}>
                <TouchableOpacity
                  style={styles.actionBtn}
                  onPress={() => handlePick(docType, true)}
                >
                  <Text style={styles.actionBtnText}>📷 Photo</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.actionBtn}
                  onPress={() => handlePick(docType, false)}
                >
                  <Text style={styles.actionBtnText}>📁 Fichier</Text>
                </TouchableOpacity>
              </View>
            )}
          </View>
        );
      })}

      <TouchableOpacity
        style={[styles.button, !allDocumentsUploaded(uploadStatus) && styles.buttonDisabled]}
        onPress={() => navigation.navigate('PendingVerification', { driverId })}
        disabled={!allDocumentsUploaded(uploadStatus)}
      >
        <Text style={styles.buttonText}>Soumettre ma demande</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container:    { padding: 20, paddingBottom: 40 },
  step:         { color: '#888', fontSize: 13, marginBottom: 6 },
  progressBar:  { height: 6, backgroundColor: '#E0E0E0', borderRadius: 3, marginBottom: 24 },
  progressFill: { height: '100%', backgroundColor: COLORS.primary, borderRadius: 3 },
  title:        { fontSize: 22, fontWeight: '700', marginBottom: 6, color: '#1A1A2E' },
  subtitle:     { fontSize: 13, color: '#888', marginBottom: 20 },
  card:         {
    borderWidth: 1, borderColor: '#E0E0E0', borderRadius: 12,
    padding: 16, marginBottom: 14, backgroundColor: '#FAFAFA',
  },
  cardTitle:    { fontSize: 15, fontWeight: '700', color: '#1A1A2E', marginBottom: 6 },
  statusText:   { fontSize: 13, marginBottom: 8 },
  actionRow:    { flexDirection: 'row', gap: 10 },
  actionBtn:    {
    flex: 1, borderWidth: 1, borderColor: COLORS.primary, borderRadius: 8,
    padding: 10, alignItems: 'center',
  },
  actionBtnText: { color: COLORS.primary, fontWeight: '600', fontSize: 13 },
  button:        {
    backgroundColor: COLORS.primary, borderRadius: 12,
    padding: 16, alignItems: 'center', marginTop: 12,
  },
  buttonDisabled: { backgroundColor: '#B0BEC5' },
  buttonText:    { color: '#fff', fontWeight: '700', fontSize: 16 },
});
ENDOFFILE

cat > frontend/src/screens/driver/onboarding/PendingVerificationScreen.tsx << 'ENDOFFILE'
// /screens/driver/onboarding/PendingVerificationScreen.tsx
// Fast Trans Maroc — P2 — Step 4

import React, { useEffect, useState } from 'react';
import {
  View, Text, TouchableOpacity, ScrollView,
  StyleSheet, Alert,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { supabase } from '../../../lib/supabaseClient';
import { DOCUMENT_LABELS, DocumentType, DOCUMENT_TYPES } from '../../../services/documentService';
import { COLORS } from '../../../constants/theme';

type VerificationStatus = 'pending' | 'verified' | 'rejected' | 'expired';

interface DocStatus {
  status:      VerificationStatus;
  docType:     DocumentType;
}

type Props = {
  navigation: NativeStackNavigationProp<any>;
  route:      RouteProp<{ PendingVerification: { driverId: string } }, 'PendingVerification'>;
};

function statusConfig(s: VerificationStatus) {
  switch (s) {
    case 'verified': return { label: 'Vérifié',    color: '#28A745', icon: '✅' };
    case 'rejected': return { label: 'Refusé',     color: '#DC3545', icon: '❌' };
    case 'expired':  return { label: 'Expiré',     color: '#DC3545', icon: '⚠️' };
    default:         return { label: 'En attente', color: '#F39C12', icon: '🟡' };
  }
}

export default function PendingVerificationScreen({ navigation, route }: Props) {
  const { driverId } = route.params;

  const [docStatuses, setDocStatuses] = useState<DocStatus[]>([
    { docType: DOCUMENT_TYPES.DRIVER_LICENSE,       status: 'pending' },
    { docType: DOCUMENT_TYPES.VEHICLE_REGISTRATION, status: 'pending' },
    { docType: DOCUMENT_TYPES.INSURANCE,            status: 'pending' },
    { docType: DOCUMENT_TYPES.TECHNICAL_INSPECTION, status: 'pending' },
  ]);

  useEffect(() => {
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
          const n = payload.new as Record<string, unknown>;
          console.log('[FTM-DEBUG] Driver - Verification status update received', {
            driverId,
            newValues: {
              is_verified:                   n.is_verified,
              driver_license_verified:       n.driver_license_verified,
              vehicle_registration_verified: n.vehicle_registration_verified,
              insurance_verified:            n.insurance_verified,
              technical_inspection_verified: n.technical_inspection_verified,
            },
          });

          setDocStatuses([
            { docType: DOCUMENT_TYPES.DRIVER_LICENSE,       status: n.driver_license_verified as VerificationStatus },
            { docType: DOCUMENT_TYPES.VEHICLE_REGISTRATION, status: n.vehicle_registration_verified as VerificationStatus },
            { docType: DOCUMENT_TYPES.INSURANCE,            status: n.insurance_verified as VerificationStatus },
            { docType: DOCUMENT_TYPES.TECHNICAL_INSPECTION, status: n.technical_inspection_verified as VerificationStatus },
          ]);

          if (n.is_verified === true) {
            Alert.alert('✅ Dossier validé !', 'Votre compte chauffeur est actif.', [
              { text: 'Commencer', onPress: () => navigation.replace('DriverHome') },
            ]);
          }
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [driverId, navigation]);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.step}>Étape 4 sur 4</Text>
      <View style={styles.progressBar}>
        <View style={[styles.progressFill, { width: '100%' }]} />
      </View>

      <Text style={styles.emoji}>⏳</Text>
      <Text style={styles.title}>Dossier soumis avec succès !</Text>
      <Text style={styles.subtitle}>Vérification sous 24–48h ouvrables</Text>

      <Text style={styles.sectionTitle}>Statut de vos documents</Text>

      {docStatuses.map(({ docType, status }) => {
        const label  = DOCUMENT_LABELS[docType];
        const config = statusConfig(status);
        return (
          <View key={docType} style={styles.statusRow}>
            <Text style={styles.docLabel}>{label.icon} {label.fr}</Text>
            <Text style={[styles.statusBadge, { color: config.color }]}>
              {config.icon} {config.label}
            </Text>
          </View>
        );
      })}

      <View style={styles.infoBox}>
        <Text style={styles.infoText}>
          ℹ️ Vous serez notifié dès la validation de votre dossier.
        </Text>
      </View>

      <View style={styles.walletBox}>
        <Text style={styles.walletText}>
          💰 Pensez à recharger votre wallet (min. 100 DH) pour commencer à accepter des missions.
        </Text>
      </View>

      <TouchableOpacity
        style={styles.walletButton}
        onPress={() => navigation.navigate('WalletRecharge')}
      >
        <Text style={styles.walletButtonText}>Recharger mon wallet</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container:    { padding: 24, paddingBottom: 48, alignItems: 'center' },
  step:         { color: '#888', fontSize: 13, marginBottom: 6, alignSelf: 'flex-start' },
  progressBar:  { height: 6, backgroundColor: '#E0E0E0', borderRadius: 3, marginBottom: 24, width: '100%' },
  progressFill: { height: '100%', backgroundColor: '#28A745', borderRadius: 3 },
  emoji:        { fontSize: 52, marginBottom: 12 },
  title:        { fontSize: 22, fontWeight: '700', color: '#1A1A2E', textAlign: 'center', marginBottom: 6 },
  subtitle:     { fontSize: 14, color: '#888', marginBottom: 24, textAlign: 'center' },
  sectionTitle: { fontSize: 15, fontWeight: '700', color: '#1A1A2E', alignSelf: 'flex-start', marginBottom: 12 },
  statusRow:    {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    width: '100%', paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: '#F0F0F0',
  },
  docLabel:     { fontSize: 14, color: '#1A1A2E' },
  statusBadge:  { fontSize: 13, fontWeight: '600' },
  infoBox:      {
    marginTop: 20, padding: 14, borderRadius: 10,
    backgroundColor: '#E8F4FD', width: '100%',
  },
  infoText:     { fontSize: 13, color: '#2980B9', lineHeight: 20 },
  walletBox:    {
    marginTop: 12, padding: 14, borderRadius: 10,
    backgroundColor: '#FFF8E7', width: '100%',
  },
  walletText:   { fontSize: 13, color: '#856404', lineHeight: 20 },
  walletButton: {
    marginTop: 20, backgroundColor: '#F39C12', borderRadius: 12,
    padding: 16, alignItems: 'center', width: '100%',
  },
  walletButtonText: { color: '#fff', fontWeight: '700', fontSize: 16 },
});
ENDOFFILE

cat > frontend/src/screens/driver/DocumentStatusScreen.tsx << 'ENDOFFILE'
// /screens/driver/DocumentStatusScreen.tsx
// Fast Trans Maroc — P2 — Suivi vérifications post-onboarding

import React, { useEffect, useState } from 'react';
import {
  View, Text, TouchableOpacity, ScrollView,
  StyleSheet, Linking, ActivityIndicator,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { supabase } from '../../lib/supabaseClient';
import {
  DOCUMENT_LABELS, DOCUMENT_TYPES, DocumentType,
  uploadDocument, saveDocumentUrl,
  pickDocument, pickImageFromCamera,
} from '../../services/documentService';
import { resetDocumentStatus } from '../../services/driverService';
import { COLORS } from '../../constants/theme';

type VerificationStatus = 'pending' | 'verified' | 'rejected' | 'expired';

interface DocInfo {
  docType:        DocumentType;
  number?:        string;
  expiry?:        string;
  status:         VerificationStatus;
  url?:           string;
}

type Props = {
  navigation: NativeStackNavigationProp<any>;
};

function statusConfig(s: VerificationStatus) {
  switch (s) {
    case 'verified': return { label: 'Vérifié',    color: '#28A745', icon: '✅' };
    case 'rejected': return { label: 'Refusé',     color: '#DC3545', icon: '❌' };
    case 'expired':  return { label: 'Expiré',     color: '#DC3545', icon: '⚠️' };
    default:         return { label: 'En attente', color: '#F39C12', icon: '🟡' };
  }
}

export default function DocumentStatusScreen({ navigation }: Props) {
  const [docs,      setDocs]      = useState<DocInfo[]>([]);
  const [driverId,  setDriverId]  = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [uploading, setUploading] = useState<DocumentType | null>(null);

  useEffect(() => {
    loadDriver();
  }, []);

  async function loadDriver() {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    const { data: driver } = await supabase
      .from('drivers')
      .select(`
        id,
        driver_license_number, driver_license_expiry, driver_license_verified, driver_license_url,
        vehicle_registration_number, vehicle_registration_verified, vehicle_registration_url,
        insurance_number, insurance_expiry, insurance_verified, insurance_url,
        technical_inspection_expiry, technical_inspection_verified, technical_inspection_url
      `)
      .eq('profile_id', (
        await supabase.from('profiles').select('id').eq('user_id', user.id).single()
      ).data?.id)
      .single();

    if (!driver) { setIsLoading(false); return; }

    setDriverId(driver.id as string);
    setDocs([
      {
        docType: DOCUMENT_TYPES.DRIVER_LICENSE,
        number:  driver.driver_license_number as string,
        expiry:  driver.driver_license_expiry as string,
        status:  driver.driver_license_verified as VerificationStatus,
        url:     driver.driver_license_url as string,
      },
      {
        docType: DOCUMENT_TYPES.VEHICLE_REGISTRATION,
        number:  driver.vehicle_registration_number as string,
        status:  driver.vehicle_registration_verified as VerificationStatus,
        url:     driver.vehicle_registration_url as string,
      },
      {
        docType: DOCUMENT_TYPES.INSURANCE,
        number:  driver.insurance_number as string,
        expiry:  driver.insurance_expiry as string,
        status:  driver.insurance_verified as VerificationStatus,
        url:     driver.insurance_url as string,
      },
      {
        docType: DOCUMENT_TYPES.TECHNICAL_INSPECTION,
        expiry:  driver.technical_inspection_expiry as string,
        status:  driver.technical_inspection_verified as VerificationStatus,
        url:     driver.technical_inspection_url as string,
      },
    ]);
    setIsLoading(false);
  }

  async function handleReupload(docType: DocumentType, fromCamera: boolean) {
    if (!driverId) return;
    console.log('[FTM-DEBUG] Document - Re-upload initiated', { driverId, docType });

    setUploading(docType);

    const picked = fromCamera ? await pickImageFromCamera() : await pickDocument();
    if (!picked) { setUploading(null); return; }

    await resetDocumentStatus(driverId, docType);

    const result = await uploadDocument(driverId, docType, picked.uri, picked.mimeType);
    if (!result.error) {
      await saveDocumentUrl(driverId, docType, result.url!);
    }

    setUploading(null);
    loadDriver();
  }

  if (isLoading) {
    return (
      <View style={styles.loader}>
        <ActivityIndicator size="large" color={COLORS.primary} />
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Mes documents</Text>

      {docs.map(doc => {
        const label  = DOCUMENT_LABELS[doc.docType];
        const config = statusConfig(doc.status);

        return (
          <View key={doc.docType} style={styles.card}>
            <View style={styles.cardHeader}>
              <Text style={styles.cardTitle}>{label.icon} {label.fr}</Text>
              <Text style={[styles.statusBadge, { color: config.color }]}>
                {config.icon} {config.label}
              </Text>
            </View>

            {doc.number ? (
              <Text style={styles.detail}>N° : {doc.number}</Text>
            ) : null}
            {doc.expiry ? (
              <Text style={styles.detail}>
                Expire : {new Date(doc.expiry).toLocaleDateString('fr-FR')}
              </Text>
            ) : null}

            {doc.status === 'expired' ? (
              <Text style={styles.expiredNote}>
                ⚠️ Renouvelez ce document pour rester actif.
              </Text>
            ) : null}

            <View style={styles.actionRow}>
              {doc.url ? (
                <TouchableOpacity
                  style={styles.viewBtn}
                  onPress={() => Linking.openURL(doc.url!)}
                >
                  <Text style={styles.viewBtnText}>Voir document</Text>
                </TouchableOpacity>
              ) : null}

              {(doc.status === 'rejected' || doc.status === 'expired') ? (
                uploading === doc.docType ? (
                  <ActivityIndicator color={COLORS.primary} />
                ) : (
                  <View style={styles.actionRow}>
                    <TouchableOpacity
                      style={styles.reuploadBtn}
                      onPress={() => handleReupload(doc.docType, true)}
                    >
                      <Text style={styles.reuploadBtnText}>📷 Photo</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={styles.reuploadBtn}
                      onPress={() => handleReupload(doc.docType, false)}
                    >
                      <Text style={styles.reuploadBtnText}>📁 Fichier</Text>
                    </TouchableOpacity>
                  </View>
                )
              ) : null}
            </View>
          </View>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  loader:       { flex: 1, justifyContent: 'center', alignItems: 'center' },
  container:    { padding: 20, paddingBottom: 40 },
  title:        { fontSize: 22, fontWeight: '700', marginBottom: 20, color: '#1A1A2E' },
  card:         {
    borderWidth: 1, borderColor: '#E0E0E0', borderRadius: 12,
    padding: 16, marginBottom: 14, backgroundColor: '#FAFAFA',
  },
  cardHeader:   { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8 },
  cardTitle:    { fontSize: 15, fontWeight: '700', color: '#1A1A2E' },
  statusBadge:  { fontSize: 13, fontWeight: '600' },
  detail:       { fontSize: 13, color: '#555', marginBottom: 4 },
  expiredNote:  { fontSize: 13, color: '#DC3545', marginTop: 6, marginBottom: 6 },
  actionRow:    { flexDirection: 'row', gap: 8, marginTop: 10 },
  viewBtn:      {
    borderWidth: 1, borderColor: COLORS.primary, borderRadius: 8,
    paddingVertical: 8, paddingHorizontal: 14,
  },
  viewBtnText:    { color: COLORS.primary, fontWeight: '600', fontSize: 13 },
  reuploadBtn:    {
    borderWidth: 1, borderColor: '#DC3545', borderRadius: 8,
    paddingVertical: 8, paddingHorizontal: 14,
  },
  reuploadBtnText: { color: '#DC3545', fontWeight: '600', fontSize: 13 },
});
ENDOFFILE

echo "✅ Fichiers P2 créés"