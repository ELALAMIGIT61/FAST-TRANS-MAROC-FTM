import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import { showMessage, confirmAction } from '../../utils/dialogs';
import type { RealtimeChannel } from '@supabase/supabase-js';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import {
  subscribeToMissionUpdates,
  subscribeToDriverLocation,
  unsubscribeChannel,
} from '../../services/realtimeService';
import { cancelMission, expireMission } from '../../services/missionService';
import type { Mission } from '../../services/missionService';
import { formatCargo } from '../../utils/cargo';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { supabase } from '../../lib/supabaseClient';

type RootStackParamList = {
  MissionTracking: { mission: Record<string, unknown> };
  MissionOffer: { missionId: string };
  Rating: { mission: Record<string, unknown> };
  VoiceChat: { mission: Record<string, unknown> };
  ClientHome: { clientProfileId?: string };
};

type Props = NativeStackScreenProps<RootStackParamList, 'MissionTracking'>;

const EXPIRATION_CHECK_INTERVAL_MS = 30000;
const VOICE_CHANNEL_OPEN_BEFORE_MS = 24 * 60 * 60 * 1000;

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

  const [voiceChannelOpen, setVoiceChannelOpen] = useState(false);

  useEffect(() => {
    const eligibleStatus = mission.status === 'accepted' || mission.status === 'in_progress';
    if (!eligibleStatus || !mission.driver_id || !mission.scheduled_pickup_time) {
      setVoiceChannelOpen(false);
      return;
    }

    const checkVoiceChannelWindow = () => {
      const scheduledTime = new Date(mission.scheduled_pickup_time as string).getTime();
      const openAt = scheduledTime - VOICE_CHANNEL_OPEN_BEFORE_MS;
      const isOpen = Date.now() >= openAt;
      // Session 2.23 : l'annonce de la messagerie est faite par le serveur
      // (tache planifiee, migration 054).
      setVoiceChannelOpen(isOpen);
    };

    checkVoiceChannelWindow();
    const interval = setInterval(checkVoiceChannelWindow, EXPIRATION_CHECK_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [mission.status, mission.driver_id, mission.scheduled_pickup_time]);

  const handleCancel = async () => {
    const confirmed = await confirmAction('Annuler la mission', 'Êtes-vous sûr de vouloir annuler ?', {
      confirmLabel: 'Oui, annuler',
      cancelLabel: 'Non',
      destructive: true,
    });
    if (!confirmed) return;
    const result = await cancelMission(mission.id, mission.client_id ?? '', 'client');
    if (result.error) showMessage('Erreur', result.error);
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
              <Text style={styles.addressText}>{mission.pickup_address}</Text>
              <Text style={styles.addressLabel}>🏁 Arrivée</Text>
              <Text style={styles.addressText}>{mission.dropoff_address}</Text>
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
              <Text style={styles.addressText}>{mission.dropoff_address}</Text>
            </View>
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
            <Text style={styles.statusTitle}>Mission expirée</Text>
            <Text style={styles.subText}>Aucun chauffeur n'était disponible avant l'heure prévue.</Text>
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

  return <View style={styles.container}>{renderStatus()}</View>;
}

const styles = StyleSheet.create({
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
