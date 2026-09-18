import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Linking,
  Platform,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import {
  getUnreconciledTransactions,
  markBankReconciled,
} from '../../services/walletService';

interface UnreconciledTx {
  id: string;
  transaction_type: string;
  amount: number;
  description: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
  processed_at: string | null;
  wallet?: {
    driver_id?: string;
    drivers?: {
      profiles?: { full_name?: string; phone_number?: string };
    };
  };
}

export default function BankReconciliationScreen() {
  const [transactions, setTransactions] = useState<UnreconciledTx[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [processingId, setProcessingId] = useState<string | null>(null);

  const loadTransactions = useCallback(async () => {
    const result = await getUnreconciledTransactions();
    if (result.success && result.transactions) {
      setTransactions(result.transactions as unknown as UnreconciledTx[]);
    }
    setLoading(false);
    setRefreshing(false);
  }, []);

  useEffect(() => {
    loadTransactions();
  }, [loadTransactions]);

  const onRefresh = () => {
    setRefreshing(true);
    loadTransactions();
  };

  const handleConfirmReconciliation = (tx: UnreconciledTx) => {
    const confirmMessage = `Confirmer que ce paiement de ${tx.amount} DH a bien ete verifie sur le releve bancaire ?`;
    const doConfirm = async () => {
      setProcessingId(tx.id);
      const result = await markBankReconciled(tx.id);
      setProcessingId(null);
      if (result.error) {
        Platform.OS === 'web' ? window.alert(result.error) : Alert.alert('Erreur', result.error);
        return;
      }
      loadTransactions();
    };
    if (Platform.OS === 'web') {
      if (window.confirm(confirmMessage)) doConfirm();
    } else {
      Alert.alert('Confirmer', confirmMessage, [
        { text: 'Annuler', style: 'cancel' },
        { text: 'Confirmer', onPress: doConfirm },
      ]);
    }
  };

  const openProof = (tx: UnreconciledTx) => {
    const url = (tx.metadata as { proof_url?: string } | null)?.proof_url;
    if (url) Linking.openURL(url);
  };

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color="#0056B3" />
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
    >
      <Text style={styles.title}>🏦 Rapprochement bancaire</Text>
      <Text style={styles.subtitle}>
        Paiements deja credites, en attente de verification sur le releve bancaire reel.
      </Text>
      {transactions.length === 0 && (
        <Text style={styles.emptyText}>Aucun paiement en attente de rapprochement.</Text>
      )}
      {transactions.map((tx) => {
        const driverName = tx.wallet?.drivers?.profiles?.full_name ?? 'Chauffeur inconnu';
        const driverPhone = tx.wallet?.drivers?.profiles?.phone_number ?? '';
        const paymentMethod = (tx.metadata as { payment_method?: string } | null)?.payment_method;
        const proofUrl = (tx.metadata as { proof_url?: string } | null)?.proof_url;
        const isProcessing = processingId === tx.id;
        return (
          <View key={tx.id} style={styles.card}>
            <Text style={styles.cardTitle}>
              {tx.transaction_type === 'refund' ? '↩️ Remboursement' : '💵 Recharge'} — {tx.amount.toFixed(2)} DH
            </Text>
            <Text style={styles.cardLine}>{driverName} {driverPhone ? `(${driverPhone})` : ''}</Text>
            {paymentMethod && <Text style={styles.cardLine}>Mode : {paymentMethod}</Text>}
            <Text style={styles.cardDate}>
              Credite le {tx.processed_at ? new Date(tx.processed_at).toLocaleString('fr-FR') : '—'}
            </Text>
            {proofUrl && (
              <TouchableOpacity onPress={() => openProof(tx)}>
                <Text style={styles.proofLink}>📎 Voir le justificatif</Text>
              </TouchableOpacity>
            )}
            <TouchableOpacity
              style={styles.confirmButton}
              onPress={() => handleConfirmReconciliation(tx)}
              disabled={isProcessing}
            >
              {isProcessing ? (
                <ActivityIndicator color="#FFF" size="small" />
              ) : (
                <Text style={styles.confirmButtonText}>Marquer comme verifie</Text>
              )}
            </TouchableOpacity>
          </View>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F8F9FA', padding: 16 },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  title: { fontSize: 20, fontWeight: '700', color: '#1A1A2E', marginBottom: 4 },
  subtitle: { fontSize: 13, color: '#6C757D', marginBottom: 16 },
  emptyText: { fontSize: 14, color: '#6C757D', textAlign: 'center', marginTop: 40 },
  card: {
    backgroundColor: '#FFF',
    borderRadius: 10,
    padding: 14,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  cardTitle: { fontSize: 15, fontWeight: '700', color: '#1A1A2E', marginBottom: 4 },
  cardLine: { fontSize: 13, color: '#333', marginBottom: 2 },
  cardDate: { fontSize: 11, color: '#999', marginTop: 4, marginBottom: 6 },
  proofLink: { fontSize: 13, color: '#0056B3', fontWeight: '600', marginBottom: 10 },
  confirmButton: {
    backgroundColor: '#0056B3',
    paddingVertical: 10,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 6,
  },
  confirmButtonText: { color: '#FFF', fontSize: 14, fontWeight: '700' },
});
