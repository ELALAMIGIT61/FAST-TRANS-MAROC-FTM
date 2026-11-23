import * as FileSystem from 'expo-file-system';
import { base64ToBytes } from './audioService';

// Correction de l'envoi des fichiers (campagne de tests du 19-20/11/2026) :
// sur telephone, l'envoi d'un « Blob » obtenu par fetch(fichier local) echoue
// (« Network request failed »). Meme methode que les messages vocaux depuis
// le 04/11/2026 : le fichier est lu en base64, puis converti en octets.

export const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

export async function readLocalFileBytes(
  fileUri: string,
  maxBytes: number = MAX_UPLOAD_BYTES
): Promise<{ bytes?: Uint8Array; error?: string }> {
  let base64: string;
  try {
    base64 = await FileSystem.readAsStringAsync(fileUri, {
      encoding: FileSystem.EncodingType.Base64,
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Upload - Read file error', { error: msg });
    return { error: 'Le fichier choisi ne peut pas être lu. Choisissez-en un autre.' };
  }

  // Taille approximative avant le decodage, pour ne pas decoder un fichier trop gros
  const approxBytes = Math.floor((base64.length * 3) / 4);
  if (approxBytes > maxBytes + 3) {
    console.log('[FTM-DEBUG] Upload - File too large', { size: approxBytes });
    return { error: 'Fichier trop volumineux (max 5 MB).' };
  }

  const bytes = base64ToBytes(base64);
  if (bytes.length === 0) {
    return { error: 'Le fichier choisi est vide. Choisissez-en un autre.' };
  }
  if (bytes.length > maxBytes) {
    console.log('[FTM-DEBUG] Upload - File too large', { size: bytes.length });
    return { error: 'Fichier trop volumineux (max 5 MB).' };
  }
  return { bytes };
}
