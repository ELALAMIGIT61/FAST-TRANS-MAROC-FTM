import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Linking,
  Alert,
  Platform,
} from 'react-native';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { startMission, completeMission, getDriverProfileId, chargeCommissionAnticipated } from '../../services/missionService';
import { requestRefund } from '../../services/walletService';
import { notifyVoiceChannelOpened } from '../../services/notificationTemplates';
import type { Mission } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type RootStackParamList = {
  MissionActive: { mission: Record<string, unknown> };
  VoiceChat: { mission: Record<string, unknown> };
  DriverHome: { driverId: string; vehicleCategory: string };
};

type Props = NativeStackScreenProps<RootStackParamList, 'MissionActive'>;

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return [h, m, s].map((v) => String(v).padStart(2, '0')).join(':');
}

const VOICE_CHANNEL_CHECK_INTERVAL_MS = 30000;
const VOICE_CHANNEL_OPEN_BEFORE_MS = 24 * 60 * 60 * 1000;

export default function MissionActiveScreen({ route, navigation }: Props) {
  const initialMission = route.params.mission as unknown as Mission;
  const [mission, setMission] = useState<Mission>(initialMission);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [isRequestingRefund, setIsRequestingRefund] = useState(false);
  const [refundRequested, setRefundRequested] = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    if (mission.status === 'in_progress' && mission.actual_pickup_time) {
      const start = new Date(mission.actual_pickup_time).getTime();
      timerRef.current = setInterval(() => {
        setElapsedSeconds(Math.floor((Date.now() - start) / 1000));
      }, 1000);
    }
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [mission.status, mission.actual_pickup_time]);

  const [voiceChannelOpen, setVoiceChannelOpen] = useState(false);
  const voiceChannelNotifiedRef = useRef(false);

  useEffect(() => {
    const eligibleStatus = mission.status === 'accepted' || mission.status === 'in_progress';
    if (!eligibleStatus || !mission.scheduled_pickup_time) {
      setVoiceChannelOpen(false);
      return;
    }

    const checkVoiceChannelWindow = () => {
      const scheduledTime = new Date(mission.scheduled_pickup_time as string).getTime();
      const openAt = scheduledTime - VOICE_CHANNEL_OPEN_BEFORE_MS;
      const isOpen = Date.now() >= openAt;
      setVoiceChannelOpen(isOpen);
      if (isOpen && !voiceChannelNotifiedRef.current) {
        voiceChannelNotifiedRef.current = true;
        if (mission.driver_id) {
          getDriverProfileId(mission.driver_id).then((result) => {
            if (result.success && result.profileId) {
              notifyVoiceChannelOpened(result.profileId, {
                id: mission.id,
                mission_number: mission.mission_number,
                scheduled_pickup_time: mission.scheduled_pickup_time as string,
              });
            }
          });
        }
        chargeCommissionAnticipated(mission.id).then((result) => {
          if (result.error) {
            console.log('[FTM-DEBUG] MissionActive - Anticipated commission charge failed', { error: result.error });
          }
        });
      }
    };

    checkVoiceChannelWindow();
    const interval = setInterval(checkVoiceChannelWindow, VOICE_CHANNEL_CHECK_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [mission.status, mission.scheduled_pickup_time]);

  const openMaps = (lat: number, lng: number) => {
    const url =
      Platform.OS === 'ios'
        ? `maps://?daddr=${lat},${lng}`
        : `https://maps.google.com/?daddr=${lat},${lng}`;
    Linking.openURL(url);
  };

  const handleStart = async () => {
    const result = await startMission(mission.id, mission.driver_id ?? '');
    if (result.error) {
      Alert.alert('Erreur', result.error);
    } else if (result.mission) {
      setMission(result.mission);
    }
  };

  const handleComplete = async () => {
    Alert.alert('Terminer la mission', 'Confirmer la livraison ?', [
      { text: 'Annuler', style: 'cancel' },
      {
        text: 'Confirmer',
        onPress: async () => {
          const result = await completeMission(mission.id, mission.driver_id ?? '');
          if (result.error) {
            Alert.alert('Erreur', result.error);
          } else {
            navigation.replace('DriverHome', {
              driverId: mission.driver_id ?? '',
              vehicleCategory: mission.vehicle_category,
            });
          }
        },
      },
    ]);
  };

  if (mission.status === 'accepted') {
    return (
      <View style={styles.container}>
        <Text style={styles.phaseTitle}>🚗 En route vers le client</Text>

        <View style={styles.addressCard}>
          <Text style={styles.addressLabel}>📍 Point de chargement</Text>
          <Text style={styles.addressText}>{mission.pickup_address}</Text>
          <Text style={styles.cityText}>{mission.pickup_city}</Text>
        </View>

        <TouchableOpacity
          style={styles.mapsButton}
          onPress={() => {
            /* pickup_location is a PostGIS geography — coordinates not directly available here */
            Alert.alert('Navigation', 'Ouvrez Google Maps avec les coordonnées du point de départ.');
          }}
        >
          <Text style={styles.mapsButtonText}>🗺 Ouvrir dans Maps</Text>
        </TouchableOpacity>

        {voiceChannelOpen && (
          <TouchableOpacity
            style={styles.mapsButton}
            onPress={() => navigation.navigate('VoiceChat', { mission: mission as unknown as Record<string, unknown> })}
          >
            <Text style={styles.mapsButtonText}>🎤 Messages vocaux</Text>
          </TouchableOpacity>
        )}
        <TouchableOpacity style={styles.primaryButton} onPress={handleStart}>
          <Text style={styles.primaryButtonText}>J'arrive — Démarrer la mission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  if (mission.status === 'in_progress') {
    return (
      <View style={styles.container}>
        <Text style={styles.phaseTitle}>🚚 Mission en cours</Text>
        <Text style={styles.missionNumber}>N° {mission.mission_number}</Text>

        <View style={styles.addressCard}>
          <Text style={styles.addressLabel}>🏁 Destination</Text>
          <Text style={styles.addressText}>{mission.dropoff_address}</Text>
          <Text style={styles.cityText}>{mission.dropoff_city}</Text>
        </View>

        <TouchableOpacity
          style={styles.mapsButton}
          onPress={() => {
            Alert.alert('Navigation', 'Ouvrez Google Maps avec les coordonnées de destination.');
          }}
        >
          <Text style={styles.mapsButtonText}>🗺 Ouvrir dans Maps</Text>
        </TouchableOpacity>

        <View style={styles.timerBox}>
          <Text style={styles.timerLabel}>⏱ Durée</Text>
          <Text style={styles.timerValue}>{formatDuration(elapsedSeconds)}</Text>
        </View>

        {voiceChannelOpen && (
          <TouchableOpacity
            style={styles.mapsButton}
            onPress={() => navigation.navigate('VoiceChat', { mission: mission as unknown as Record<string, unknown> })}
          >
            <Text style={styles.mapsButtonText}>🎤 Messages vocaux</Text>
          </TouchableOpacity>
        )}
        <TouchableOpacity style={styles.successButton} onPress={handleComplete}>
          <Text style={styles.successButtonText}>Mission terminée ✓</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const isCancelled = mission.status === 'cancelled_client' || mission.status === 'cancelled_driver';
  const canRequestRefund = isCancelled && !!mission.commission_charged_at;

  const handleRequestRefund = async () => {
    setIsRequestingRefund(true);
    const result = await requestRefund(mission.id, mission.driver_id as string);
    setIsRequestingRefund(false);
    if (result.error) {
      Platform.OS === 'web' ? window.alert(result.error) : Alert.alert('Erreur', result.error);
      return;
    }
    setRefundRequested(true);
  };

  return (
    <View style={styles.container}>
      <Text style={styles.phaseTitle}>Mission</Text>
      <Text style={styles.missionNumber}>Statut : {mission.status}</Text>
      {canRequestRefund && !refundRequested && (
        <TouchableOpacity
          style={styles.mapsButton}
          onPress={handleRequestRefund}
          disabled={isRequestingRefund}
        >
          <Text style={styles.mapsButtonText}>
            {isRequestingRefund ? 'Envoi...' : '💸 Demander un remboursement'}
          </Text>
        </TouchableOpacity>
      )}
      {refundRequested && (
        <Text style={styles.missionNumber}>Demande de remboursement envoyee.</Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
    padding: SPACING.lg,
    justifyContent: 'center',
    gap: SPACING.md,
  },
  phaseTitle: { fontSize: 24, fontWeight: '700', color: COLORS.text, textAlign: 'center' },
  missionNumber: { fontSize: 14, color: COLORS.textSecondary, textAlign: 'center' },
  addressCard: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    gap: SPACING.xs,
  },
  addressLabel: { fontSize: 11, fontWeight: '700', color: COLORS.textSecondary, letterSpacing: 1 },
  addressText: { fontSize: 16, color: COLORS.text, fontWeight: '500' },
  cityText: { fontSize: 14, color: COLORS.textSecondary },
  mapsButton: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  mapsButtonText: { color: COLORS.primary, fontSize: 15, fontWeight: '600' },
  primaryButton: {
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    minHeight: 52,
    justifyContent: 'center',
  },
  primaryButtonText: { color: '#fff', fontSize: 17, fontWeight: '700' },
  timerBox: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
    gap: 4,
  },
  timerLabel: { fontSize: 12, color: COLORS.textSecondary, fontWeight: '600' },
  timerValue: { fontSize: 32, fontWeight: '700', color: COLORS.text, fontVariant: ['tabular-nums'] },
  successButton: {
    backgroundColor: COLORS.success ?? '#38A169',
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    minHeight: 52,
    justifyContent: 'center',
  },
  successButtonText: { color: '#fff', fontSize: 17, fontWeight: '700' },
});
