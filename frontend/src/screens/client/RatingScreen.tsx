import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  TextInput,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import { showMessage, confirmAction } from '../../utils/dialogs';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { submitClientRating, getMissionExactLocation } from '../../services/missionService';
import { cleanServerMessage } from '../../services/settingsService';
import type { Mission } from '../../services/missionService';
import { saveMissionAddress, listSavedAddresses, SAVED_ADDRESS_LABEL_MAX } from '../../services/savedAddressService';
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

  // Lot 5 (C3, decision du porteur du 13/11/2026) : a la fin d'une mission
  // terminee, le client peut enregistrer l'adresse de chargement et celle de
  // livraison dans « Mes adresses », avec un nom facultatif.
  const [addressLabel, setAddressLabel] = useState('');
  const [savedWhich, setSavedWhich] = useState<{ pickup: boolean; dropoff: boolean }>({ pickup: false, dropoff: false });
  const [savingWhich, setSavingWhich] = useState<'pickup' | 'dropoff' | null>(null);

  // Adresses deja enregistrees lors d'une visite precedente de cet ecran
  // (client passe puis revenu par « ⭐ Noter » ou par un rappel)
  useEffect(() => {
    if (mission.status !== 'completed' || !mission.client_id) return;
    let active = true;
    (async () => {
      const [{ location }, { addresses }] = await Promise.all([
        getMissionExactLocation(mission.id),
        listSavedAddresses(mission.client_id as string),
      ]);
      if (!active || !location) return;
      const same = (address: string | null, city: string) =>
        !!address &&
        addresses.some(
          (a) => a.address.toLowerCase() === address.trim().toLowerCase() && a.city.toLowerCase() === city.toLowerCase()
        );
      setSavedWhich({
        pickup: same(location.pickup_address, mission.pickup_city),
        dropoff: same(location.dropoff_address, mission.dropoff_city),
      });
    })();
    return () => {
      active = false;
    };
  }, [mission.id, mission.status, mission.client_id, mission.pickup_city, mission.dropoff_city]);

  const handleSaveAddress = async (which: 'pickup' | 'dropoff') => {
    setSavingWhich(which);
    const result = await saveMissionAddress(mission.id, which, addressLabel);
    setSavingWhich(null);
    if (result.error) {
      showMessage('Mes adresses', cleanServerMessage(result.error));
      return;
    }
    setSavedWhich((w) => ({ ...w, [which]: true }));
    setAddressLabel('');
    showMessage('Mes adresses', 'Adresse enregistrée. Vous la retrouverez avec « 📍 Mes adresses » à votre prochaine mission.');
  };

  const handleSubmit = async () => {
    if (!allRated) {
      showMessage('Notes requises', 'Merci de noter les 3 critères.');
      return;
    }
    // Lot 5 (C3, demande du porteur du 13/11/2026) : apres l'envoi de l'avis, les
    // adresses de la mission ne peuvent plus etre enregistrees ; confirmation si
    // l'une ou les deux ne le sont pas. (« Passer » reste sans confirmation.)
    if (mission.status === 'completed' && (!savedWhich.pickup || !savedWhich.dropoff)) {
      const missing =
        !savedWhich.pickup && !savedWhich.dropoff
          ? 'Les adresses de chargement et de livraison ne sont pas enregistrées.'
          : !savedWhich.pickup
            ? 'L’adresse de chargement n’est pas enregistrée.'
            : 'L’adresse de livraison n’est pas enregistrée.';
      const goOn = await confirmAction(
        'Adresses non enregistrées',
        `${missing} Après l’envoi de votre avis, vous ne pourrez plus le faire.`,
        { confirmLabel: 'Envoyer sans enregistrer', cancelLabel: 'Enregistrer d’abord' }
      );
      if (!goOn) return;
    }
    setIsLoading(true);
    const result = await submitClientRating(mission.id, ratings, review.trim() || undefined);
    setIsLoading(false);

    if (result.error) {
      // A1 (migration 077) : message du serveur sans son code (ex. delai depasse)
      showMessage(result.error.startsWith('notation_expiree') ? 'Notation impossible' : 'Erreur', cleanServerMessage(result.error));
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

      {mission.status === 'completed' && (
        <View style={styles.saveBox}>
          <Text style={styles.saveTitle}>📍 Enregistrer une adresse de cette mission</Text>
          <Text style={styles.saveHelp}>Pour la retrouver à votre prochaine mission (facultatif).</Text>
          <TextInput
            style={styles.saveInput}
            value={addressLabel}
            onChangeText={setAddressLabel}
            placeholder="Nom de l'adresse (optionnel) : ex. Maison, Dépôt"
            placeholderTextColor={COLORS.textSecondary}
            maxLength={SAVED_ADDRESS_LABEL_MAX}
          />
          <View style={styles.saveRow}>
            {(['pickup', 'dropoff'] as const).map((which) => (
              <TouchableOpacity
                key={which}
                style={[styles.saveButton, savedWhich[which] && styles.saveButtonDone]}
                onPress={() => handleSaveAddress(which)}
                disabled={savedWhich[which] || savingWhich !== null}
              >
                {savingWhich === which ? (
                  <ActivityIndicator size="small" color={COLORS.primary} />
                ) : (
                  <Text style={styles.saveButtonText}>
                    {savedWhich[which]
                      ? '✅ Enregistrée'
                      : which === 'pickup'
                        ? 'Adresse de chargement'
                        : 'Adresse de livraison'}
                  </Text>
                )}
              </TouchableOpacity>
            ))}
          </View>
        </View>
      )}

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
  saveBox: {
    width: '100%',
    backgroundColor: COLORS.surface,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.lg,
  },
  saveTitle: { fontSize: 15, fontWeight: '700', color: COLORS.text },
  saveHelp: { fontSize: 12, color: COLORS.textSecondary, marginBottom: SPACING.sm },
  saveInput: {
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
    color: COLORS.text,
    fontSize: 14,
    marginBottom: SPACING.sm,
  },
  saveRow: { flexDirection: 'row', gap: SPACING.sm },
  saveButton: {
    flex: 1,
    minHeight: 44,
    borderRadius: BORDER_RADIUS.md,
    backgroundColor: COLORS.primary + '15',
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.sm,
  },
  saveButtonDone: { backgroundColor: COLORS.success + '20' },
  saveButtonText: { color: COLORS.primary, fontWeight: '600', fontSize: 14, textAlign: 'center' },
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
