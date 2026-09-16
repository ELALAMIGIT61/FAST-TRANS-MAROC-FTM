import React, { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';

import { COLORS } from '../../constants/theme';
import { requestWalletTopup, uploadPaymentProof } from '../../services/walletService';
import { pickDocument, pickImageFromCamera } from '../../services/documentService';

// ─── Types ────────────────────────────────────────────────────────────────────

type RootStackParamList = {
  WalletDashboard: undefined;
  WalletTopup: { walletId: string; currentBalance: number; minimumBalance: number; driverId: string };
  TransactionHistory: { walletId: string };
};

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'WalletTopup'>;
type RoutePropType = RouteProp<RootStackParamList, 'WalletTopup'>;

const PRESET_AMOUNTS = [100, 200, 300, 500, 1000];

// ─── Component ────────────────────────────────────────────────────────────────

export default function WalletTopupScreen() {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<RoutePropType>();
  const { walletId, currentBalance, minimumBalance, driverId } = route.params;

  const [selectedAmount, setSelectedAmount] = useState<number | null>(null);
  const [customAmount, setCustomAmount] = useState('');
  const [note, setNote] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [paymentMethod, setPaymentMethod] = useState<'cash_agent' | 'bank_transfer' | 'wafacash'>('cash_agent');
  const [proofUri, setProofUri] = useState<string | null>(null);
  const [proofMimeType, setProofMimeType] = useState<string | null>(null);
  const [isUploadingProof, setIsUploadingProof] = useState(false);

  const finalAmount = selectedAmount ?? (customAmount ? parseFloat(customAmount) : 0);
  const isValid = finalAmount >= 100;
  const deficit = Math.max(minimumBalance - currentBalance, 0);

  const handlePreset = (amount: number) => {
    setSelectedAmount(amount);
    setCustomAmount('');
  };

  const handleCustomChange = (text: string) => {
    setCustomAmount(text);
    setSelectedAmount(null);
  };

  const handlePickProof = async (fromCamera: boolean) => {
    const picked = fromCamera ? await pickImageFromCamera() : await pickDocument();
    if (!picked) return;
    setProofUri(picked.uri);
    setProofMimeType(picked.mimeType);
  };

  const requiresProof = paymentMethod !== 'cash_agent';
  const canSubmit = isValid && (!requiresProof || !!proofUri);

  const handleConfirm = async () => {
    if (!canSubmit) return;
    setIsLoading(true);
    let proofUrl: string | null = null;
    if (requiresProof && proofUri && proofMimeType) {
      setIsUploadingProof(true);
      const uploadResult = await uploadPaymentProof(driverId, proofUri, proofMimeType);
      setIsUploadingProof(false);
      if (uploadResult.error) {
        setIsLoading(false);
        Alert.alert('Erreur', uploadResult.error);
        return;
      }
      proofUrl = uploadResult.url ?? null;
    }
    const result = await requestWalletTopup(walletId, finalAmount, note, paymentMethod, proofUrl);
    setIsLoading(false);

    if (result.error) {
      Alert.alert('Erreur', result.error);
      return;
    }

    if (Platform.OS === 'web') {
      window.alert('📨 Demande transmise\n\nVotre demande de recharge a ete transmise. Elle sera traitee par l\'administrateur.');
      navigation.goBack();
    } else {
      Alert.alert(
        '📨 Demande transmise',
        "Votre demande de recharge a ete transmise. Elle sera traitee par l'administrateur.",
        [{ text: 'OK', onPress: () => navigation.goBack() }]
      );
    }
  };

  return (
    <KeyboardAvoidingView
      style={{ flex: 1 }}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView
        style={styles.container}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        <Text style={styles.screenTitle}>Recharger mon wallet</Text>

        {/* Current balance */}
        <View style={styles.infoBox}>
          <Text style={styles.infoRow}>
            Solde actuel :{' '}
            <Text style={{ color: currentBalance >= minimumBalance ? (COLORS.success ?? '#28A745') : (COLORS.alert ?? '#DC3545'), fontWeight: '700' }}>
              {currentBalance.toFixed(2)} DH {currentBalance >= minimumBalance ? '✅' : '❌'}
            </Text>
          </Text>
          <Text style={styles.infoRow}>Minimum requis : {minimumBalance.toFixed(2)} DH</Text>
          {deficit > 0 && (
            <Text style={[styles.infoRow, { color: COLORS.alert ?? '#DC3545' }]}>
              À recharger minimum : {deficit.toFixed(2)} DH
            </Text>
          )}
        </View>

        {/* Preset amounts */}
        <Text style={styles.sectionTitle}>── MONTANT DE RECHARGE ──</Text>
        <View style={styles.presetGrid}>
          {PRESET_AMOUNTS.map((amt) => (
            <TouchableOpacity
              key={amt}
              style={[
                styles.presetCard,
                selectedAmount === amt && styles.presetCardSelected,
              ]}
              onPress={() => handlePreset(amt)}
            >
              <Text
                style={[
                  styles.presetText,
                  selectedAmount === amt && styles.presetTextSelected,
                ]}
              >
                {amt} DH
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* Custom amount */}
        <Text style={styles.sectionTitle}>── OU MONTANT PERSONNALISÉ ──</Text>
        <TextInput
          style={styles.input}
          placeholder="Autre montant (DH)"
          placeholderTextColor={COLORS.textSecondary ?? '#999'}
          keyboardType="numeric"
          value={customAmount}
          onChangeText={handleCustomChange}
        />

        {/* Agent ref */}
        <Text style={styles.sectionTitle}>── NOTE ──</Text>
        <TextInput
          style={styles.input}
          placeholder="Note (optionnel)"
          placeholderTextColor={COLORS.textSecondary ?? '#999'}
          value={note}
          onChangeText={setNote}
        />

        {/* Mode de paiement */}
        <Text style={styles.sectionTitle}>── MODE DE PAIEMENT ──</Text>
        <View style={styles.methodRow}>
          {([
            { key: 'cash_agent', label: 'Especes (agent)' },
            { key: 'bank_transfer', label: 'Virement' },
            { key: 'wafacash', label: 'Wafacash / Cash Plus' },
          ] as const).map((m) => (
            <TouchableOpacity
              key={m.key}
              style={[styles.methodButton, paymentMethod === m.key && styles.methodButtonActive]}
              onPress={() => { setPaymentMethod(m.key); setProofUri(null); setProofMimeType(null); }}
            >
              <Text style={[styles.methodButtonText, paymentMethod === m.key && styles.methodButtonTextActive]}>
                {m.label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {requiresProof && (
          <>
            <Text style={styles.sectionTitle}>── JUSTIFICATIF ──</Text>
            <View style={styles.methodRow}>
              <TouchableOpacity style={styles.proofButton} onPress={() => handlePickProof(false)}>
                <Text style={styles.proofButtonText}>Choisir un fichier</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.proofButton} onPress={() => handlePickProof(true)}>
                <Text style={styles.proofButtonText}>Prendre une photo</Text>
              </TouchableOpacity>
            </View>
            {proofUri && <Text style={styles.proofSelected}>✅ Justificatif selectionne</Text>}
          </>
        )}

        {/* Summary */}
        {finalAmount > 0 && (
          <View style={styles.summaryBox}>
            <Text style={styles.summaryTitle}>── RÉCAPITULATIF ──</Text>
            <Text style={styles.summaryRow}>
              Solde actuel : {currentBalance.toFixed(2)} DH
            </Text>
            <Text style={styles.summaryRow}>
              Recharge :{' '}
              <Text style={{ color: COLORS.success ?? '#28A745', fontWeight: '700' }}>
                +{finalAmount.toFixed(2)} DH
              </Text>
            </Text>
          </View>
        )}

        {/* Info note */}
        <View style={styles.noteBox}>
          <Text style={styles.noteText}>
            {'\u2139\ufe0f'} Votre demande sera examinee par l'equipe FTM. Le solde sera credite apres validation du paiement.
          </Text>
        </View>

        {/* CTA */}
        <TouchableOpacity
          style={[styles.confirmButton, !canSubmit && styles.confirmButtonDisabled]}
          onPress={handleConfirm}
          disabled={!canSubmit || isLoading}
        >
          {isLoading ? (
            <ActivityIndicator color="#1A1A1A" />
          ) : (
            <Text style={styles.confirmButtonText}>
              {isUploadingProof ? 'Envoi du justificatif...' : 'Confirmer la recharge'}
            </Text>
          )}
        </TouchableOpacity>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background ?? '#F5F5F5' },
  content: { padding: 16, paddingBottom: 40 },
  screenTitle: {
    fontSize: 22,
    fontWeight: '700',
    color: COLORS.text ?? '#1A1A1A',
    marginBottom: 16,
  },

  infoBox: {
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderRadius: 10,
    padding: 14,
    marginBottom: 16,
  },
  infoRow: { fontSize: 14, color: COLORS.text ?? '#1A1A1A', marginBottom: 4 },

  sectionTitle: {
    fontSize: 12,
    color: COLORS.textSecondary ?? '#777',
    letterSpacing: 1,
    marginBottom: 10,
    marginTop: 16,
  },

  presetGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  presetCard: {
    flex: 1,
    minWidth: '28%',
    borderWidth: 1.5,
    borderColor: COLORS.border ?? '#E0E0E0',
    borderRadius: 8,
    paddingVertical: 12,
    alignItems: 'center',
    backgroundColor: COLORS.white ?? '#FFFFFF',
  },
  presetCardSelected: {
    borderColor: COLORS.primary ?? '#007AFF',
    backgroundColor: (COLORS.primary ?? '#007AFF') + '15',
  },
  presetText: { fontSize: 15, fontWeight: '600', color: COLORS.text ?? '#1A1A1A' },
  presetTextSelected: { color: COLORS.primary ?? '#007AFF' },

  input: {
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderWidth: 1,
    borderColor: COLORS.border ?? '#E0E0E0',
    borderRadius: 8,
    height: 48,
    paddingHorizontal: 14,
    fontSize: 15,
    color: COLORS.text ?? '#1A1A1A',
  },

  summaryBox: {
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderRadius: 10,
    padding: 14,
    marginTop: 16,
  },
  summaryTitle: { fontSize: 12, color: COLORS.textSecondary ?? '#777', letterSpacing: 1, marginBottom: 8 },
  summaryRow: { fontSize: 14, color: COLORS.text ?? '#1A1A1A', marginBottom: 4 },

  noteBox: {
    backgroundColor: '#FFF9E6',
    borderRadius: 8,
    padding: 12,
    marginTop: 16,
  },
  noteText: { fontSize: 13, color: '#7A6000', lineHeight: 18 },

  confirmButton: {
    backgroundColor: COLORS.primary ?? '#007AFF',
    borderRadius: 10,
    height: 52,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 24,
  },
  confirmButtonDisabled: { opacity: 0.4 },
  confirmButtonText: { fontSize: 16, fontWeight: '700', color: COLORS.white ?? '#FFFFFF' },
  methodRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 8 },
  methodButton: {
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#CCC',
  },
  methodButtonActive: { backgroundColor: '#0056B3', borderColor: '#0056B3' },
  methodButtonText: { fontSize: 13, color: '#333' },
  methodButtonTextActive: { color: '#FFF', fontWeight: '700' },
  proofButton: {
    paddingVertical: 10,
    paddingHorizontal: 14,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#0056B3',
  },
  proofButtonText: { fontSize: 13, color: '#0056B3', fontWeight: '600' },
  proofSelected: { fontSize: 13, color: '#28A745', marginTop: 6 },
});
