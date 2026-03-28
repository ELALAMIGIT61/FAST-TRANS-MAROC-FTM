import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Linking,
  Alert,
} from 'react-native';
import type { RealtimeChannel } from '@supabase/supabase-js';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import {
  subscribeToMissionUpdates,
  subscribeToDriverLocation,
  unsubscribeChannel,
} from '../../services/realtimeService';
import { cancelMission } from '../../services/missionService';
import type { Mission } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type RootStackParamList = {
  MissionTracking: { mission: Record<string, unknown> };
  Rating: { mission: Record<string, unknown> };
  CreateMission: { clientProfileId: string };
};

type Props = NativeStackScreenProps<RootStackParamList, 'MissionTracking'>;

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

  const handleCancel = async () => {
    Alert.alert('Annuler la mission', 'Êtes-vous sûr de vouloir annuler ?', [
      { text: 'Non', style: 'cancel' },
      {
        text: 'Oui, annuler',
        style: 'destructive',
        onPress: async () => {
          const result = await cancelMission(mission.id, mission.client_id ?? '', 'client');
          if (result.error) Alert.alert('Erreur', result.error);
        },
      },
    ]);
  };

  const callDriver = () => {
    Linking.openURL(`tel:${(mission as unknown as Record<string, unknown>).driver_phone ?? ''}`);
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
            {mission.estimated_distance_km && (
              <Text style={styles.distanceText}>
                Distance estimée : ~{mission.estimated_distance_km} km
              </Text>
            )}
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
            </View>
            <TouchableOpacity style={styles.callButton} onPress={callDriver}>
              <Text style={styles.callButtonText}>📞 Appeler le chauffeur</Text>
            </TouchableOpacity>
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
              onPress={() => navigation.replace('CreateMission', { clientProfileId: mission.client_id ?? '' })}
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
