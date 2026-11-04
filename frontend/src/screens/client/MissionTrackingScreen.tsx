import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  AppState,
} from 'react-native';
import { showMessage, confirmAction } from '../../utils/dialogs';
import type { RealtimeChannel } from '@supabase/supabase-js';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import {
  subscribeToMissionUpdates,
  subscribeToDriverLocation,
  unsubscribeChannel,
} from '../../services/realtimeService';
import {
  cancelMission,
  cancelMissionByClient,
  expireMission,
  getMissionById,
  getMissionExactLocation,
  getMissionDriverIdentity,
} from '../../services/missionService';
import { cleanServerMessage } from '../../services/settingsService';
import type { Mission, ClientCancelReason } from '../../services/missionService';
import CancelReasonModal from '../../components/CancelReasonModal';
import { formatCargo } from '../../utils/cargo';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { supabase } from '../../lib/supabaseClient';
import BackButton from '../../components/BackButton';

type RootStackParamList = {
  MissionTracking: { mission: Record<string, unknown> };
  MissionOffer: { missionId: string };
  Rating: { mission: Record<string, unknown> };
  VoiceChat: { mission: Record<string, unknown> };
  ClientHome: { clientProfileId?: string };
};

type Props = NativeStackScreenProps<RootStackParamList, 'MissionTracking'>;

const EXPIRATION_CHECK_INTERVAL_MS = 30000;

export default function MissionTrackingScreen({ route, navigation }: Props) {
  const initialMission = route.params.mission as unknown as Mission;
  const [mission, setMission] = useState<Mission>(initialMission);
  const missionChannelRef = useRef<RealtimeChannel | null>(null);
  const locationChannelRef = useRef<RealtimeChannel | null>(null);

  const handleMissionUpdate = useCallback(
    (updated: Record<string, unknown>) => {
      const updatedMission = updated as unknown as Mission;
      setMission(updatedMission);

      if (updatedMission.status === 'completed') {
        setTimeout(() => {
          navigation.replace('Rating', { mission: updated });
        }, 2000);
      }
    },
    [navigation]
  );

  useEffect(() => {
    missionChannelRef.current = subscribeToMissionUpdates(
      mission.id,
      handleMissionUpdate
    );

    return () => {
      unsubscribeChannel(missionChannelRef.current);
      unsubscribeChannel(locationChannelRef.current);
    };
  }, [mission.id, handleMissionUpdate]);

  // A1 (verification A5) : au retour de l'application au premier plan, la
  // mission est relue (l'ecoute en direct est interrompue en arriere-plan)
  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state !== 'active') return;
      getMissionById(mission.id).then((result) => {
        if (result.success && result.mission) {
          handleMissionUpdate(result.mission as unknown as Record<string, unknown>);
        }
      });
    });
    return () => sub.remove();
  }, [mission.id, handleMissionUpdate]);

  useEffect(() => {
    if (mission.driver_id && !locationChannelRef.current) {
      locationChannelRef.current = subscribeToDriverLocation(
        mission.driver_id,
        (driver) => {
          console.log('[FTM-DEBUG] Realtime - Driver location update received', driver);
        }
      );
    }
  }, [mission.driver_id]);

  useEffect(() => {
    if (mission.status !== 'pending' || !mission.scheduled_pickup_time) {
      return;
    }

    const checkExpiration = async () => {
      const scheduledTime = new Date(mission.scheduled_pickup_time as string).getTime();
      const now = Date.now();

      if (now > scheduledTime) {
        console.log('[FTM-DEBUG] Mission - Detected expiration client-side', {
          missionId: mission.id,
          scheduledTime: mission.scheduled_pickup_time,
        });
        const result = await expireMission(mission.id);
        if (result.success && result.mission) {
          setMission(result.mission);
        }
      }
    };

    checkExpiration();
    const interval = setInterval(checkExpiration, EXPIRATION_CHECK_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [mission.status, mission.scheduled_pickup_time, mission.id]);

  // A1 (correction 27) : acces aux offres depuis l'ecran de suivi (avant, seulement
  // en touchant la notification). Nombre d'offres relu toutes les 10 secondes.
  const [offersCount, setOffersCount] = useState(0);

  // A1 (migration 072) : la fiche de la mission ne contient plus que
  // « quartier, ville » ; le client relit ses adresses exactes dans la partie
  // verrouillee. Prenom et plaque du chauffeur : au prelevement de la commission.
  const [exactPickup, setExactPickup] = useState<string | null>(null);
  const [exactDropoff, setExactDropoff] = useState<string | null>(null);
  const [driverIdentity, setDriverIdentity] = useState<{ first_name: string; license_plate: string } | null>(null);

  useEffect(() => {
    let active = true;
    getMissionExactLocation(mission.id).then(({ location }) => {
      if (!active || !location) return;
      setExactPickup(location.pickup_address);
      setExactDropoff(location.dropoff_address);
    });
    return () => {
      active = false;
    };
  }, [mission.id]);

  useEffect(() => {
    if (!mission.driver_id || !mission.commission_charged_at) {
      setDriverIdentity(null);
      return;
    }
    let active = true;
    getMissionDriverIdentity(mission.id).then(({ identity }) => {
      if (active) setDriverIdentity(identity);
    });
    return () => {
      active = false;
    };
  }, [mission.id, mission.driver_id, mission.commission_charged_at]);

  const driverIdentityText = driverIdentity
    ? `👤 ${driverIdentity.first_name}  ·  🚚 ${driverIdentity.license_plate}`
    : null;

  useEffect(() => {
    if (mission.status !== 'pending') return;
    let cancelled = false;
    const readCount = async () => {
      const { count, error } = await supabase
        .from('mission_offers')
        .select('id', { count: 'exact', head: true })
        .eq('mission_id', mission.id)
        .eq('status', 'pending');
      if (!cancelled && !error) setOffersCount(count ?? 0);
    };
    readCount();
    const interval = setInterval(readCount, 10000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [mission.status, mission.id]);

  // A1 (migration 074) : messagerie vocale ouverte au prelevement de la commission
  const voiceChannelOpen =
    (mission.status === 'accepted' || mission.status === 'in_progress') &&
    !!mission.driver_id &&
    !!mission.commission_charged_at;

  // A1 (migration 076) : mission conclue : fenetre avec la raison de
  // l'annulation (obligatoire) et le rappel de l'annulation tardive (073).
  // Mission en attente (pas encore d'accord) : simple confirmation.
  const [cancelModal, setCancelModal] = useState<{ lateHours: number | null } | null>(null);

  const handleCancel = async () => {
    if (mission.status === 'accepted') {
      const { data } = await supabase.rpc('get_client_cancel_terms', { p_mission_id: mission.id });
      const terms = Array.isArray(data) ? (data[0] as { late?: boolean; hours?: number } | undefined) : undefined;
      setCancelModal({ lateHours: terms?.late ? Number(terms.hours) : null });
      return;
    }
    const confirmed = await confirmAction('Annuler la mission', 'Êtes-vous sûr de vouloir annuler ?', {
      confirmLabel: 'Oui, annuler',
      cancelLabel: 'Non',
      destructive: true,
    });
    if (!confirmed) return;
    const result = await cancelMission(mission.id, mission.client_id ?? '', 'client');
    if (result.error) showMessage('Erreur', cleanServerMessage(result.error));
  };

  const confirmCancelWithReason = async (reason: ClientCancelReason, text: string): Promise<string | null> => {
    const result = await cancelMissionByClient(mission.id, reason, text);
    if (result.error) return cleanServerMessage(result.error);
    setCancelModal(null);
    if (result.mission) setMission(result.mission);
    return null;
  };

  const renderStatus = () => {
    switch (mission.status) {
      case 'pending':
        return (
          <View style={styles.statusContainer}>
            <ActivityIndicator size="large" color={COLORS.primary} />
            <Text style={styles.statusTitle}>Recherche d'un chauffeur...</Text>
            <Text style={styles.missionNumber}>N° {mission.mission_number}</Text>
            <View style={styles.addressCard}>
              <Text style={styles.addressLabel}>📍 Départ</Text>
              <Text style={styles.addressText}>{exactPickup ?? mission.pickup_address}</Text>
              <Text style={styles.addressLabel}>🏁 Arrivée</Text>
              <Text style={styles.addressText}>{exactDropoff ?? mission.dropoff_address}</Text>
            </View>
            {/* A1 (correction 14) : une distance de 0 s'affichait "0" hors d'un <Text> : plantage sur telephone */}
            {!!mission.estimated_distance_km && (
              <Text style={styles.distanceText}>
                Distance estimée : ~{mission.estimated_distance_km} km
              </Text>
            )}
            {/* A1 F6 : poids et volume indiques par le client */}
            {formatCargo(mission.cargo_weight_kg, mission.cargo_volume_m3) && (
              <Text style={styles.distanceText}>
                Chargement : {formatCargo(mission.cargo_weight_kg, mission.cargo_volume_m3)}
              </Text>
            )}
            <TouchableOpacity
              style={styles.callButton}
              onPress={() => navigation.navigate('MissionOffer', { missionId: mission.id })}
            >
              <Text style={styles.callButtonText}>
                {offersCount > 0 ? `💰 Voir les offres (${offersCount})` : '💰 Voir les offres'}
              </Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.cancelButton} onPress={handleCancel}>
              <Text style={styles.cancelButtonText}>Annuler</Text>
            </TouchableOpacity>
          </View>
        );

      case 'accepted':
        return (
          <View style={styles.statusContainer}>
            <Text style={styles.successIcon}>✅</Text>
            <Text style={styles.statusTitle}>Chauffeur trouvé !</Text>
            <View style={styles.driverCard}>
              <Text style={styles.driverName}>Chauffeur assigné</Text>
              {driverIdentityText ? (
                <Text style={styles.driverInfo}>{driverIdentityText}</Text>
              ) : (
                <Text style={styles.driverInfo}>
                  Son prénom et sa plaque s’afficheront 24 h avant le chargement.
                </Text>
              )}
              <Text style={styles.driverInfo}>Mission N° {mission.mission_number}</Text>
              {formatCargo(mission.cargo_weight_kg, mission.cargo_volume_m3) && (
                <Text style={styles.driverInfo}>
                  Chargement : {formatCargo(mission.cargo_weight_kg, mission.cargo_volume_m3)}
                </Text>
              )}
            </View>
            {/* A1 (correction 17) : pas d'appel telephonique, messages vocaux uniquement */}
            {voiceChannelOpen && (
              <TouchableOpacity
                style={styles.callButton}
                onPress={() => navigation.navigate('VoiceChat', { mission: mission as unknown as Record<string, unknown> })}
              >
                <Text style={styles.callButtonText}>🎤 Messages vocaux</Text>
              </TouchableOpacity>
            )}
            <TouchableOpacity style={styles.cancelButton} onPress={handleCancel}>
              <Text style={styles.cancelButtonText}>Annuler</Text>
            </TouchableOpacity>
          </View>
        );

      case 'in_progress':
        return (
          <View style={styles.statusContainer}>
            <Text style={styles.statusIcon}>🚚</Text>
            <Text style={styles.statusTitle}>Mission en cours</Text>
            <View style={styles.addressCard}>
              <Text style={styles.addressLabel}>🏁 Destination</Text>
              <Text style={styles.addressText}>{exactDropoff ?? mission.dropoff_address}</Text>
            </View>
            {driverIdentityText && <Text style={styles.distanceText}>{driverIdentityText}</Text>}
            {voiceChannelOpen && (
              <TouchableOpacity
                style={styles.callButton}
                onPress={() => navigation.navigate('VoiceChat', { mission: mission as unknown as Record<string, unknown> })}
              >
                <Text style={styles.callButtonText}>🎤 Messages vocaux</Text>
              </TouchableOpacity>
            )}
          </View>
        );

      case 'completed':
        return (
          <View style={styles.statusContainer}>
            <Text style={styles.successIcon}>✅</Text>
            <Text style={styles.statusTitle}>Mission terminée !</Text>
            <Text style={styles.subText}>Redirection vers l'évaluation...</Text>
          </View>
        );

      case 'cancelled_driver':
        return (
          <View style={styles.statusContainer}>
            <Text style={styles.errorIcon}>❌</Text>
            <Text style={styles.statusTitle}>Mission annulée par le chauffeur</Text>
            <TouchableOpacity
              style={styles.primaryButton}
              onPress={() => navigation.navigate('ClientHome', { clientProfileId: mission.client_id ?? '' })}
            >
              <Text style={styles.primaryButtonText}>Créer une nouvelle mission</Text>
            </TouchableOpacity>
          </View>
        );

      // A1 (correction 26) : l'annulation par le client n'avait pas d'affichage (ecran blanc).
      case 'cancelled_client':
        return (
          <View style={styles.statusContainer}>
            <Text style={styles.errorIcon}>❌</Text>
            <Text style={styles.statusTitle}>Mission annulée</Text>
            <Text style={styles.subText}>Vous avez annulé cette mission.</Text>
            <TouchableOpacity
              style={styles.primaryButton}
              onPress={() => navigation.navigate('ClientHome', { clientProfileId: mission.client_id ?? '' })}
            >
              <Text style={styles.primaryButtonText}>Créer une nouvelle mission</Text>
            </TouchableOpacity>
          </View>
        );

      case 'expired':
        return (
          <View style={styles.statusContainer}>
            <Text style={styles.errorIcon}>⏱️</Text>
            {/* A1 F9 : une mission conclue (avec chauffeur) non demarree est
                cloturee par le serveur (migration 071) */}
            <Text style={styles.statusTitle}>{mission.driver_id ? 'Mission non réalisée' : 'Mission expirée'}</Text>
            <Text style={styles.subText}>
              {mission.driver_id
                ? 'La mission n’a pas démarré à l’heure prévue et a été clôturée.'
                : "Aucun accord n'a été conclu avec un chauffeur avant l'heure prévue."}
            </Text>
            <TouchableOpacity
              style={styles.primaryButton}
              onPress={() => navigation.navigate('ClientHome', { clientProfileId: mission.client_id ?? '' })}
            >
              <Text style={styles.primaryButtonText}>Créer une nouvelle mission</Text>
            </TouchableOpacity>
          </View>
        );

      default:
        return null;
    }
  };

  // A1 : bouton « Retour » vers l'accueil du client (constat du 30/10/2026)
  return (
    <View style={styles.screen}>
      <BackButton />
      <View style={styles.container}>{renderStatus()}</View>
      {cancelModal && (
        <CancelReasonModal
          lateHours={cancelModal.lateHours}
          onConfirm={confirmCancelWithReason}
          onClose={() => setCancelModal(null)}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: COLORS.background },
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
    justifyContent: 'center',
    padding: SPACING.lg,
  },
  statusContainer: { alignItems: 'center', gap: SPACING.md },
  statusTitle: {
    fontSize: 22,
    fontWeight: '700',
    color: COLORS.text,
    textAlign: 'center',
  },
  missionNumber: { fontSize: 14, color: COLORS.textSecondary },
  statusIcon: { fontSize: 48 },
  successIcon: { fontSize: 48 },
  errorIcon: { fontSize: 48 },
  addressCard: {
    width: '100%',
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    gap: SPACING.xs,
  },
  addressLabel: { fontSize: 12, fontWeight: '700', color: COLORS.textSecondary, letterSpacing: 1 },
  addressText: { fontSize: 15, color: COLORS.text, marginBottom: SPACING.xs },
  distanceText: { fontSize: 14, color: COLORS.textSecondary },
  driverCard: {
    width: '100%',
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
    gap: SPACING.xs,
  },
  driverName: { fontSize: 18, fontWeight: '700', color: COLORS.text },
  driverInfo: { fontSize: 14, color: COLORS.textSecondary },
  callButton: {
    width: '100%',
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
  },
  callButtonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  cancelButton: {
    width: '100%',
    borderWidth: 1,
    borderColor: COLORS.alert ?? '#E53E3E',
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
  },
  cancelButtonText: { color: COLORS.alert ?? '#E53E3E', fontSize: 16, fontWeight: '600' },
  primaryButton: {
    width: '100%',
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    marginTop: SPACING.md,
  },
  primaryButtonText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  subText: { fontSize: 14, color: COLORS.textSecondary },
});
