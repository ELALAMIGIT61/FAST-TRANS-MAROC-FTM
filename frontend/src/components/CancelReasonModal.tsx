// /frontend/src/components/CancelReasonModal.tsx
// FTM A1 (migration 076, decisions du porteur du 03/11/2026) — fenetre
// d'annulation d'une mission conclue par le client : raison obligatoire (une
// case parmi trois), quelques mots facultatifs (200 caracteres au plus), et
// rappel de l'annulation tardive quand elle s'applique. La raison n'est vue
// que par l'admin.
import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Modal, ActivityIndicator } from 'react-native';
import { COLORS, SPACING, BORDER_RADIUS } from '../constants/theme';
import { CLIENT_CANCEL_REASONS } from '../services/missionService';
import type { ClientCancelReason } from '../services/missionService';

interface Props {
  // annulation tardive : delai en heures (null si l'annulation est a temps)
  lateHours: number | null;
  onConfirm: (reason: ClientCancelReason, text: string) => Promise<string | null>;
  onClose: () => void;
}

export default function CancelReasonModal({ lateHours, onConfirm, onClose }: Props) {
  const [reason, setReason] = useState<ClientCancelReason | null>(null);
  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleConfirm = async () => {
    if (!reason) {
      setError('Choisissez la raison de l’annulation.');
      return;
    }
    setSending(true);
    setError(null);
    const message = await onConfirm(reason, text);
    setSending(false);
    if (message) setError(message);
  };

  return (
    <Modal transparent animationType="fade" visible onRequestClose={onClose}>
      <View style={styles.overlay}>
        <View style={styles.card}>
          <Text style={styles.title}>Annuler la mission</Text>
          <Text style={styles.text}>Le chauffeur a réservé ce créneau pour vous.</Text>
          {lateHours !== null && (
            <Text style={styles.warning}>
              {`Annulation tardive : à moins de ${lateHours} h de l’heure prévue (ou après), le chauffeur ne sera pas remboursé de sa commission.`}
            </Text>
          )}
          <Text style={styles.question}>Pourquoi annulez-vous ?</Text>
          {CLIENT_CANCEL_REASONS.map((r) => (
            <TouchableOpacity
              key={r.value}
              style={[styles.option, reason === r.value && styles.optionSelected]}
              onPress={() => {
                setReason(r.value);
                setError(null);
              }}
              disabled={sending}
            >
              <Text style={styles.radio}>{reason === r.value ? '◉' : '○'}</Text>
              <Text style={styles.optionText}>{r.label}</Text>
            </TouchableOpacity>
          ))}
          <TextInput
            style={styles.input}
            placeholder="Quelques mots (facultatif)"
            value={text}
            onChangeText={setText}
            maxLength={200}
            multiline
            editable={!sending}
          />
          {error && <Text style={styles.error}>{error}</Text>}
          <TouchableOpacity
            style={[styles.confirmButton, !reason && styles.confirmDisabled]}
            onPress={handleConfirm}
            disabled={sending}
          >
            {sending ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.confirmText}>Confirmer l’annulation</Text>
            )}
          </TouchableOpacity>
          <TouchableOpacity style={styles.keepButton} onPress={onClose} disabled={sending}>
            <Text style={styles.keepText}>Ne pas annuler</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'center', padding: SPACING.lg },
  card: { backgroundColor: COLORS.surface, borderRadius: BORDER_RADIUS.lg, padding: SPACING.lg, gap: SPACING.sm },
  title: { fontSize: 20, fontWeight: '700', color: COLORS.text, textAlign: 'center' },
  text: { fontSize: 14, color: COLORS.textSecondary, textAlign: 'center' },
  warning: { fontSize: 14, color: COLORS.alert, backgroundColor: '#FDECEA', borderRadius: BORDER_RADIUS.md, padding: SPACING.sm },
  question: { fontSize: 15, fontWeight: '600', color: COLORS.text, marginTop: SPACING.xs },
  option: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
  },
  optionSelected: { borderColor: COLORS.primary, backgroundColor: '#EAF2FB' },
  radio: { fontSize: 18, color: COLORS.primary },
  optionText: { fontSize: 15, color: COLORS.text },
  input: {
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
    minHeight: 60,
    fontSize: 14,
    textAlignVertical: 'top',
  },
  error: { fontSize: 13, color: COLORS.alert },
  confirmButton: {
    backgroundColor: COLORS.alert,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    minHeight: 50,
    justifyContent: 'center',
  },
  confirmDisabled: { backgroundColor: '#EDA3AA' },
  confirmText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  keepButton: { padding: SPACING.sm, alignItems: 'center' },
  keepText: { color: COLORS.primary, fontSize: 15, fontWeight: '600' },
});
