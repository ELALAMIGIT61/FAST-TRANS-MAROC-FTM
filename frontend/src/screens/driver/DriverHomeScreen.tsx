import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Switch,
} from 'react-native';
import { showMessage, confirmAction } from '../../utils/dialogs';
import type { RealtimeChannel } from '@supabase/supabase-js';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { startBackgroundTracking, stopBackgroundTracking } from '../../services/locationService';
import { subscribeToNewMissions, subscribeToMissionUpdates, unsubscribeChannel } from '../../services/realtimeService';
import { supabase } from '../../lib/supabaseClient';
import NewMissionModal from './NewMissionModal';
import NotificationBell from '../../components/NotificationBell';
import { signOutAndUnregisterDevice as handleSignOut } from '../../services/pushSetup';
import type { Mission, VehicleCategory } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useFocusEffect } from '@react-navigation/native';

type RootStackParamList = {
  DriverHome: { driverId: string; vehicleCategory: VehicleCategory };
  MissionActive: { mission: Record<string, unknown> };
  MissionOffer: { missionId: string; driverId: string };
  WalletDashboard: { driverId: string };
  DocumentStatus: undefined;
};

type Props = NativeStackScreenProps<RootStackParamList, 'DriverHome'>;

export default function DriverHomeScreen({ route, navigation }: Props) {
  const { driverId, vehicleCategory } = route.params;
  const [isAvailable, setIsAvailable] = useState(false);
  const [walletBalance, setWalletBalance] = useState<number | null>(null);
  const [walletError, setWalletError] = useState(false);
  // A1 (correction 20) : mission conclue ou en cours, pour pouvoir la reprendre
  // apres une fermeture de l'application (auparavant : impossible d'y revenir).
  const [activeMission, setActiveMission] = useState<Record<string, unknown> | null>(null);

  useFocusEffect(
    useCallback(() => {
      let cancelled = false;
      supabase
        .from('missions')
        .select('*')
        .eq('driver_id', driverId)
        .in('status', ['accepted', 'in_progress'])
        .order('scheduled_pickup_time', { ascending: true })
        .limit(1)
        .then(({ data, error }) => {
          if (cancelled) return;
          if (error) {
            console.log('[FTM-DEBUG] Driver - Active mission read failed', { error: error.message });
            return;
          }
          setActiveMission(data && data.length > 0 ? (data[0] as Record<string, unknown>) : null);
        });
      return () => {
        cancelled = true;
      };
    }, [driverId])
  );
  const [pendingMission, setPendingMission] = useState<Mission | null>(null);
  const missionChannelRef = useRef<RealtimeChannel | null>(null);
  const pendingMissionUpdateChannelRef = useRef<RealtimeChannel | null>(null);

  // Session 3.4 : solde relu a chaque retour sur l'accueil ; en cas d'echec,
  // la carte reste visible et propose de reessayer (au lieu de disparaitre).
  const fetchWallet = useCallback(async () => {
    const { data, error } = await supabase
      .from('wallet')
      .select('balance')
      .eq('driver_id', driverId)
      .single();
    if (data) {
      setWalletBalance(data.balance as number);
      setWalletError(false);
    } else {
      console.log('[FTM-DEBUG] Wallet - Balance fetch failed', { error: error?.message });
      setWalletError(true);
    }
  }, [driverId]);

  useFocusEffect(
    useCallback(() => {
      fetchWallet();
    }, [fetchWallet])
  );

  const clearPendingMissionWatch = useCallback(async () => {
    if (pendingMissionUpdateChannelRef.current) {
      await unsubscribeChannel(pendingMissionUpdateChannelRef.current);
      pendingMissionUpdateChannelRef.current = null;
    }
  }, []);

  // A1 (correction 12) : ecoute des nouvelles missions, isolee pour etre
  // relancee aussi a l'ouverture de l'ecran quand le chauffeur est deja disponible.
  const subscribeMissions = useCallback(() => {
    if (missionChannelRef.current) return;
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
  }, [driverId, vehicleCategory, clearPendingMissionWatch]);

  const handleToggleAvailability = useCallback(async () => {
    const newStatus = !isAvailable;
    if (newStatus) {
      const trackResult = await startBackgroundTracking(driverId);
      if (trackResult.error) {
        showMessage('GPS requis', trackResult.error);
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
      showMessage('Erreur', error.message);
      if (newStatus) await stopBackgroundTracking();
      return;
    }
    console.log('[FTM-DEBUG] Driver - Availability updated', { driverId, isAvailable: newStatus });
    setIsAvailable(newStatus);
    if (newStatus) subscribeMissions();
  }, [isAvailable, driverId, clearPendingMissionWatch, subscribeMissions]);

  // A1 (correction 12) : a l'ouverture, l'ecran affiche l'etat reel enregistre
  // dans la base (choix du porteur : le chauffeur reste disponible quand il quitte
  // l'application) ; s'il est disponible, le suivi et l'ecoute reprennent.
  useEffect(() => {
    let cancelled = false;
    const restoreAvailability = async () => {
      const { data, error } = await supabase
        .from('drivers')
        .select('is_available')
        .eq('id', driverId)
        .single();
      if (cancelled) return;
      if (error || !data) {
        console.log('[FTM-DEBUG] Driver - Availability read failed', { error: error?.message });
        return;
      }
      if (data.is_available !== true) return;
      const trackResult = await startBackgroundTracking(driverId);
      if (cancelled) return;
      if (trackResult.error) showMessage('GPS requis', trackResult.error);
      setIsAvailable(true);
      subscribeMissions();
      console.log('[FTM-DEBUG] Driver - Availability restored from database', { driverId });
    };
    if (driverId) restoreAvailability();
    return () => {
      cancelled = true;
    };
  }, [driverId, subscribeMissions]);

  const handleLogout = async () => {
    const ok = await confirmAction('Déconnexion', 'Voulez-vous vraiment vous déconnecter ?', {
      confirmLabel: 'Se déconnecter',
      destructive: true,
    });
    if (!ok) return;
    const result = await handleSignOut();
    if (result.error) showMessage('Erreur', result.error);
  };

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
        <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
          <Text style={styles.logoutButtonText}>🚪 Se déconnecter</Text>
        </TouchableOpacity>
      </View>
      {activeMission && (
        <TouchableOpacity
          style={styles.activeMissionCard}
          onPress={() => navigation.navigate('MissionActive', { mission: activeMission })}
        >
          <Text style={styles.activeMissionTitle}>
            {activeMission.status === 'in_progress' ? '🚚 Mission en cours' : '📅 Mission à venir'}
          </Text>
          <Text style={styles.activeMissionText}>
            N° {String(activeMission.mission_number ?? '')} — toucher pour reprendre
          </Text>
        </TouchableOpacity>
      )}
      {walletBalance !== null ? (
        <TouchableOpacity
          style={[styles.walletCard, { borderColor: walletColor }]}
          onPress={() => navigation.navigate('WalletDashboard', { driverId })}
        >
          <Text style={styles.walletLabel}>💰 Wallet</Text>
          <Text style={[styles.walletAmount, { color: walletColor }]}>
            {walletBalance.toFixed(2)} DH
          </Text>
        </TouchableOpacity>
      ) : (
        <TouchableOpacity
          style={[styles.walletCard, { borderColor: COLORS.border }]}
          onPress={fetchWallet}
          disabled={!walletError}
        >
          <Text style={styles.walletLabel}>💰 Wallet</Text>
          <Text style={styles.walletPending}>
            {walletError ? 'Solde indisponible — toucher pour réessayer' : 'Chargement…'}
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
          onOfferCreated={() => {
            const missionId = pendingMission.id;
            setPendingMission(null);
            clearPendingMissionWatch();
            navigation.navigate('MissionOffer', { missionId, driverId });
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
  activeMissionCard: {
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.md,
  },
  activeMissionTitle: { color: '#fff', fontSize: 16, fontWeight: '700' },
  activeMissionText: { color: '#fff', fontSize: 14, marginTop: 4 },
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
  walletPending: { fontSize: 13, color: COLORS.textSecondary, flexShrink: 1, marginLeft: 8, textAlign: 'right' },
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
  logoutButton: {
    paddingVertical: 4,
    paddingHorizontal: 8,
  },
  logoutButtonText: {
    fontSize: 12,
    color: '#DC3545',
  },
});
