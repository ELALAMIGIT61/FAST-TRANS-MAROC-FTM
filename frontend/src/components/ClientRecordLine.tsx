// /frontend/src/components/ClientRecordLine.tsx
// FTM A1 (migration 076) — ligne « historique du client » montree au
// chauffeur : missions realisees, annulations apres accord et annulations
// tardives sur la periode reglable, ou « Nouveau client ». Rien n'est affiche
// si le serveur ne renvoie rien.
import React, { useEffect, useState } from 'react';
import { Text, StyleSheet } from 'react-native';
import type { StyleProp, TextStyle } from 'react-native';
import { COLORS } from '../constants/theme';
import { formatClientRecord, getMissionClientRecord } from '../services/missionService';
import type { ClientRecord } from '../services/missionService';

export default function ClientRecordLine({
  missionId,
  record,
  style,
}: {
  missionId?: string;
  // deja connu (liste « Missions disponibles ») : pas de lecture
  record?: ClientRecord | null;
  style?: StyleProp<TextStyle>;
}) {
  const [loaded, setLoaded] = useState<ClientRecord | null>(null);

  useEffect(() => {
    if (record || !missionId) return;
    let active = true;
    getMissionClientRecord(missionId).then((r) => {
      if (active) setLoaded(r);
    });
    return () => {
      active = false;
    };
  }, [missionId, record]);

  const r = record ?? loaded;
  if (!r) return null;
  return <Text style={[styles.text, style]}>{formatClientRecord(r)}</Text>;
}

const styles = StyleSheet.create({
  text: { fontSize: 13, color: COLORS.textSecondary },
});
