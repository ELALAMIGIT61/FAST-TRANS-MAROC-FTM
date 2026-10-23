import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Linking,
  Platform,
} from 'react-native';
import { showMessage, confirmAction } from '../../utils/dialogs';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { startMission, completeMission } from '../../services/missionService';
import { requestRefund } from '../../services/walletService';
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
      // Session 2.23 : le prelevement de la commission et l'annonce de la
      // messagerie sont faits par le serveur (tache planifiee, migration 054).
      setVoiceChannelOpen(isOpen);
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

  // A1 (correction 18) : les boutons « Ouvrir dans Maps » n'affichaient qu'un
  // message. Le point de chargement est ouvert par ses coordonnees (lues dans
  // la colonne geographique de la mission) ; la destination par son adresse
  // ecrite, plus fiable tant que ses coordonnees ne sont pas calculees (R1).
  const pointFromGeography = (value: unknown): { lat: number; lng: number } | null => {
    try {
      if (typeof value === 'string') {
        const wkt = value.match(/POINT\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s*\)/i);
        if (wkt) return { lng: Number(wkt[1]), lat: Number(wkt[2]) };
        if (/^[0-9a-f]+$/i.test(value) && value.length >= 42) {
          // Format EWKB hexadecimal renvoye par PostGIS (point avec SRID 4326)
          const bytes = new Uint8Array(value.length / 2);
          for (let i = 0; i < bytes.length; i++) bytes[i] = parseInt(value.substr(i * 2, 2), 16);
          const view = new DataView(bytes.buffer);
          const little = bytes[0] === 1;
          const type = view.getUint32(1, little);
          const offset = type & 0x20000000 ? 9 : 5;
          const lng = view.getFloat64(offset, little);
          const lat = view.getFloat64(offset + 8, little);
          if (Number.isFinite(lat) && Number.isFinite(lng)) return { lat, lng };
        }
      } else if (value && typeof value === 'object') {
        const coords = (value as { coordinates?: number[] }).coordinates;
        if (coords && coords.length >= 2) return { lng: coords[0], lat: coords[1] };
      }
    } catch (err: unknown) {
      console.log('[FTM-DEBUG] Maps - Geography decode error', { err: String(err) });
    }
    return null;
  };

  const openMapsAddress = (address: string, city: string) => {
    const query = encodeURIComponent([address, city, 'Maroc'].filter(Boolean).join(', '));
    Linking.openURL(`https://www.google.com/maps/dir/?api=1&destination=${query}`);
  };

  const openPickupInMaps = () => {
    const raw = mission as unknown as Record<string, unknown>;
    const point = pointFromGeography(raw.pickup_location);
    if (point) openMaps(point.lat, point.lng);
    else openMapsAddress(String(raw.pickup_address ?? ''), String(raw.pickup_city ?? ''));
  };

  const openDropoffInMaps = () => {
    const raw = mission as unknown as Record<string, unknown>;
    openMapsAddress(String(raw.dropoff_address ?? ''), String(raw.dropoff_city ?? ''));
  };

  const handleStart = async () => {
    const result = await startMission(mission.id, mission.driver_id ?? '');
    if (result.error) {
      showMessage('Erreur', result.error);
    } else if (result.mission) {
      setMission(result.mission);
    }
  };

  const handleComplete = async () => {
    const confirmed = await confirmAction('Terminer la mission', 'Confirmer la livraison ?');
    if (!confirmed) return;
    const result = await completeMission(mission.id, mission.driver_id ?? '');
    if (result.error) {
      showMessage('Erreur', result.error);
    } else {
      // A1 (correction 21) : revenir a l'accueil existant au lieu d'en creer un 2e
      // (deux accueils = deux abonnements temps reel identiques = plantage).
      navigation.navigate('DriverHome', {
        driverId: mission.driver_id ?? '',
        vehicleCategory: mission.vehicle_category,
      });
    }
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
          onPress={openPickupInMaps}
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
          onPress={openDropoffInMaps}
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
      showMessage('Erreur', result.error);
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
