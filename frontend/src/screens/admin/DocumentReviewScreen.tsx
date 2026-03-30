import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Modal,
  TextInput,
  RefreshControl,
  ActivityIndicator,
  Linking,
  Alert,
  ScrollView,
} from 'react-native';
import { COLORS } from '../../constants/theme';
import { getPendingDrivers, verifyDocument, rejectDocument } from '../../services/adminService';

type DocumentType = 'driver_license' | 'vehicle_registration' | 'insurance' | 'technical_inspection';

interface Driver {
  id: string;
  profile_id: string;
  vehicle_category: string;
  vehicle_brand: string;
  vehicle_model: string;
  license_plate: string;
  driver_license_number: string;
  driver_license_expiry: string;
  driver_license_verified: string;
  driver_license_url: string;
  vehicle_registration_number: string;
  vehicle_registration_verified: string;
  vehicle_registration_url: string;
  insurance_number: string;
  insurance_expiry: string;
  insurance_verified: string;
  insurance_url: string;
  technical_inspection_expiry: string;
  technical_inspection_verified: string;
  technical_inspection_url: string;
  is_verified: boolean;
  created_at: string;
  profiles: {
    id: string;
    full_name: string;
    phone_number: string;
    language_preference: string;
    is_active: boolean;
    created_at: string;
  };
}

const DOC_LABELS: Record<DocumentType, string> = {
  driver_license: '🪪 Permis de conduire',
  vehicle_registration: '📄 Carte grise',
  insurance: '🛡️ Assurance',
  technical_inspection: '🔧 Visite technique',
};

function statusIcon(status: string) {
  if (status === 'verified') return '✅';
  if (status === 'rejected') return '❌';
  return '🟡';
}

function statusLabel(status: string) {
  if (status === 'verified') return 'Vérifié';
  if (status === 'rejected') return 'Rejeté';
  return 'En attente';
}

export default function DocumentReviewScreen() {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [selectedDriver, setSelectedDriver] = useState<Driver | null>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [rejectTarget, setRejectTarget] = useState<DocumentType | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  const loadDrivers = useCallback(async () => {
    const result = await getPendingDrivers();
    if (result.success && result.drivers) {
      setDrivers(result.drivers as Driver[]);
    }
    setLoading(false);
    setRefreshing(false);
  }, []);

  useEffect(() => { loadDrivers(); }, [loadDrivers]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadDrivers();
  }, [loadDrivers]);

  const handleVerify = async (driver: Driver, docType: DocumentType) => {
    setIsProcessing(true);
    const result = await verifyDocument(driver.id, docType, driver.profile_id);
    if (result.success) {
      await loadDrivers();
      if (selectedDriver) {
        const updated = drivers.find(d => d.id === driver.id);
        if (updated) setSelectedDriver(updated);
      }
    } else {
      Alert.alert('Erreur', result.error ?? 'Une erreur est survenue');
    }
    setIsProcessing(false);
  };

  const handleRejectConfirm = async () => {
    if (!selectedDriver || !rejectTarget || !rejectReason.trim()) {
      Alert.alert('Requis', 'Veuillez saisir un motif de rejet.');
      return;
    }
    setIsProcessing(true);
    const result = await rejectDocument(selectedDriver.id, rejectTarget, selectedDriver.profile_id, rejectReason.trim());
    if (result.success) {
      setRejectTarget(null);
      setRejectReason('');
      await loadDrivers();
    } else {
      Alert.alert('Erreur', result.error ?? 'Une erreur est survenue');
    }
    setIsProcessing(false);
  };

  const docs: { key: DocumentType; label: string; verifiedField: string; urlField: string; numberField: string; expiryField: string }[] = [
    { key: 'driver_license', label: DOC_LABELS.driver_license, verifiedField: 'driver_license_verified', urlField: 'driver_license_url', numberField: 'driver_license_number', expiryField: 'driver_license_expiry' },
    { key: 'vehicle_registration', label: DOC_LABELS.vehicle_registration, verifiedField: 'vehicle_registration_verified', urlField: 'vehicle_registration_url', numberField: 'vehicle_registration_number', expiryField: '' },
    { key: 'insurance', label: DOC_LABELS.insurance, verifiedField: 'insurance_verified', urlField: 'insurance_url', numberField: 'insurance_number', expiryField: 'insurance_expiry' },
    { key: 'technical_inspection', label: DOC_LABELS.technical_inspection, verifiedField: 'technical_inspection_verified', urlField: 'technical_inspection_url', numberField: '', expiryField: 'technical_inspection_expiry' },
  ];

  const renderDriverCard = ({ item }: { item: Driver }) => (
    <TouchableOpacity style={styles.card} onPress={() => setSelectedDriver(item)}>
      <Text style={styles.cardName}>👤 {item.profiles?.full_name}</Text>
      <Text style={styles.cardSub}>🚐 {item.vehicle_category?.toUpperCase()} — {item.license_plate}</Text>
      <Text style={styles.cardSub}>Inscrit le {new Date(item.created_at).toLocaleDateString('fr-MA')}</Text>
      <View style={styles.docRow}>
        {docs.map(d => (
          <Text key={d.key} style={styles.docBadge}>
            {statusIcon((item as any)[d.verifiedField])} {d.label.split(' ')[1]}
          </Text>
        ))}
      </View>
      <Text style={styles.viewDocs}>Voir les documents →</Text>
    </TouchableOpacity>
  );

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color={COLORS.primary} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={drivers}
        keyExtractor={item => item.id}
        renderItem={renderDriverCard}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        ListHeaderComponent={
          <Text style={styles.header}>Documents en attente ({drivers.length})</Text>
        }
        ListEmptyComponent={
          <Text style={styles.empty}>✅ Aucun document en attente.</Text>
        }
      />

      <Modal visible={!!selectedDriver} animationType="slide" onRequestClose={() => setSelectedDriver(null)}>
        {selectedDriver && (
          <ScrollView style={styles.modal}>
            <TouchableOpacity onPress={() => setSelectedDriver(null)} style={styles.closeBtn}>
              <Text style={styles.closeBtnText}>✕ Fermer</Text>
            </TouchableOpacity>
            <Text style={styles.modalName}>👤 {selectedDriver.profiles?.full_name}</Text>
            <Text style={styles.modalSub}>📞 {selectedDriver.profiles?.phone_number}</Text>
            <Text style={styles.modalSub}>🚐 {selectedDriver.vehicle_category} | {selectedDriver.vehicle_brand} {selectedDriver.vehicle_model}</Text>
            <Text style={styles.modalSub}>Plaque : {selectedDriver.license_plate}</Text>

            {selectedDriver.is_verified && (
              <View style={styles.verifiedBanner}>
                <Text style={styles.verifiedBannerText}>✅ Dossier complet validé !</Text>
              </View>
            )}

            {docs.map(doc => {
              const status: string = (selectedDriver as any)[doc.verifiedField] ?? 'pending';
              const url: string = (selectedDriver as any)[doc.urlField] ?? '';
              const number: string = doc.numberField ? (selectedDriver as any)[doc.numberField] : '';
              const expiry: string = doc.expiryField ? (selectedDriver as any)[doc.expiryField] : '';
              return (
                <View key={doc.key} style={styles.docSection}>
                  <Text style={styles.docSectionTitle}>── {doc.label} ──</Text>
                  <Text style={styles.docStatus}>{statusIcon(status)} {statusLabel(status)}</Text>
                  {number ? <Text style={styles.docInfo}>N° : {number}</Text> : null}
                  {expiry ? <Text style={styles.docInfo}>Expire : {new Date(expiry).toLocaleDateString('fr-MA')}</Text> : null}
                  {url ? (
                    <TouchableOpacity onPress={() => Linking.openURL(url)}>
                      <Text style={styles.viewDocBtn}>🔍 Voir le document</Text>
                    </TouchableOpacity>
                  ) : null}
                  {status === 'pending' && (
                    <View style={styles.actionRow}>
                      <TouchableOpacity
                        style={[styles.actionBtn, styles.validateBtn]}
                        onPress={() => handleVerify(selectedDriver, doc.key)}
                        disabled={isProcessing}
                      >
                        <Text style={styles.actionBtnText}>✅ Valider</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={[styles.actionBtn, styles.rejectBtn]}
                        onPress={() => setRejectTarget(doc.key)}
                        disabled={isProcessing}
                      >
                        <Text style={styles.actionBtnText}>❌ Rejeter</Text>
                      </TouchableOpacity>
                    </View>
                  )}
                  {rejectTarget === doc.key && (
                    <View style={styles.rejectForm}>
                      <TextInput
                        style={styles.rejectInput}
                        placeholder="Ex: Document illisible"
                        value={rejectReason}
                        onChangeText={setRejectReason}
                        multiline
                      />
                      <TouchableOpacity
                        style={styles.confirmRejectBtn}
                        onPress={handleRejectConfirm}
                        disabled={isProcessing}
                      >
                        <Text style={styles.confirmRejectText}>Confirmer le rejet</Text>
                      </TouchableOpacity>
                    </View>
                  )}
                </View>
              );
            })}
          </ScrollView>
        )}
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F5F7FA' },
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  header: { fontSize: 18, fontWeight: '700', color: COLORS.primary, padding: 16, paddingBottom: 8 },
  card: {
    backgroundColor: '#FFF',
    margin: 12,
    marginBottom: 0,
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 3,
    elevation: 2,
  },
  cardName: { fontSize: 15, fontWeight: '700', color: '#1A1A2E', marginBottom: 4 },
  cardSub: { fontSize: 13, color: '#666', marginBottom: 2 },
  docRow: { flexDirection: 'row', flexWrap: 'wrap', marginTop: 8, gap: 6 },
  docBadge: { fontSize: 12, color: '#555', marginRight: 8 },
  viewDocs: { marginTop: 10, color: COLORS.primary, fontWeight: '600', fontSize: 13 },
  empty: { textAlign: 'center', color: '#888', marginTop: 40, fontSize: 15 },
  modal: { flex: 1, backgroundColor: '#F5F7FA', padding: 16 },
  closeBtn: { alignSelf: 'flex-end', padding: 8, marginBottom: 8 },
  closeBtnText: { color: '#888', fontSize: 14 },
  modalName: { fontSize: 18, fontWeight: '700', color: '#1A1A2E', marginBottom: 4 },
  modalSub: { fontSize: 13, color: '#666', marginBottom: 2 },
  verifiedBanner: {
    backgroundColor: '#D1FAE5',
    borderRadius: 8,
    padding: 10,
    marginVertical: 12,
    alignItems: 'center',
  },
  verifiedBannerText: { color: '#065F46', fontWeight: '700', fontSize: 14 },
  docSection: {
    backgroundColor: '#FFF',
    borderRadius: 10,
    padding: 14,
    marginTop: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.04,
    shadowRadius: 3,
    elevation: 1,
  },
  docSectionTitle: { fontSize: 14, fontWeight: '700', color: '#333', marginBottom: 6 },
  docStatus: { fontSize: 13, color: '#555', marginBottom: 4 },
  docInfo: { fontSize: 13, color: '#444', marginBottom: 2 },
  viewDocBtn: { color: COLORS.primary, fontWeight: '600', fontSize: 13, marginTop: 6 },
  actionRow: { flexDirection: 'row', gap: 10, marginTop: 10 },
  actionBtn: {
    flex: 1,
    borderRadius: 8,
    padding: 10,
    alignItems: 'center',
  },
  validateBtn: { backgroundColor: '#10B981' },
  rejectBtn: { backgroundColor: '#EF4444' },
  actionBtnText: { color: '#FFF', fontWeight: '700', fontSize: 13 },
  rejectForm: { marginTop: 10 },
  rejectInput: {
    borderWidth: 1,
    borderColor: '#DDD',
    borderRadius: 8,
    padding: 10,
    fontSize: 13,
    color: '#333',
    backgroundColor: '#FFF',
    minHeight: 60,
  },
  confirmRejectBtn: {
    backgroundColor: '#EF4444',
    borderRadius: 8,
    padding: 10,
    alignItems: 'center',
    marginTop: 8,
  },
  confirmRejectText: { color: '#FFF', fontWeight: '700', fontSize: 13 },
});
