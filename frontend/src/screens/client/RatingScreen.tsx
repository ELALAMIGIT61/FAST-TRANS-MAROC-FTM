import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  TextInput,
  StyleSheet,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { submitClientRating } from '../../services/missionService';
import type { Mission } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type RootStackParamList = {
  Rating: { mission: Record<string, unknown> };
  ClientHome: undefined;
};

type Props = NativeStackScreenProps<RootStackParamList, 'Rating'>;

const STAR_COLORS: Record<number, string> = {
  1: '#E53E3E',
  2: '#E53E3E',
  3: '#D69E2E',
  4: '#38A169',
  5: '#38A169',
};

export default function RatingScreen({ route, navigation }: Props) {
  const mission = route.params.mission as unknown as Mission;
  const [rating, setRating] = useState(0);
  const [review, setReview] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async () => {
    if (rating === 0) {
      Alert.alert('Note requise', 'Veuillez sélectionner une note.');
      return;
    }
    setIsLoading(true);
    const result = await submitClientRating(mission.id, rating, review || undefined);
    setIsLoading(false);

    if (result.error) {
      Alert.alert('Erreur', result.error);
    } else {
      navigation.replace('ClientHome');
    }
  };

  const handleSkip = () => {
    navigation.replace('ClientHome');
  };

  const starColor = rating > 0 ? STAR_COLORS[rating] : COLORS.border;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Comment s'est passée{'\n'}votre mission ?</Text>

      <View style={styles.starsRow}>
        {[1, 2, 3, 4, 5].map((star) => (
          <TouchableOpacity key={star} onPress={() => setRating(star)}>
            <Text style={[styles.star, { color: star <= rating ? starColor : COLORS.border }]}>
              ★
            </Text>
          </TouchableOpacity>
        ))}
      </View>

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
        style={[styles.submitButton, rating === 0 && styles.submitButtonDisabled]}
        onPress={handleSubmit}
        disabled={isLoading || rating === 0}
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
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
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
    marginBottom: SPACING.xl,
    lineHeight: 32,
  },
  starsRow: {
    flexDirection: 'row',
    gap: SPACING.sm,
    marginBottom: SPACING.xl,
  },
  star: { fontSize: 48 },
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
