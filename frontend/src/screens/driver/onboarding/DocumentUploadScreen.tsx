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
