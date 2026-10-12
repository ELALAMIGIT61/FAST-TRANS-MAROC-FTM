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

/**
 * Volet 4b-5 — Enregistre le remplacement d'un document en UNE seule ecriture :
 * lien du fichier + nouvelle date d'expiration (+ date de 1re mise en circulation
 * pour la carte grise) + statut remis a 'pending'.
 * A appeler UNIQUEMENT apres un upload reussi.
 * Cote base (migration 043) : le document repasse en attente et le chauffeur
 * devient indisponible jusqu'a la validation de l'administrateur.
 * Verifie qu'une ligne a bien ete modifiee (une ecriture bloquee par RLS
 * echoue en silence : 0 ligne, aucune erreur).
 */
export async function saveDocumentReplacement(
  driverId: string,
  docType: DocumentType,
  url: string,
  expiry: string,
  firstServiceDate?: string | null
): Promise<{ success?: boolean; error?: string }> {
  const columns: Record<DocumentType, { url: string; expiry: string; verified: string }> = {
    driver_license:       { url: 'driver_license_url',       expiry: 'driver_license_expiry',       verified: 'driver_license_verified' },
    vehicle_registration: { url: 'vehicle_registration_url', expiry: 'vehicle_registration_expiry', verified: 'vehicle_registration_verified' },
    insurance:            { url: 'insurance_url',            expiry: 'insurance_expiry',            verified: 'insurance_verified' },
    technical_inspection: { url: 'technical_inspection_url', expiry: 'technical_inspection_expiry', verified: 'technical_inspection_verified' },
  };

  const col = columns[docType];
  if (!col) {
    console.log('[FTM-DEBUG] Document - Unknown docType', { docType });
    return { error: 'Type de document inconnu.' };
  }

  const update: Record<string, string> = {
    [col.url]:      url,
    [col.expiry]:   expiry,
    [col.verified]: 'pending',
  };
  if (docType === 'vehicle_registration' && firstServiceDate) {
    update.vehicle_first_service_date = firstServiceDate;
  }

  console.log('[FTM-DEBUG] Document - Saving replacement', { driverId, docType, expiry, firstServiceDate });

  const { data, error } = await supabase
    .from('drivers')
    .update(update)
    .eq('id', driverId)
    .select('id');

  if (error) {
    console.log('[FTM-DEBUG] Document - Save replacement error', { error: error.message });
    return { error: error.message };
  }
  if (!data || data.length !== 1) {
    console.log('[FTM-DEBUG] Document - Save replacement: no row updated', { driverId, docType });
    return { error: "Le document n'a pas pu etre enregistre (aucune ligne modifiee)." };
  }

  console.log('[FTM-DEBUG] Document - Replacement saved', { driverId, docType });
  return { success: true };
}

/**
 * Volet 4b-5 — Inscription (etape 2) : enregistre les 2 dates de la carte grise
 * (expiration + 1re mise en circulation). Appelee juste apres saveDriverDocuments
 * (driverService.ts, non modifie). Verifie qu'une ligne a bien ete modifiee
 * (une ecriture bloquee par RLS echoue en silence : 0 ligne, aucune erreur).
 */
export async function saveRegistrationDates(
  driverId: string,
  expiry: string,
  firstServiceDate: string
): Promise<{ success?: boolean; error?: string }> {
  console.log('[FTM-DEBUG] Document - Saving registration dates', { driverId, expiry, firstServiceDate });

  const { data, error } = await supabase
    .from('drivers')
    .update({
      vehicle_registration_expiry: expiry,
      vehicle_first_service_date:  firstServiceDate,
    })
    .eq('id', driverId)
    .select('id');

  if (error) {
    console.log('[FTM-DEBUG] Document - Save registration dates error', { error: error.message });
    return { error: error.message };
  }
  if (!data || data.length !== 1) {
    console.log('[FTM-DEBUG] Document - Save registration dates: no row updated', { driverId });
    return { error: "Les dates de la carte grise n'ont pas pu etre enregistrees (aucune ligne modifiee)." };
  }

  console.log('[FTM-DEBUG] Document - Registration dates saved', { driverId });
  return { success: true };
}
