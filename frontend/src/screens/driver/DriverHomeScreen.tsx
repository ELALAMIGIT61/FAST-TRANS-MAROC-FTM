import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Switch,
  Alert,
} from 'react-native';
import type { RealtimeChannel } from '@supabase/supabase-js';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { startBackgroundTracking, stopBackgroundTracking } from '../../services/locationService';
import { subscribeToNewMissions, subscribeToMissionUpdates, unsubscribeChannel } from '../../services/realtimeService';
import { supabase } from '../../lib/supabaseClient';
import NewMissionModal from './NewMissionModal';
import NotificationBell from '../../components/NotificationBell';
import type { Mission, VehicleCategory } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type RootStackParamList = {
  DriverHome: { driverId: string; vehicleCategory: VehicleCategory };
  MissionActive: { mission: Record<string, unknown> };
  WalletDashboard: { driverId: string };
  DocumentStatus: undefined;
};

type Props = NativeStackScreenProps<RootStackParamList, 'DriverHome'>;

export default function DriverHomeScreen({ route, navigation }: Props) {
  const { driverId, vehicleCategory } = route.params;
  const [isAvailable, setIsAvailable] = useState(false);
  const [walletBalance, setWalletBalance] = useState<number | null>(null);
  const [pendingMission, setPendingMission] = useState<Mission | null>(null);
  const missionChannelRef = useRef<RealtimeChannel | null>(null);
  const pendingMissionUpdateChannelRef = useRef<RealtimeChannel | null>(null);

  useEffect(() => {
    const fetchWallet = async () => {
      const { data } = await supabase
        .from('wallet')
        .select('balance')
        .eq('driver_id', driverId)
        .single();
      if (data) setWalletBalance(data.balance as number);
    };
    fetchWallet();
  }, [driverId]);

  const clearPendingMissionWatch = useCallback(async () => {
    if (pendingMissionUpdateChannelRef.current) {
      await unsubscribeChannel(pendingMissionUpdateChannelRef.current);
      pendingMissionUpdateChannelRef.current = null;
    }
  }, []);

  const handleToggleAvailability = useCallback(async () => {
    const newStatus = !isAvailable;
    if (newStatus) {
      const trackResult = await startBackgroundTracking(driverId);
      if (trackResult.error) {
        Alert.alert('GPS requis', trackResult.error);
        return;
      }
    } else {
      await stopBackgroundTracking();
      if (missionChannelRef.current) {
        await unsubscribeChannel(missionChannelRef.current);
        missionChannelRef.current = null;
      }
      await clearPendingMissionWatch();
      setPendingMission(null);
    }
    const { error } = await supabase
      .from('drivers')
      .update({ is_available: newStatus })
      .eq('id', driverId);
    if (error) {
      Alert.alert('Erreur', error.message);
      if (newStatus) await stopBackgroundTracking();
      return;
    }
    console.log('[FTM-DEBUG] Driver - Availability updated', { driverId, isAvailable: newStatus });
    setIsAvailable(newStatus);
    if (newStatus) {
      missionChannelRef.current = subscribeToNewMissions(
        vehicleCategory,
        null,
        async (missionData) => {
          const mission = missionData as unknown as Mission;
          const rawMission = missionData as Record<string, unknown>;
          const pickupLocation = rawMission.pickup_location as string | null;

          if (pickupLocation) {
            const { data: nearbyDrivers, error: nearbyError } = await supabase.rpc('find_nearby_drivers', {
              client_point: pickupLocation,
              radius_meters: 60000,
              p_vehicle_category: vehicleCategory,
            });

            if (nearbyError) {
              console.log('[FTM-DEBUG] Driver - Distance check error, showing mission by default', {
                missionId: mission.id,
                error: nearbyError.message,
              });
            } else {
              const isWithinRadius = (nearbyDrivers as { id: string }[] | null)?.some((d) => d.id === driverId);
              if (!isWithinRadius) {
                console.log('[FTM-DEBUG] Driver - Mission outside radius, skipping', {
                  missionId: mission.id,
                  driverId,
                });
                return;
              }
            }
          }

          setPendingMission(mission);
          pendingMissionUpdateChannelRef.current = subscribeToMissionUpdates(
            mission.id,
            (updated) => {
              const updatedStatus = (updated as Record<string, unknown>).status;
              if (updatedStatus !== 'pending') {
                console.log('[FTM-DEBUG] Driver - Mission no longer pending, dismissing modal', {
                  missionId: mission.id,
                  status: updatedStatus,
                });
                setPendingMission(null);
                clearPendingMissionWatch();
              }
            }
          );
        }
      );
    }
  }, [isAvailable, driverId, vehicleCategory, clearPendingMissionWatch]);

  useEffect(() => {
    return () => {
      stopBackgroundTracking();
      unsubscribeChannel(missionChannelRef.current);
      unsubscribeChannel(pendingMissionUpdateChannelRef.current);
    };
  }, []);

  const walletColor =
    walletBalance !== null && walletBalance < 100
      ? (COLORS.alert ?? '#E53E3E')
      : (COLORS.success ?? '#38A169');

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View>
          <Text style={styles.greeting}>Bonjour, Chauffeur</Text>
          <Text style={styles.vehicleInfo}>{vehicleCategory.toUpperCase()}</Text>
        </View>
        <NotificationBell />
      </View>
      {walletBalance !== null && (
        <TouchableOpacity
          style={[styles.walletCard, { borderColor: walletColor }]}
          onPress={() => navigation.navigate('WalletDashboard', { driverId })}
        >
          <Text style={styles.walletLabel}>💰 Wallet</Text>
          <Text style={[styles.walletAmount, { color: walletColor }]}>
            {walletBalance.toFixed(2)} DH
          </Text>
        </TouchableOpacity>
      )}
      <View style={styles.toggleCard}>
        <Text style={styles.toggleCardTitle}>JE SUIS</Text>
        <View style={styles.toggleRow}>
          <Text style={[styles.toggleStatus, isAvailable ? styles.statusOn : styles.statusOff]}>
            {isAvailable ? '● DISPONIBLE' : '○ HORS SERVICE'}
          </Text>
          <Switch
            value={isAvailable}
            onValueChange={handleToggleAvailability}
            trackColor={{ false: COLORS.border, true: COLORS.success ?? '#38A169' }}
            thumbColor="#fff"
          />
        </View>
      </View>
      <TouchableOpacity
        style={styles.documentsButton}
        onPress={() => navigation.navigate('DocumentStatus')}
      >
        <Text style={styles.documentsButtonText}>📄 Mes documents</Text>
      </TouchableOpacity>
      {pendingMission && (
        <NewMissionModal
          mission={pendingMission}
          driverId={driverId}
          onAccepted={(acceptedMission) => {
            setPendingMission(null);
            clearPendingMissionWatch();
            navigation.navigate('MissionActive', { mission: acceptedMission as unknown as Record<string, unknown> });
          }}
          onDismiss={() => {
            setPendingMission(null);
            clearPendingMissionWatch();
          }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background, padding: SPACING.lg },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  greeting: { fontSize: 22, fontWeight: '700', color: COLORS.text },
  vehicleInfo: { fontSize: 14, color: COLORS.textSecondary, marginTop: 2 },
  walletCard: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderWidth: 1.5,
    marginBottom: SPACING.md,
  },
  walletLabel: { fontSize: 16, color: COLORS.text, fontWeight: '600' },
  walletAmount: { fontSize: 22, fontWeight: '700' },
  toggleCard: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.lg,
    alignItems: 'center',
    gap: SPACING.md,
    marginBottom: SPACING.lg,
  },
  toggleCardTitle: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 2,
    color: COLORS.textSecondary,
  },
  toggleRow: { flexDirection: 'row', alignItems: 'center', gap: SPACING.md },
  toggleStatus: { fontSize: 17, fontWeight: '700' },
  statusOn: { color: COLORS.success ?? '#38A169' },
  statusOff: { color: COLORS.textSecondary },
  documentsButton: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border,
    marginBottom: SPACING.md,
  },
  documentsButtonText: {
    fontSize: 15,
    fontWeight: '600',
    color: COLORS.text,
  },
});
