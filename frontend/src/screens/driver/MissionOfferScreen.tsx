import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, TouchableOpacity, TextInput, StyleSheet } from 'react-native';
import type { RealtimeChannel } from '@supabase/supabase-js';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import {
  counterMissionOffer,
  acceptMissionOffer,
  rejectOfferAcceptance,
  submitClientCounterOffer,
} from '../../services/missionService';
import type { MissionOffer } from '../../services/missionService';
import {
  subscribeToMissionOffers,
  subscribeToDriverOffers,
  unsubscribeChannel,
} from '../../services/realtimeService';

// ─── DÉRIVATION D'ÉTAT PURE ─────────────────────────────────────────────────

type OfferDisplayState =
  | { kind: 'awaiting_response' }
  | { kind: 'can_respond_round2'; price: number }
  | { kind: 'confirmation_pending'; price: number }
  | { kind: 'waiting_other_confirmation' }
  | { kind: 'not_selected' }
  | { kind: 'accepted' };

interface ClientOfferView {
  offer: MissionOffer;
  state: OfferDisplayState;
}

interface ClientOffersDerivedState {
  views: ClientOfferView[];
  isAnyAcceptancePending: boolean;
  isMissionResolved: boolean;
}

function deriveClientOffersState(offers: MissionOffer[]): ClientOffersDerivedState {
  const isAnyAcceptancePending = offers.some(
    (o) => o.status === 'pending' && o.client_accepted === true
  );
  const isMissionResolved = offers.some((o) => o.status === 'accepted');

  const views: ClientOfferView[] = offers.map((offer) => {
    if (offer.status === 'accepted') {
      return { offer, state: { kind: 'accepted' } };
    }
    if (offer.status === 'not_selected') {
      return { offer, state: { kind: 'not_selected' } };
    }
    if (offer.client_accepted && !offer.driver_accepted) {
      return { offer, state: { kind: 'waiting_other_confirmation' } };
    }
    if (offer.driver_accepted && !offer.client_accepted) {
      return { offer, state: { kind: 'confirmation_pending', price: offer.offered_price } };
    }
    return { offer, state: { kind: 'awaiting_response' } };
  });

  return { views, isAnyAcceptancePending, isMissionResolved };
}

function deriveDriverOfferState(offer: MissionOffer | null): OfferDisplayState | null {
  if (!offer) return null;

  if (offer.status === 'accepted') {
    return { kind: 'accepted' };
  }
  if (offer.status === 'not_selected') {
    return { kind: 'not_selected' };
  }
  if (offer.driver_accepted && !offer.client_accepted) {
    return { kind: 'waiting_other_confirmation' };
  }
  if (offer.client_accepted && !offer.driver_accepted) {
    return { kind: 'confirmation_pending', price: offer.offered_price };
  }
  if (offer.round_number === 2) {
    return { kind: 'can_respond_round2', price: offer.offered_price };
  }
  return { kind: 'awaiting_response' };
}

// ─── COMPOSANT ───────────────────────────────────────────────────────────────

interface Props {
  missionId: string;
  role: 'client' | 'driver';
  driverId?: string;
  onMissionResolved: () => void;
}

export default function MissionOfferScreen({ missionId, role, driverId, onMissionResolved }: Props) {
  const [clientOffers, setClientOffers] = useState<MissionOffer[]>([]);
  const [driverOffer, setDriverOffer] = useState<MissionOffer | null>(null);
  const [counterPrice, setCounterPrice] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const channelRef = React.useRef<RealtimeChannel | null>(null);

  useEffect(() => {
    if (role === 'client') {
      channelRef.current = subscribeToMissionOffers(missionId, (offer) => {
        const updated = offer as unknown as MissionOffer;
        setClientOffers((prev) => {
          const idx = prev.findIndex((o) => o.id === updated.id);
          if (idx === -1) return [...prev, updated];
          const next = [...prev];
          next[idx] = updated;
          return next;
        });
      });
    } else if (role === 'driver' && driverId) {
      channelRef.current = subscribeToDriverOffers(driverId, (offer) => {
        const updated = offer as unknown as MissionOffer;
        if (updated.mission_id === missionId) {
          setDriverOffer(updated);
        }
      });
    }

    return () => {
      unsubscribeChannel(channelRef.current);
    };
  }, [role, missionId, driverId]);

  useEffect(() => {
    const clientState = role === 'client' ? deriveClientOffersState(clientOffers) : null;
    if (clientState?.isMissionResolved) {
      onMissionResolved();
    }
    const driverState = role === 'driver' ? deriveDriverOfferState(driverOffer) : null;
    if (driverState?.kind === 'accepted') {
      onMissionResolved();
    }
  }, [role, clientOffers, driverOffer, onMissionResolved]);

  const handleClientAccept = useCallback(async (offerId: string) => {
    setIsSubmitting(true);
    setErrorMessage(null);
    const result = await acceptMissionOffer(offerId, 'client');
    if (result.error) setErrorMessage(result.error);
    setIsSubmitting(false);
  }, []);

  const handleClientCounter = useCallback(async () => {
    setErrorMessage(null);
    const price = Number(counterPrice);
    if (!price || price <= 0) {
      setErrorMessage('Veuillez saisir un prix valide.');
      return;
    }
    setIsSubmitting(true);
    const result = await submitClientCounterOffer(missionId, price);
    if (result.error) setErrorMessage(result.error);
    setCounterPrice('');
    setIsSubmitting(false);
  }, [missionId, counterPrice]);

  const handleClientConfirm = useCallback(async (offerId: string) => {
    setIsSubmitting(true);
    setErrorMessage(null);
    const result = await acceptMissionOffer(offerId, 'client');
    if (result.error) setErrorMessage(result.error);
    setIsSubmitting(false);
  }, []);

  const handleClientReject = useCallback(async (offerId: string) => {
    setIsSubmitting(true);
    setErrorMessage(null);
    const result = await rejectOfferAcceptance(offerId, 'client');
    if (result.error) setErrorMessage(result.error);
    setIsSubmitting(false);
  }, []);

  const handleDriverAccept = useCallback(async (offerId: string) => {
    setIsSubmitting(true);
    setErrorMessage(null);
    const result = await acceptMissionOffer(offerId, 'driver');
    if (result.error) setErrorMessage(result.error);
    setIsSubmitting(false);
  }, []);

  const handleDriverCounter = useCallback(async (offerId: string) => {
    setErrorMessage(null);
    const price = Number(counterPrice);
    if (!price || price <= 0) {
      setErrorMessage('Veuillez saisir un prix valide.');
      return;
    }
    setIsSubmitting(true);
    const result = await counterMissionOffer(offerId, price, 'driver');
    if (result.error) setErrorMessage(result.error);
    setCounterPrice('');
    setIsSubmitting(false);
  }, [counterPrice]);

  const handleDriverConfirm = useCallback(async (offerId: string) => {
    setIsSubmitting(true);
    setErrorMessage(null);
    const result = await acceptMissionOffer(offerId, 'driver');
    if (result.error) setErrorMessage(result.error);
    setIsSubmitting(false);
  }, []);

  const handleDriverReject = useCallback(async (offerId: string) => {
    setIsSubmitting(true);
    setErrorMessage(null);
    const result = await rejectOfferAcceptance(offerId, 'driver');
    if (result.error) setErrorMessage(result.error);
    setIsSubmitting(false);
  }, []);

  const clientState = role === 'client' ? deriveClientOffersState(clientOffers) : null;
  const driverState = role === 'driver' ? deriveDriverOfferState(driverOffer) : null;

  return (
    <View style={styles.container}>
      {errorMessage && (
        <View style={styles.errorBanner}>
          <Text style={styles.errorText}>{errorMessage}</Text>
        </View>
      )}

      {role === 'client' && clientState && (
        <View style={styles.section}>
          <Text style={styles.title}>Offres reçues</Text>
          {clientState.views.length === 0 && (
            <Text style={styles.emptyText}>En attente d'offres de chauffeurs…</Text>
          )}
          {clientState.views.map(({ offer, state }) => (
            <View key={offer.id} style={styles.offerCard}>
              <Text style={styles.offerPrice}>{offer.offered_price} DH</Text>

              {state.kind === 'awaiting_response' && (
                <TouchableOpacity
                  style={[styles.acceptButton, clientState.isAnyAcceptancePending && styles.buttonDisabled]}
                  onPress={() => handleClientAccept(offer.id)}
                  disabled={isSubmitting || clientState.isAnyAcceptancePending}
                >
                  <Text style={styles.acceptButtonText}>Accepter ce prix</Text>
                </TouchableOpacity>
              )}

              {state.kind === 'waiting_other_confirmation' && (
                <Text style={styles.waitingText}>En attente de confirmation du chauffeur…</Text>
              )}

              {state.kind === 'confirmation_pending' && (
                <View style={styles.actionRow}>
                  <TouchableOpacity
                    style={styles.acceptButton}
                    onPress={() => handleClientConfirm(offer.id)}
                    disabled={isSubmitting}
                  >
                    <Text style={styles.acceptButtonText}>Confirmer</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={styles.refuseButton}
                    onPress={() => handleClientReject(offer.id)}
                    disabled={isSubmitting}
                  >
                    <Text style={styles.refuseButtonText}>Refuser</Text>
                  </TouchableOpacity>
                </View>
              )}

              {state.kind === 'not_selected' && (
                <Text style={styles.notSelectedText}>Offre non retenue</Text>
              )}
            </View>
          ))}

          {!clientState.isAnyAcceptancePending && clientState.views.length > 0 && (
            <View style={styles.counterSection}>
              <TextInput
                style={styles.priceInput}
                keyboardType="numeric"
                placeholder="Nouveau prix (DH)"
                value={counterPrice}
                onChangeText={setCounterPrice}
              />
              <TouchableOpacity
                style={styles.counterButton}
                onPress={handleClientCounter}
                disabled={isSubmitting}
              >
                <Text style={styles.counterButtonText}>Proposer ce prix à tous les chauffeurs</Text>
              </TouchableOpacity>
            </View>
          )}
        </View>
      )}

      {role === 'driver' && driverState && (
        <View style={styles.section}>
          <Text style={styles.title}>Votre offre</Text>

          {driverState.kind === 'awaiting_response' && (
            <Text style={styles.waitingText}>En attente de réponse du client…</Text>
          )}

          {driverState.kind === 'can_respond_round2' && (
            <View>
              <Text style={styles.offerPrice}>Le client propose {driverState.price} DH</Text>
              <View style={styles.actionRow}>
                <TouchableOpacity
                  style={styles.acceptButton}
                  onPress={() => driverOffer && handleDriverAccept(driverOffer.id)}
                  disabled={isSubmitting}
                >
                  <Text style={styles.acceptButtonText}>Accepter</Text>
                </TouchableOpacity>
              </View>
              <View style={styles.counterSection}>
                <TextInput
                  style={styles.priceInput}
                  keyboardType="numeric"
                  placeholder="Nouveau prix (DH)"
                  value={counterPrice}
                  onChangeText={setCounterPrice}
                />
                <TouchableOpacity
                  style={styles.counterButton}
                  onPress={() => driverOffer && handleDriverCounter(driverOffer.id)}
                  disabled={isSubmitting}
                >
                  <Text style={styles.counterButtonText}>Reproposer un prix</Text>
                </TouchableOpacity>
              </View>
            </View>
          )}

          {driverState.kind === 'confirmation_pending' && (
            <View>
              <Text style={styles.offerPrice}>{driverState.price} DH</Text>
              <View style={styles.actionRow}>
                <TouchableOpacity
                  style={styles.acceptButton}
                  onPress={() => driverOffer && handleDriverConfirm(driverOffer.id)}
                  disabled={isSubmitting}
                >
                  <Text style={styles.acceptButtonText}>Confirmer</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.refuseButton}
                  onPress={() => driverOffer && handleDriverReject(driverOffer.id)}
                  disabled={isSubmitting}
                >
                  <Text style={styles.refuseButtonText}>Refuser</Text>
                </TouchableOpacity>
              </View>
            </View>
          )}

          {driverState.kind === 'waiting_other_confirmation' && (
            <Text style={styles.waitingText}>En attente de confirmation du client…</Text>
          )}

          {driverState.kind === 'not_selected' && (
            <Text style={styles.notSelectedText}>Cette offre n'a pas été retenue.</Text>
          )}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background, padding: SPACING.lg },
  section: { gap: SPACING.md },
  title: { fontSize: 18, fontWeight: '700', color: COLORS.text },
  emptyText: { color: COLORS.textSecondary, fontStyle: 'italic' },
  offerCard: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    gap: SPACING.sm,
  },
  offerPrice: { fontSize: 18, fontWeight: '700', color: COLORS.text },
  actionRow: { flexDirection: 'row', gap: SPACING.sm },
  acceptButton: {
    flex: 1,
    backgroundColor: COLORS.success ?? '#38A169',
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
  },
  acceptButtonText: { color: '#fff', fontSize: 15, fontWeight: '700' },
  refuseButton: {
    flex: 1,
    backgroundColor: (COLORS.alert ?? '#E53E3E') + '15',
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.alert ?? '#E53E3E',
  },
  refuseButtonText: { color: COLORS.alert ?? '#E53E3E', fontSize: 15, fontWeight: '700' },
  buttonDisabled: { opacity: 0.5 },
  waitingText: { color: COLORS.textSecondary },
  notSelectedText: { color: COLORS.textSecondary, fontStyle: 'italic' },
  counterSection: { gap: SPACING.sm, marginTop: SPACING.sm },
  priceInput: {
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
    fontSize: 16,
  },
  counterButton: {
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
  },
  counterButtonText: { color: '#fff', fontSize: 15, fontWeight: '700' },
  errorBanner: {
    backgroundColor: (COLORS.alert ?? '#E53E3E') + '15',
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
    marginBottom: SPACING.md,
  },
  errorText: { color: COLORS.alert ?? '#E53E3E' },
});
