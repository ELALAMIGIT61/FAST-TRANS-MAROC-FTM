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
