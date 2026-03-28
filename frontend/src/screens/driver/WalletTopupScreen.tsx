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
import { topupWallet } from '../../services/walletService';

// ─── Types ────────────────────────────────────────────────────────────────────

type RootStackParamList = {
  WalletDashboard: undefined;
  WalletTopup: { walletId: string; currentBalance: number; minimumBalance: number };
  TransactionHistory: { walletId: string };
};

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'WalletTopup'>;
type RoutePropType = RouteProp<RootStackParamList, 'WalletTopup'>;

const PRESET_AMOUNTS = [100, 200, 300, 500, 1000];

// ─── Component ────────────────────────────────────────────────────────────────

export default function WalletTopupScreen() {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<RoutePropType>();
  const { walletId, currentBalance, minimumBalance } = route.params;

  const [selectedAmount, setSelectedAmount] = useState<number | null>(null);
  const [customAmount, setCustomAmount] = useState('');
  const [agentRef, setAgentRef] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const finalAmount = selectedAmount ?? (customAmount ? parseFloat(customAmount) : 0);
  const newBalance = currentBalance + finalAmount;
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

  const handleConfirm = async () => {
    if (!isValid) return;
    setIsLoading(true);
    const result = await topupWallet(walletId, finalAmount, agentRef);
    setIsLoading(false);

    if (result.error) {
      Alert.alert('Erreur', result.error);
      return;
    }

    Alert.alert(
      '✅ Recharge effectuée',
      `Nouveau solde : ${result.balanceAfter?.toFixed(2)} DH`,
      [{ text: 'OK', onPress: () => navigation.goBack() }]
    );
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
        <Text style={styles.sectionTitle}>── RÉFÉRENCE DE PAIEMENT ──</Text>
        <TextInput
          style={styles.input}
          placeholder="Réf. reçu / code agent (optionnel)"
          placeholderTextColor={COLORS.textSecondary ?? '#999'}
          value={agentRef}
          onChangeText={setAgentRef}
        />

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
            <Text style={styles.summaryRow}>
              Nouveau solde :{' '}
              <Text
                style={{
                  color: newBalance >= minimumBalance ? (COLORS.success ?? '#28A745') : (COLORS.alert ?? '#DC3545'),
                  fontWeight: '700',
                }}
              >
                {newBalance.toFixed(2)} DH {newBalance >= minimumBalance ? '✅' : '⚠️'}
              </Text>
            </Text>
          </View>
        )}

        {/* Info note */}
        <View style={styles.noteBox}>
          <Text style={styles.noteText}>
            ℹ️ Le paiement s'effectue en espèces auprès d'un agent FTM.
            Présentez votre numéro de téléphone à l'agent.
          </Text>
        </View>

        {/* CTA */}
        <TouchableOpacity
          style={[styles.confirmButton, !isValid && styles.confirmButtonDisabled]}
          onPress={handleConfirm}
          disabled={!isValid || isLoading}
        >
          {isLoading ? (
            <ActivityIndicator color="#1A1A1A" />
          ) : (
            <Text style={styles.confirmButtonText}>Confirmer la recharge</Text>
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
});
