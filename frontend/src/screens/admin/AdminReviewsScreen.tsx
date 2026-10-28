// /frontend/src/screens/admin/AdminReviewsScreen.tsx
// FTM A1 F5 — « Avis à modérer » : l'admin publie ou refuse les commentaires
// des clients avant qu'ils soient visibles par les autres clients (sans le nom
// du client). Les notes, elles, comptent tout de suite dans les moyennes.

import React, { useCallback, useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  RefreshControl,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import BackButton from '../../components/BackButton';
import { showMessage, confirmAction } from '../../utils/dialogs';
import {
  getReviewsToModerate,
  moderateReview,
  type ReviewToModerate,
} from '../../services/reputationService';

export default function AdminReviewsScreen() {
  const [reviews, setReviews] = useState<ReviewToModerate[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    const result = await getReviewsToModerate();
    setLoading(false);
    if (result.error) {
      setError(result.error);
      return;
    }
    setError(null);
    setReviews(result.reviews ?? []);
  }, []);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load])
  );

  const decide = async (item: ReviewToModerate, publish: boolean) => {
    const ok = await confirmAction(
      publish ? 'Publier cet avis' : 'Refuser cet avis',
      publish
        ? 'Le commentaire sera visible par les clients (sans le nom de son auteur).'
        : 'Le commentaire ne sera jamais affiché. Les notes restent comptées.',
      { confirmLabel: publish ? 'Publier' : 'Refuser', cancelLabel: 'Annuler', destructive: !publish }
    );
    if (!ok) return;
    setBusyId(item.mission_id);
    const result = await moderateReview(item.mission_id, publish);
    setBusyId(null);
    if (result.error) {
      showMessage('Erreur', result.error);
    }
    setReviews((list) => list.filter((r) => r.mission_id !== item.mission_id));
  };

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={load} />}
    >
      <BackButton />
      <Text style={styles.title}>⭐ Avis à modérer</Text>
      <Text style={styles.intro}>
        Un avis publié est visible par les clients sur l’écran des offres, sans le nom de son auteur.
      </Text>

      {error && (
        <TouchableOpacity style={styles.errorBox} onPress={load}>
          <Text style={styles.errorText}>Liste indisponible — toucher pour réessayer.</Text>
        </TouchableOpacity>
      )}

      {!loading && !error && reviews.length === 0 && (
        <Text style={styles.empty}>Aucun avis en attente.</Text>
      )}

      {reviews.map((item) => (
        <View key={item.mission_id} style={styles.card}>
          <Text style={styles.meta}>
            {`Mission ${item.mission_number} · ${new Date(item.review_date).toLocaleDateString('fr-FR')}`}
            {item.driver_name ? ` · Chauffeur : ${item.driver_name}` : ''}
          </Text>
          <Text style={styles.notes}>
            {`Ponctualité ★ ${item.rating_punctuality}  ·  Soin ★ ${item.rating_care}  ·  Services ★ ${item.rating_service}`}
          </Text>
          <Text style={styles.review}>« {item.review} »</Text>
          <View style={styles.actions}>
            <TouchableOpacity
              style={[styles.button, styles.publish]}
              disabled={busyId !== null}
              onPress={() => decide(item, true)}
            >
              <Text style={styles.buttonText}>Publier</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.button, styles.reject]}
              disabled={busyId !== null}
              onPress={() => decide(item, false)}
            >
              <Text style={styles.buttonText}>Refuser</Text>
            </TouchableOpacity>
          </View>
        </View>
      ))}
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
  empty: { fontSize: 14, color: '#6C757D', textAlign: 'center', marginTop: 24 },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 14,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#DEE2E6',
    gap: 6,
  },
  meta: { fontSize: 12, color: '#6C757D' },
  notes: { fontSize: 13, color: '#1A1A2E', fontWeight: '600' },
  review: { fontSize: 15, color: '#1A1A2E', fontStyle: 'italic' },
  actions: { flexDirection: 'row', gap: 10, marginTop: 4 },
  button: { flex: 1, borderRadius: 8, paddingVertical: 10, alignItems: 'center' },
  publish: { backgroundColor: '#28A745' },
  reject: { backgroundColor: '#DC3545' },
  buttonText: { color: '#FFFFFF', fontWeight: '700', fontSize: 14 },
});
