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
  getPendingTransactions,
  validatePendingTransaction,
  rejectPendingTransaction,
} from '../../services/walletService';

interface PendingTx {
  id: string;
  transaction_type: string;
  amount: number;
  description: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
  wallet?: {
    driver_id?: string;
    drivers?: {
      profiles?: { full_name?: string; phone_number?: string };
    };
  };
}

export default function PendingTransactionsScreen() {
  const [transactions, setTransactions] = useState<PendingTx[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [processingId, setProcessingId] = useState<string | null>(null);

  const loadTransactions = useCallback(async () => {
    const result = await getPendingTransactions();
    if (result.success && result.transactions) {
      setTransactions(result.transactions as unknown as PendingTx[]);
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

  const handleValidate = (tx: PendingTx) => {
    const confirmMessage = `Valider cette transaction de ${tx.amount} DH ?`;
    const doValidate = async () => {
      setProcessingId(tx.id);
      const result = await validatePendingTransaction(tx.id);
      setProcessingId(null);
      if (result.error) {
        Platform.OS === 'web' ? window.alert(result.error) : Alert.alert('Erreur', result.error);
        return;
      }
      loadTransactions();
    };
    if (Platform.OS === 'web') {
      if (window.confirm(confirmMessage)) doValidate();
    } else {
      Alert.alert('Valider', confirmMessage, [
        { text: 'Annuler', style: 'cancel' },
        { text: 'Valider', onPress: doValidate },
      ]);
    }
  };

  const handleReject = (tx: PendingTx) => {
    const confirmMessage = `Rejeter cette transaction de ${tx.amount} DH ?`;
    const doReject = async () => {
      setProcessingId(tx.id);
      const result = await rejectPendingTransaction(tx.id, 'Rejetee par admin');
      setProcessingId(null);
      if (result.error) {
        Platform.OS === 'web' ? window.alert(result.error) : Alert.alert('Erreur', result.error);
        return;
      }
      loadTransactions();
    };
    if (Platform.OS === 'web') {
      if (window.confirm(confirmMessage)) doReject();
    } else {
      Alert.alert('Rejeter', confirmMessage, [
        { text: 'Annuler', style: 'cancel' },
        { text: 'Rejeter', style: 'destructive', onPress: doReject },
      ]);
    }
  };

  const openProof = (tx: PendingTx) => {
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
      <Text style={styles.title}>💰 Demandes en attente</Text>
      {transactions.length === 0 && (
        <Text style={styles.emptyText}>Aucune demande en attente.</Text>
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
            {tx.description && <Text style={styles.cardLine}>{tx.description}</Text>}
            <Text style={styles.cardDate}>{new Date(tx.created_at).toLocaleString('fr-FR')}</Text>
            {proofUrl && (
              <TouchableOpacity onPress={() => openProof(tx)}>
                <Text style={styles.proofLink}>📎 Voir le justificatif</Text>
              </TouchableOpacity>
            )}
            <View style={styles.actionsRow}>
              <TouchableOpacity
                style={styles.validateButton}
                onPress={() => handleValidate(tx)}
                disabled={isProcessing}
              >
                {isProcessing ? (
                  <ActivityIndicator color="#FFF" size="small" />
                ) : (
                  <Text style={styles.actionButtonText}>Valider</Text>
                )}
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.rejectButton}
                onPress={() => handleReject(tx)}
                disabled={isProcessing}
              >
                <Text style={styles.actionButtonText}>Rejeter</Text>
              </TouchableOpacity>
            </View>
          </View>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F8F9FA', padding: 16 },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  title: { fontSize: 20, fontWeight: '700', color: '#1A1A2E', marginBottom: 16 },
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
  cardDate: { fontSize: 11, color: '#999', marginTop: 4 },
  proofLink: { fontSize: 13, color: '#0056B3', fontWeight: '600', marginTop: 6 },
  actionsRow: { flexDirection: 'row', gap: 10, marginTop: 12 },
  validateButton: {
    flex: 1,
    backgroundColor: '#28A745',
    paddingVertical: 10,
    borderRadius: 8,
    alignItems: 'center',
  },
  rejectButton: {
    flex: 1,
    backgroundColor: '#DC3545',
    paddingVertical: 10,
    borderRadius: 8,
    alignItems: 'center',
  },
  actionButtonText: { color: '#FFF', fontSize: 14, fontWeight: '700' },
});
