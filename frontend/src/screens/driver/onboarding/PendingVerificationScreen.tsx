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
