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
