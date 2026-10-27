import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  TextInput,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import { showMessage } from '../../utils/dialogs';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { submitClientRating } from '../../services/missionService';
import type { Mission } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type RootStackParamList = {
  Rating: { mission: Record<string, unknown> };
  ClientHome: { clientProfileId?: string };
};

type Props = NativeStackScreenProps<RootStackParamList, 'Rating'>;

type CriterionKey = 'punctuality' | 'care' | 'service';

const CRITERIA: { key: CriterionKey; label: string; help: string }[] = [
  { key: 'punctuality', label: 'Ponctualité', help: 'Respect de l’heure prévue' },
  { key: 'care', label: 'Soin de la marchandise', help: 'État de la marchandise à l’arrivée' },
  { key: 'service', label: 'Services', help: 'Courtoisie, communication, aide…' },
];

const STAR_COLORS: Record<number, string> = {
  1: '#E53E3E',
  2: '#E53E3E',
  3: '#D69E2E',
  4: '#38A169',
  5: '#38A169',
};

export default function RatingScreen({ route, navigation }: Props) {
  const mission = route.params.mission as unknown as Mission;
  // A1 F5 : 3 criteres, tous obligatoires
  const [ratings, setRatings] = useState<Record<CriterionKey, number>>({
    punctuality: 0,
    care: 0,
    service: 0,
  });
  const [review, setReview] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const allRated = CRITERIA.every((c) => ratings[c.key] > 0);

  const handleSubmit = async () => {
    if (!allRated) {
      showMessage('Notes requises', 'Merci de noter les 3 critères.');
      return;
    }
    setIsLoading(true);
    const result = await submitClientRating(mission.id, ratings, review.trim() || undefined);
    setIsLoading(false);

    if (result.error) {
      showMessage('Erreur', result.error);
    } else {
      navigation.navigate('ClientHome', { clientProfileId: mission.client_id ?? '' });
    }
  };

  const handleSkip = () => {
    navigation.navigate('ClientHome', { clientProfileId: mission.client_id ?? '' });
  };

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.container} keyboardShouldPersistTaps="handled">
      <Text style={styles.title}>Comment s'est passée{'\n'}votre mission ?</Text>

      {CRITERIA.map((criterion) => {
        const value = ratings[criterion.key];
        const starColor = value > 0 ? STAR_COLORS[value] : COLORS.border;
        return (
          <View key={criterion.key} style={styles.criterionBlock}>
            <Text style={styles.criterionLabel}>{criterion.label}</Text>
            <Text style={styles.criterionHelp}>{criterion.help}</Text>
            <View style={styles.starsRow}>
              {[1, 2, 3, 4, 5].map((star) => (
                <TouchableOpacity
                  key={star}
                  onPress={() => setRatings((r) => ({ ...r, [criterion.key]: star }))}
                >
                  <Text style={[styles.star, { color: star <= value ? starColor : COLORS.border }]}>
                    ★
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>
        );
      })}

      <Text style={styles.reviewNote}>
        Votre commentaire pourra être lu par les autres clients, sans votre nom, après validation.
      </Text>

      <TextInput
        style={styles.reviewInput}
        value={review}
        onChangeText={setReview}
        placeholder="Laissez un avis... (optionnel)"
        placeholderTextColor={COLORS.textSecondary}
        multiline
        numberOfLines={4}
        textAlignVertical="top"
      />

      <TouchableOpacity
        style={[styles.submitButton, !allRated && styles.submitButtonDisabled]}
        onPress={handleSubmit}
        disabled={isLoading || !allRated}
      >
        {isLoading ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Text style={styles.submitButtonText}>Envoyer mon avis</Text>
        )}
      </TouchableOpacity>

      <TouchableOpacity onPress={handleSkip} style={styles.skipButton}>
        <Text style={styles.skipText}>Passer</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: { flex: 1, backgroundColor: COLORS.background },
  container: {
    flexGrow: 1,
    backgroundColor: COLORS.background,
    padding: SPACING.lg,
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.text,
    textAlign: 'center',
    marginBottom: SPACING.lg,
    lineHeight: 32,
  },
  criterionBlock: { width: '100%', alignItems: 'center', marginBottom: SPACING.md },
  criterionLabel: { fontSize: 16, fontWeight: '700', color: COLORS.text },
  criterionHelp: { fontSize: 12, color: COLORS.textSecondary, marginBottom: 2 },
  starsRow: {
    flexDirection: 'row',
    gap: SPACING.sm,
  },
  star: { fontSize: 38 },
  reviewNote: { fontSize: 12, color: COLORS.textSecondary, textAlign: 'center', marginBottom: SPACING.xs },
  reviewInput: {
    width: '100%',
    backgroundColor: COLORS.surface,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    color: COLORS.text,
    fontSize: 15,
    minHeight: 100,
    marginBottom: SPACING.lg,
  },
  submitButton: {
    width: '100%',
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    minHeight: 52,
    justifyContent: 'center',
  },
  submitButtonDisabled: { opacity: 0.5 },
  submitButtonText: { color: '#fff', fontSize: 17, fontWeight: '700' },
  skipButton: { marginTop: SPACING.md, padding: SPACING.sm },
  skipText: { color: COLORS.textSecondary, fontSize: 15 },
});
