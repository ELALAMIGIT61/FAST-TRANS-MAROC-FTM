// /frontend/src/screens/driver/DriverOpenMissionsScreen.tsx
// FTM A1 F2 (migration 070, accord du porteur du 28/10/2026) — écran
// « Missions disponibles » du chauffeur.
// Auparavant, une nouvelle mission n'apparaissait que dans la fenêtre de
// 60 secondes ou par la notification : si le chauffeur la manquait, il ne
// pouvait plus la retrouver. Cet écran liste :
//   1. les missions ouvertes auxquelles il peut encore faire une offre (mêmes
//      règles que la notification, calculées par le serveur) ; seulement
//      quand il est « Disponible » (décision 2) ;
//   2. ses offres en cours, qui attendent la réponse d'un client (visibles
//      même « Hors service », décision 2).
// Toucher une mission ouvre le formulaire d'offre habituel, sans compte à
// rebours (décision 4) ; toucher une offre ouvre l'écran de négociation.
// Retouches après le test sur téléphone du 29/10/2026 (demandes du porteur) :
// bouton « Actualiser », relecture automatique toutes les 30 secondes, geste
// « tirer vers le bas » actif même quand la liste est vide, message « Hors
// service » dans un encadré, mention « Toucher pour… » en étiquette colorée.
import React, { useCallback, useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, RefreshControl } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import BackButton from '../../components/BackButton';
import { supabase } from '../../lib/supabaseClient';
import { getDriverOpenMissions, getDriverPendingOffers } from '../../services/missionService';
import type { DriverOpenMission, DriverPendingOffer } from '../../services/missionService';
import { formatCargo } from '../../utils/cargo';
import { formatMissionDateTime } from '../../components/DateTimeField';
import NewMissionModal from './NewMissionModal';

type DriverStackParamList = {
  DriverOpenMissions: { driverId: string };
  MissionOffer: { missionId: string; driverId: string };
};

type Props = NativeStackScreenProps<DriverStackParamList, 'DriverOpenMissions'>;

// Relecture automatique tant que l'écran est affiché
const AUTO_REFRESH_MS = 30000;

function formatPickup(iso: string | null | undefined): string {
  if (!iso) return 'Date non indiquée';
  return formatMissionDateTime(new Date(iso));
}

function offerStatusLabel(offer: DriverPendingOffer): string {
  if (offer.client_accepted && !offer.driver_accepted) {
    return '✅ Le client a accepté : à vous de confirmer';
  }
  if (offer.driver_accepted && !offer.client_accepted) {
    return '⏳ En attente de la confirmation du client';
  }
  return '⏳ En attente de la réponse du client';
}

export default function DriverOpenMissionsScreen({ route, navigation }: Props) {
  const { driverId } = route.params;
  const [isAvailable, setIsAvailable] = useState<boolean | null>(null);
  const [missions, setMissions] = useState<DriverOpenMission[]>([]);
  const [offers, setOffers] = useState<DriverPendingOffer[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [selectedMission, setSelectedMission] = useState<DriverOpenMission | null>(null);

  const load = useCallback(async () => {
    const [availability, openResult, offersResult] = await Promise.all([
      supabase.from('drivers').select('is_available').eq('id', driverId).single(),
      getDriverOpenMissions(),
      getDriverPendingOffers(),
    ]);
    setIsAvailable(availability.data ? availability.data.is_available === true : null);
    setMissions(openResult.missions ?? []);
    setOffers(offersResult.offers ?? []);
    setLoadError(
      openResult.error || offersResult.error
        ? 'Impossible de charger les missions pour le moment. Tirez vers le bas pour réessayer.'
        : null
    );
    setIsLoading(false);
  }, [driverId]);

  // Liste relue à chaque arrivée sur l'écran (retour de la négociation compris),
  // puis toutes les 30 secondes tant que l'écran reste affiché.
  useFocusEffect(
    useCallback(() => {
      load();
      const timer = setInterval(load, AUTO_REFRESH_MS);
      return () => clearInterval(timer);
    }, [load])
  );

  const onRefresh = useCallback(async () => {
    setIsRefreshing(true);
    await load();
    setIsRefreshing(false);
  }, [load]);

  return (
    <View style={styles.container}>
      <BackButton />
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={isRefreshing} onRefresh={onRefresh} />}
      >
        <View style={styles.titleRow}>
          <Text style={styles.title}>📋 Missions disponibles</Text>
          <TouchableOpacity
            style={[styles.refreshButton, isRefreshing && styles.refreshButtonDisabled]}
            onPress={onRefresh}
            disabled={isRefreshing}
            accessibilityRole="button"
            accessibilityLabel="Actualiser"
          >
            <Text style={styles.refreshButtonText}>{isRefreshing ? '…' : '🔄 Actualiser'}</Text>
          </TouchableOpacity>
        </View>

        {loadError && <Text style={styles.errorText}>{loadError}</Text>}

        <Text style={styles.sectionTitle}>Missions ouvertes</Text>
        {isLoading ? (
          <Text style={styles.emptyText}>Chargement…</Text>
        ) : isAvailable === false ? (
          <View style={styles.notice}>
            <Text style={styles.noticeText}>⚠️ Vous êtes « Hors service ».</Text>
            <Text style={styles.noticeText}>Passez « Disponible » pour voir les missions.</Text>
          </View>
        ) : missions.length === 0 ? (
          <Text style={styles.emptyText}>Aucune mission ouverte pour le moment.</Text>
        ) : (
          missions.map((mission) => (
            <TouchableOpacity
              key={mission.id}
              style={styles.card}
              onPress={() => setSelectedMission(mission)}
            >
              <Text style={styles.cardRoute}>
                {mission.pickup_city} → {mission.dropoff_city}
              </Text>
              <Text style={styles.cardDate}>{formatPickup(mission.scheduled_pickup_time)}</Text>
              <Text style={styles.cardMeta}>
                ⚖️ {formatCargo(mission.cargo_weight_kg, mission.cargo_volume_m3) ?? 'Poids et volume non indiqués'}
              </Text>
              <Text style={styles.cardMeta}>N° {mission.mission_number}</Text>
              <View style={styles.actionTag}>
                <Text style={styles.actionTagText}>👉 Toucher pour faire une offre</Text>
              </View>
            </TouchableOpacity>
          ))
        )}

        <Text style={styles.sectionTitle}>Mes offres en cours</Text>
        {isLoading ? (
          <Text style={styles.emptyText}>Chargement…</Text>
        ) : offers.length === 0 ? (
          <Text style={styles.emptyText}>Aucune offre en attente.</Text>
        ) : (
          offers.map((offer) => (
            <TouchableOpacity
              key={offer.offer_id}
              style={styles.card}
              onPress={() => navigation.navigate('MissionOffer', { missionId: offer.mission_id, driverId })}
            >
              <Text style={styles.cardRoute}>
                {offer.pickup_city} → {offer.dropoff_city}
              </Text>
              <Text style={styles.cardDate}>{formatPickup(offer.scheduled_pickup_time)}</Text>
              <Text style={styles.cardPrice}>💰 Prix en discussion : {offer.offered_price} DH</Text>
              <Text style={styles.cardStatus}>{offerStatusLabel(offer)}</Text>
              <Text style={styles.cardMeta}>N° {offer.mission_number}</Text>
              <View style={styles.actionTag}>
                <Text style={styles.actionTagText}>👉 Toucher pour ouvrir</Text>
              </View>
            </TouchableOpacity>
          ))
        )}
      </ScrollView>

      {selectedMission && (
        <NewMissionModal
          mission={selectedMission}
          driverId={driverId}
          withCountdown={false}
          onOfferCreated={() => {
            const missionId = selectedMission.id;
            setSelectedMission(null);
            navigation.navigate('MissionOffer', { missionId, driverId });
          }}
          onDismiss={() => {
            setSelectedMission(null);
            load();
          }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background },
  scroll: { flex: 1 },
  // flexGrow : la zone occupe tout l'écran, le geste « tirer vers le bas »
  // fonctionne donc aussi quand la liste est vide (constat du 29/10/2026).
  content: { flexGrow: 1, padding: SPACING.lg, paddingTop: SPACING.sm, gap: SPACING.sm },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: SPACING.sm,
    marginBottom: SPACING.sm,
  },
  title: { fontSize: 22, fontWeight: '700', color: COLORS.text, flexShrink: 1 },
  refreshButton: {
    borderWidth: 1.5,
    borderColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.md,
    paddingVertical: 6,
    paddingHorizontal: 10,
  },
  refreshButtonDisabled: { opacity: 0.5 },
  refreshButtonText: { fontSize: 14, fontWeight: '700', color: COLORS.primary },
  notice: {
    backgroundColor: '#FEF5E7',
    borderWidth: 2,
    borderColor: COLORS.cta,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    gap: 4,
  },
  noticeText: { fontSize: 16, fontWeight: '700', color: COLORS.text },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 1,
    color: COLORS.textSecondary,
    marginTop: SPACING.md,
    textTransform: 'uppercase',
  },
  emptyText: { fontSize: 14, color: COLORS.textSecondary, paddingVertical: SPACING.sm },
  errorText: { fontSize: 13, color: COLORS.alert ?? '#E53E3E' },
  card: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border,
    gap: 4,
  },
  cardRoute: { fontSize: 16, fontWeight: '700', color: COLORS.text },
  cardDate: { fontSize: 14, color: COLORS.text },
  cardPrice: { fontSize: 14, fontWeight: '600', color: COLORS.text },
  cardStatus: { fontSize: 13, color: COLORS.primary },
  cardMeta: { fontSize: 13, color: COLORS.textSecondary },
  actionTag: {
    alignSelf: 'flex-start',
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.md,
    paddingVertical: 6,
    paddingHorizontal: 12,
    marginTop: 6,
  },
  actionTagText: { fontSize: 15, fontWeight: '700', color: '#fff' },
});
