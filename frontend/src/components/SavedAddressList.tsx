// Lot 5 (C3) : liste « Mes adresses » affichée sous le départ ou l'arrivée de
// l'écran « Nouvelle mission ». Le client choisit une adresse, la renomme ou
// la supprime. Pas d'écran séparé (décision du porteur du 13/11/2026).
import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, ActivityIndicator } from 'react-native';
import { COLORS, SPACING, BORDER_RADIUS } from '../constants/theme';
import { showMessage, confirmAction } from '../utils/dialogs';
import { cleanServerMessage } from '../services/settingsService';
import {
  SavedAddress,
  SAVED_ADDRESS_LABEL_MAX,
  renameSavedAddress,
  deleteSavedAddress,
  savedAddressTitle,
} from '../services/savedAddressService';

interface Props {
  addresses: SavedAddress[];
  onChoose: (address: SavedAddress) => void;
  // appelé après un changement de nom ou une suppression, pour relire la liste
  onChanged: () => void;
}

export default function SavedAddressList({ addresses, onChoose, onChanged }: Props) {
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState('');
  const [busyId, setBusyId] = useState<string | null>(null);

  const startRename = (a: SavedAddress) => {
    setEditingId(a.id);
    setDraft(a.label ?? '');
  };

  const saveRename = async (a: SavedAddress) => {
    setBusyId(a.id);
    const { error } = await renameSavedAddress(a.id, draft);
    setBusyId(null);
    if (error) {
      showMessage('Mes adresses', cleanServerMessage(error));
      return;
    }
    setEditingId(null);
    onChanged();
  };

  const remove = async (a: SavedAddress) => {
    const ok = await confirmAction('Mes adresses', `Supprimer l'adresse « ${savedAddressTitle(a)} » ?`, {
      confirmLabel: 'Supprimer',
      destructive: true,
    });
    if (!ok) return;
    setBusyId(a.id);
    const { error } = await deleteSavedAddress(a.id);
    setBusyId(null);
    if (error) {
      showMessage('Mes adresses', cleanServerMessage(error));
      return;
    }
    onChanged();
  };

  if (addresses.length === 0) {
    return (
      <Text style={styles.empty}>
        Aucune adresse enregistrée. Vous pourrez en enregistrer à la fin d'une mission terminée, sur l'écran de notation.
      </Text>
    );
  }

  return (
    <View style={styles.box}>
      {addresses.map((a) => (
        <View key={a.id} style={styles.row}>
          {editingId === a.id ? (
            <>
              <TextInput
                style={styles.input}
                value={draft}
                onChangeText={setDraft}
                placeholder="Nom de l'adresse (ex. Maison, Dépôt)"
                placeholderTextColor={COLORS.textSecondary}
                maxLength={SAVED_ADDRESS_LABEL_MAX}
                autoFocus
              />
              <View style={styles.actions}>
                <TouchableOpacity onPress={() => setEditingId(null)} disabled={busyId === a.id}>
                  <Text style={styles.actionMuted}>Annuler</Text>
                </TouchableOpacity>
                <TouchableOpacity onPress={() => saveRename(a)} disabled={busyId === a.id}>
                  {busyId === a.id ? <ActivityIndicator size="small" color={COLORS.primary} /> : <Text style={styles.action}>Enregistrer</Text>}
                </TouchableOpacity>
              </View>
            </>
          ) : (
            <>
              <TouchableOpacity onPress={() => onChoose(a)} disabled={busyId === a.id}>
                <Text style={styles.title}>{a.label ? `🏷 ${a.label}` : '📍 Adresse'}</Text>
                <Text style={styles.text}>{a.address}, {a.city}</Text>
                {!!a.landmark && <Text style={styles.sub}>Repère : {a.landmark}</Text>}
              </TouchableOpacity>
              <View style={styles.actions}>
                <TouchableOpacity onPress={() => remove(a)} disabled={busyId === a.id}>
                  <Text style={styles.actionDanger}>Supprimer</Text>
                </TouchableOpacity>
                <TouchableOpacity onPress={() => startRename(a)} disabled={busyId === a.id}>
                  <Text style={styles.actionMuted}>Renommer</Text>
                </TouchableOpacity>
                <TouchableOpacity onPress={() => onChoose(a)} disabled={busyId === a.id}>
                  <Text style={styles.action}>Choisir</Text>
                </TouchableOpacity>
              </View>
            </>
          )}
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  box: {
    backgroundColor: COLORS.surface,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    marginBottom: SPACING.sm,
  },
  row: { padding: SPACING.sm, borderBottomWidth: 1, borderBottomColor: COLORS.border },
  title: { fontSize: 14, fontWeight: '700', color: COLORS.text },
  text: { fontSize: 14, color: COLORS.text },
  sub: { fontSize: 12, color: COLORS.textSecondary, marginTop: 2 },
  actions: { flexDirection: 'row', justifyContent: 'flex-end', gap: 16, marginTop: 6 },
  action: { fontSize: 14, fontWeight: '700', color: COLORS.primary },
  actionMuted: { fontSize: 14, color: COLORS.textSecondary },
  actionDanger: { fontSize: 14, color: COLORS.alert },
  input: {
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
    color: COLORS.text,
    fontSize: 14,
  },
  empty: { fontSize: 13, color: COLORS.textSecondary, fontStyle: 'italic', marginBottom: SPACING.sm },
});
