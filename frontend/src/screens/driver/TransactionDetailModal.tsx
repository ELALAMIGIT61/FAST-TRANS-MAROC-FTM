import React from 'react';
import {
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

import { COLORS } from '../../constants/theme';
import { Transaction } from '../../services/walletService';

// ─── Types ────────────────────────────────────────────────────────────────────

interface TransactionDetailModalProps {
  transaction: Transaction | null;
  visible: boolean;
  onClose: () => void;
}

interface TransactionConfig {
  icon: string;
  label: string;
  color: string;
  sign: string;
}

// ─── Config ───────────────────────────────────────────────────────────────────

const TRANSACTION_CONFIG: Record<string, TransactionConfig> = {
  commission: { icon: '💸', label: 'Commission FTM', color: '#DC3545', sign: '−' },
  topup:      { icon: '💰', label: 'Recharge',        color: '#28A745', sign: '+' },
  refund:     { icon: '↩️', label: 'Remboursement',   color: '#28A745', sign: '+' },
};

const VEHICLE_LABELS: Record<string, string> = {
  vul:       '🚐 VUL',
  n2_medium: '🚛 N2 Medium',
  n2_large:  '🚚 N2 Large',
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

function formatDate(isoDate: string | null): string {
  if (!isoDate) return '—';
  const d = new Date(isoDate);
  return d.toLocaleDateString('fr-MA', {
    day:    '2-digit',
    month:  '2-digit',
    year:   'numeric',
    hour:   '2-digit',
    minute: '2-digit',
  });
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={styles.rowValue}>{value}</Text>
    </View>
  );
}

// ─── Component ────────────────────────────────────────────────────────────────

export default function TransactionDetailModal({
  transaction,
  visible,
  onClose,
}: TransactionDetailModalProps) {
  if (!transaction) return null;

  const cfg = TRANSACTION_CONFIG[transaction.transaction_type] ?? TRANSACTION_CONFIG.commission;
  const isFailed = transaction.status === 'failed';
  const metadata = transaction.metadata as Record<string, string> | null;

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
    >
      <View style={styles.container}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.headerTitle}>
            {cfg.icon} {cfg.label}
          </Text>
          <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
            <Text style={styles.closeBtnText}>✕</Text>
          </TouchableOpacity>
        </View>

        <ScrollView contentContainerStyle={styles.content}>
          {/* Amount */}
          <View style={styles.amountSection}>
            <Text style={[styles.amountText, { color: cfg.color }]}>
              {cfg.sign} {transaction.amount.toFixed(2)} DH
            </Text>
            <View
              style={[
                styles.statusBadge,
                { backgroundColor: isFailed ? '#DC3545' : '#28A745' },
              ]}
            >
              <Text style={styles.statusBadgeText}>
                {isFailed ? '❌ Échoué' : '✅ Complété'}
              </Text>
            </View>
          </View>

          {/* Détails */}
          <Text style={styles.sectionTitle}>── DÉTAILS ──</Text>
          <Row label="Type" value={cfg.label} />
          <Row
            label="Date"
            value={formatDate(transaction.processed_at ?? transaction.created_at)}
          />
          {transaction.description && (
            <Row label="Description" value={transaction.description} />
          )}

          {/* Solde */}
          <Text style={styles.sectionTitle}>── SOLDE ──</Text>
          <Row label="Avant" value={`${transaction.balance_before.toFixed(2)} DH`} />
          <Row label="Après" value={`${transaction.balance_after.toFixed(2)} DH`} />

          {/* Mission associée */}
          {transaction.missions && (
            <>
              <Text style={styles.sectionTitle}>── MISSION ASSOCIÉE ──</Text>
              <Row label="N°" value={transaction.missions.mission_number} />
              <Row
                label="Trajet"
                value={`${transaction.missions.pickup_city} → ${transaction.missions.dropoff_city}`}
              />
              <Row
                label="Véhicule"
                value={VEHICLE_LABELS[transaction.missions.vehicle_category] ?? transaction.missions.vehicle_category}
              />
            </>
          )}

          {/* Metadata (topup/refund) */}
          {metadata && Object.keys(metadata).length > 0 && (
            <>
              <Text style={styles.sectionTitle}>── INFORMATIONS PAIEMENT ──</Text>
              {metadata.agent_ref && (
                <Row label="Réf agent" value={metadata.agent_ref} />
              )}
              {metadata.payment_method && (
                <Row
                  label="Méthode"
                  value={
                    metadata.payment_method === 'cash_agent' ? 'Cash agent' : metadata.payment_method
                  }
                />
              )}
              {metadata.reason && (
                <Row label="Motif" value={metadata.reason} />
              )}
            </>
          )}

          <TouchableOpacity style={styles.closeButton} onPress={onClose}>
            <Text style={styles.closeButtonText}>Fermer</Text>
          </TouchableOpacity>
        </ScrollView>
      </View>
    </Modal>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background ?? '#F5F5F5' },

  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 12,
    backgroundColor: COLORS.white ?? '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border ?? '#E0E0E0',
  },
  headerTitle: { fontSize: 17, fontWeight: '700', color: COLORS.text ?? '#1A1A1A', flex: 1 },
  closeBtn: { padding: 4 },
  closeBtnText: { fontSize: 18, color: COLORS.textSecondary ?? '#777' },

  content: { padding: 16, paddingBottom: 40 },

  amountSection: { alignItems: 'center', paddingVertical: 24 },
  amountText: { fontSize: 36, fontWeight: '800', marginBottom: 10 },
  statusBadge: { borderRadius: 20, paddingHorizontal: 14, paddingVertical: 5 },
  statusBadgeText: { color: '#FFFFFF', fontWeight: '700', fontSize: 13 },

  sectionTitle: {
    fontSize: 11,
    color: COLORS.textSecondary ?? '#777',
    letterSpacing: 1,
    marginTop: 20,
    marginBottom: 10,
  },

  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border ?? '#F0F0F0',
  },
  rowLabel: { fontSize: 13, color: COLORS.textSecondary ?? '#777', flex: 1 },
  rowValue: { fontSize: 13, fontWeight: '600', color: COLORS.text ?? '#1A1A1A', flex: 2, textAlign: 'right' },

  closeButton: {
    backgroundColor: COLORS.primary ?? '#007AFF',
    borderRadius: 10,
    height: 48,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 28,
  },
  closeButtonText: { fontSize: 15, fontWeight: '700', color: COLORS.white ?? '#FFFFFF' },
});
