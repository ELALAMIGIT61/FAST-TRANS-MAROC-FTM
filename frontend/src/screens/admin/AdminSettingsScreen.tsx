// /frontend/src/screens/admin/AdminSettingsScreen.tsx
// FTM A1 — Ecran « Réglages » de l'admin : modifier sans migration les
// valeurs des regles de fonctionnement (ecarts entre missions, delais
// d'annulation, rayons de diffusion). Chaque changement est confirme puis
// pris en compte immediatement par le serveur.

import React, { useCallback, useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import BackButton from '../../components/BackButton';
import { showMessage, confirmAction } from '../../utils/dialogs';
import { getAppSettings, updateAppSetting, cleanServerMessage, type AppSetting } from '../../services/settingsService';

type Group = {
  prefix: string;
  title: string;
  help: string;
  short: string;
  unit: string;
  max: number;
  // valeur minimale autorisee (0 par defaut)
  min?: number;
};

const GROUPS: Group[] = [
  // A1 (migrations 073 et 074) : commission et solde minimum
  {
    prefix: 'commission_amount_',
    title: 'Commission prélevée au chauffeur par mission',
    help: 'S’applique aux missions créées après le changement. Les chauffeurs de la catégorie sont prévenus. Au moins 1 DH, et pas plus que le solde minimum.',
    short: 'Commission',
    unit: 'DH',
    max: 10000,
    min: 1,
  },
  {
    prefix: 'min_balance_',
    title: 'Solde disponible minimum pour recevoir des missions',
    help: 'Solde moins les commissions des missions conclues pas encore prélevées. En dessous, le chauffeur passe « Hors service ». Jamais inférieur à la commission.',
    short: 'Solde minimum',
    unit: 'DH',
    max: 100000,
  },
  {
    prefix: 'client_cancel_no_refund_hours_',
    title: 'Annulation par le client : délai sans perte du remboursement du chauffeur',
    help: 'Si le client annule à moins de ce délai avant la mission (ou après), la commission du chauffeur n’est pas remboursée.',
    short: 'Annulation client',
    unit: 'h',
    max: 168,
  },
  {
    prefix: 'driver_gap_hours_',
    title: 'Écart minimum entre deux missions d’un chauffeur',
    help: 'Compté entre les heures de début des missions. Une offre plus proche est refusée.',
    short: 'Écart entre missions',
    unit: 'h',
    max: 168,
  },
  {
    prefix: 'cancel_refund_hours_',
    title: 'Annulation par le chauffeur : délai sans perte du remboursement',
    help: 'À moins de ce délai avant la mission, la commission prélevée n’est pas remboursée.',
    short: 'Délai d’annulation',
    unit: 'h',
    max: 168,
  },
  {
    prefix: 'broadcast_radius_km_',
    title: 'Rayon de diffusion des nouvelles missions',
    help: 'Autour du point de chargement. 0 = sans limite (tout le Maroc).',
    short: 'Rayon de diffusion',
    unit: 'km',
    max: 2000,
  },
  {
    // A1 F5 : une seule valeur, commune a toutes les categories
    prefix: 'cancel_count_window_',
    title: 'Annulations des chauffeurs affichées aux clients',
    help: 'Période sur laquelle on compte les missions annulées par le chauffeur.',
    short: 'Période des annulations',
    unit: 'mois',
    max: 60,
  },
  {
    // A1 (migration 076) : historique du client montre aux chauffeurs
    prefix: 'client_cancel_window_',
    title: 'Historique des clients affiché aux chauffeurs',
    help: 'Période sur laquelle on compte les missions réalisées et les annulations du client après accord (dont tardives). Au moins 1 mois.',
    short: 'Période de l’historique client',
    unit: 'mois',
    max: 60,
    min: 1,
  },
  // A1 F9 (migration 071) : missions conclues non demarrees et missions en
  // cours non cloturees (0 = regle desactivee)
  {
    prefix: 'start_reminder_hours_',
    title: 'Rappel au chauffeur : mission conclue non démarrée',
    help: 'Heures après l’heure prévue. Un seul rappel. 0 = pas de rappel.',
    short: 'Rappel « non démarrée »',
    unit: 'h',
    max: 168,
  },
  {
    prefix: 'not_started_close_hours_',
    title: 'Clôture d’une mission conclue non démarrée (« non réalisée »)',
    help: 'Heures après l’heure prévue. Chauffeur, client et admin sont prévenus. 0 = jamais.',
    short: 'Clôture « non réalisée »',
    unit: 'h',
    max: 168,
  },
  {
    prefix: 'in_progress_close_hours_',
    title: 'Clôture d’une mission en cours oubliée (« terminée »)',
    help: 'Heures après le démarrage par le chauffeur. 0 = jamais.',
    short: 'Clôture « terminée »',
    unit: 'h',
    max: 168,
  },
];

const CATEGORY_LABELS: Record<string, string> = {
  vul: 'VUL',
  n2_medium: 'N2 Moyen',
  n2_large: 'N2 Grand',
  months: 'Toutes catégories',
};
const CATEGORY_ORDER = ['vul', 'n2_medium', 'n2_large'];

function formatDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} à ${pad(d.getHours())}h${pad(d.getMinutes())}`;
}

function formatValue(value: number, unit: string): string {
  if (unit === 'km' && value === 0) return 'sans limite';
  return `${value} ${unit}`;
}

export default function AdminSettingsScreen() {
  const [settings, setSettings] = useState<AppSetting[]>([]);
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [savingKey, setSavingKey] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    const result = await getAppSettings();
    setLoading(false);
    if (result.error) {
      setError(result.error);
      return;
    }
    setError(null);
    const list = result.settings ?? [];
    setSettings(list);
    setDrafts(Object.fromEntries(list.map((s) => [s.key, String(s.value)])));
  }, []);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load])
  );

  const save = async (setting: AppSetting, group: Group | null, label: string) => {
    // label : nom complet du reglage, ex. « Écart entre missions — VUL »
    const raw = (drafts[setting.key] ?? '').replace(',', '.').trim();
    const value = Number(raw);
    const unit = group?.unit ?? '';
    const max = group?.max ?? 100000;
    const min = group?.min ?? 0;
    if (raw === '' || !Number.isFinite(value) || value < min || value > max) {
      showMessage('Valeur invalide', `Saisissez un nombre entre ${min} et ${max}${unit ? ' ' + unit : ''}.`);
      return;
    }
    if (value === setting.value) return;
    const ok = await confirmAction(
      'Modifier le réglage',
      `${label} : passer de ${formatValue(setting.value, unit)} à ${formatValue(value, unit)} ?\n\n` +
        'Le changement s’applique immédiatement.',
      { confirmLabel: 'Enregistrer', cancelLabel: 'Annuler' }
    );
    if (!ok) return;
    setSavingKey(setting.key);
    const result = await updateAppSetting(setting.key, value);
    setSavingKey(null);
    if (result.error || !result.setting) {
      showMessage('Erreur', result.error ? cleanServerMessage(result.error) : 'Enregistrement impossible.');
      return;
    }
    const updated = result.setting;
    setSettings((list) => list.map((s) => (s.key === updated.key ? updated : s)));
    setDrafts((d) => ({ ...d, [updated.key]: String(updated.value) }));
    showMessage('Réglage enregistré', `${label} : ${formatValue(updated.value, unit)}.`);
  };

  const renderRow = (setting: AppSetting, group: Group | null, label: string, fullLabel: string) => {
    const draft = drafts[setting.key] ?? '';
    const changed = draft.replace(',', '.').trim() !== String(setting.value);
    return (
      <View key={setting.key} style={styles.row}>
        <View style={styles.rowLabelBox}>
          <Text style={styles.rowLabel}>{label}</Text>
          <Text style={styles.rowMeta}>Modifié le {formatDate(setting.updated_at)}</Text>
        </View>
        <TextInput
          style={styles.input}
          value={draft}
          onChangeText={(t) => setDrafts((d) => ({ ...d, [setting.key]: t }))}
          keyboardType="decimal-pad"
          maxLength={6}
        />
        <Text style={styles.unit}>{group?.unit ?? ''}</Text>
        <TouchableOpacity
          style={[styles.saveButton, !changed && styles.saveButtonDisabled]}
          disabled={!changed || savingKey !== null}
          onPress={() => save(setting, group, fullLabel)}
        >
          {savingKey === setting.key ? (
            <ActivityIndicator color="#fff" size="small" />
          ) : (
            <Text style={styles.saveButtonText}>OK</Text>
          )}
        </TouchableOpacity>
      </View>
    );
  };

  const known = new Set<string>();
  const sections = GROUPS.map((group) => {
    const rows = settings
      .filter((s) => s.key.startsWith(group.prefix))
      .sort(
        (a, b) =>
          CATEGORY_ORDER.indexOf(a.key.slice(group.prefix.length)) -
          CATEGORY_ORDER.indexOf(b.key.slice(group.prefix.length))
      );
    rows.forEach((s) => known.add(s.key));
    return { group, rows };
  });
  const others = settings.filter((s) => !known.has(s.key));

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={load} />}
      keyboardShouldPersistTaps="handled"
    >
      <BackButton />
      <Text style={styles.title}>⚙️ Réglages</Text>
      <Text style={styles.intro}>
        Valeurs des règles de fonctionnement, modifiables à tout moment selon l’expérience. Chaque
        changement est confirmé puis appliqué immédiatement.
      </Text>

      {error && (
        <TouchableOpacity style={styles.errorBox} onPress={load}>
          <Text style={styles.errorText}>Réglages indisponibles — toucher pour réessayer.</Text>
        </TouchableOpacity>
      )}

      {sections.map(({ group, rows }) =>
        rows.length === 0 ? null : (
          <View key={group.prefix} style={styles.card}>
            <Text style={styles.cardTitle}>{group.title}</Text>
            <Text style={styles.cardHelp}>{group.help}</Text>
            {rows.map((s) => {
              const cat = s.key.slice(group.prefix.length);
              const catLabel = CATEGORY_LABELS[cat] ?? cat;
              return renderRow(s, group, catLabel, `${group.short} — ${catLabel}`);
            })}
          </View>
        )
      )}

      {others.length > 0 && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Autres réglages</Text>
          {others.map((s) => renderRow(s, null, s.description ?? s.key, s.description ?? s.key))}
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F5F7FA' },
  content: { padding: 16, paddingBottom: 40 },
  title: { fontSize: 22, fontWeight: '700', color: '#1A1A2E', marginTop: 8 },
  intro: { fontSize: 13, color: '#6C757D', marginTop: 6, marginBottom: 12 },
  errorBox: { backgroundColor: '#FDECEA', borderRadius: 10, padding: 12, marginBottom: 12 },
  errorText: { color: '#DC3545', fontSize: 14 },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 14,
    marginBottom: 14,
    borderWidth: 1,
    borderColor: '#DEE2E6',
  },
  cardTitle: { fontSize: 15, fontWeight: '700', color: '#1A1A2E' },
  cardHelp: { fontSize: 12, color: '#6C757D', marginTop: 4, marginBottom: 8 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    borderTopWidth: 1,
    borderTopColor: '#F0F0F0',
    gap: 8,
  },
  rowLabelBox: { flex: 1 },
  rowLabel: { fontSize: 15, fontWeight: '600', color: '#1A1A2E' },
  rowMeta: { fontSize: 11, color: '#6C757D', marginTop: 2 },
  input: {
    width: 70,
    borderWidth: 1,
    borderColor: '#DEE2E6',
    borderRadius: 8,
    paddingVertical: 6,
    paddingHorizontal: 8,
    fontSize: 15,
    textAlign: 'right',
    color: '#1A1A2E',
    backgroundColor: '#FFFFFF',
  },
  unit: { width: 34, fontSize: 13, color: '#6C757D' },
  saveButton: {
    backgroundColor: '#0056B3',
    borderRadius: 8,
    paddingVertical: 8,
    paddingHorizontal: 12,
    minWidth: 44,
    alignItems: 'center',
  },
  saveButtonDisabled: { backgroundColor: '#ADB5BD' },
  saveButtonText: { color: '#FFFFFF', fontWeight: '700', fontSize: 14 },
});
