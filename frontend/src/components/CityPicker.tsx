// /frontend/src/components/CityPicker.tsx
// FTM A1 (correction 15) — Choix d'une ville dans la liste des villes du Maroc.
// Un champ qui ouvre une liste avec recherche (accents et majuscules ignores).

import React, { useMemo, useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  Modal,
  FlatList,
  StyleSheet,
} from 'react-native';
import { COLORS, SPACING, BORDER_RADIUS } from '../constants/theme';
import { MOROCCO_CITIES, normalizeCityName } from '../constants/moroccoCities';

type Props = {
  value: string;
  onChange: (city: string) => void;
  placeholder: string;
};

export default function CityPicker({ value, onChange, placeholder }: Props) {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState('');

  const filtered = useMemo(() => {
    const q = normalizeCityName(search);
    if (!q) return MOROCCO_CITIES;
    return MOROCCO_CITIES.filter((c) => normalizeCityName(c.name).includes(q));
  }, [search]);

  const close = () => {
    setOpen(false);
    setSearch('');
  };

  return (
    <>
      <TouchableOpacity style={styles.field} onPress={() => setOpen(true)}>
        <Text style={value ? styles.fieldText : styles.placeholder}>
          {value ? value : placeholder}
        </Text>
        <Text style={styles.arrow}>▼</Text>
      </TouchableOpacity>

      <Modal visible={open} animationType="slide" transparent onRequestClose={close}>
        <View style={styles.backdrop}>
          <View style={styles.sheet}>
            <Text style={styles.title}>{placeholder}</Text>
            <TextInput
              style={styles.search}
              value={search}
              onChangeText={setSearch}
              placeholder="Rechercher une ville"
              placeholderTextColor={COLORS.textSecondary}
              autoCorrect={false}
            />
            <FlatList
              data={filtered}
              keyExtractor={(c) => c.name}
              keyboardShouldPersistTaps="handled"
              renderItem={({ item }) => (
                <TouchableOpacity
                  style={styles.row}
                  onPress={() => {
                    onChange(item.name);
                    close();
                  }}
                >
                  <Text style={[styles.rowText, item.name === value && styles.rowTextActive]}>
                    {item.name}
                  </Text>
                </TouchableOpacity>
              )}
              ListEmptyComponent={
                <Text style={styles.empty}>
                  Ville absente de la liste : choisissez la ville la plus proche.
                </Text>
              }
            />
            <TouchableOpacity style={styles.closeButton} onPress={close}>
              <Text style={styles.closeButtonText}>Fermer</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  field: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: COLORS.surface,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
    marginBottom: SPACING.sm,
  },
  fieldText: { color: COLORS.text, fontSize: 15 },
  placeholder: { color: COLORS.textSecondary, fontSize: 15 },
  arrow: { color: COLORS.textSecondary, fontSize: 12 },
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'flex-end' },
  sheet: {
    backgroundColor: COLORS.background,
    borderTopLeftRadius: BORDER_RADIUS.lg,
    borderTopRightRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    maxHeight: '80%',
  },
  title: { fontSize: 16, fontWeight: '700', color: COLORS.text, marginBottom: SPACING.sm },
  search: {
    backgroundColor: COLORS.surface,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
    color: COLORS.text,
    fontSize: 15,
    marginBottom: SPACING.sm,
  },
  row: { paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: COLORS.border },
  rowText: { fontSize: 15, color: COLORS.text },
  rowTextActive: { color: COLORS.primary, fontWeight: '700' },
  empty: { color: COLORS.textSecondary, fontSize: 14, paddingVertical: SPACING.md },
  closeButton: { alignItems: 'center', paddingVertical: SPACING.md },
  closeButtonText: { color: COLORS.primary, fontSize: 16, fontWeight: '600' },
});
