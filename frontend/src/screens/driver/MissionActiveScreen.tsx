import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useFocusEffect } from '@react-navigation/native';
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
import {
  startMission,
  completeMission,
  cancelMission,
  getDriverCancelTerms,
  getMissionById,
  getMissionExactLocation,
  exactAddressHint,
} from '../../services/missionService';
import type { MissionExactLocation } from '../../services/missionService';
import { cleanServerMessage } from '../../services/settingsService';
import { subscribeToMissionUpdates, unsubscribeChannel } from '../../services/realtimeService';
import { requestRefund } from '../../services/walletService';
import type { Mission } from '../../services/missionService';
import { formatCargo } from '../../utils/cargo';
import BackButton from '../../components/BackButton';
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


export default function MissionActiveScreen({ route, navigation }: Props) {
  const initialMission = route.params.mission as unknown as Mission;
  const [mission, setMission] = useState<Mission>(initialMission);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [isRequestingRefund, setIsRequestingRefund] = useState(false);
  const [refundRequested, setRefundRequested] = useState(false);
  const [isCancelling, setIsCancelling] = useState(false);
  // A1 (migration 072) : adresse et point exacts, lisibles seulement apres le
  // prelevement de la commission (null avant : quartier et ville seulement)
  const [exact, setExact] = useState<MissionExactLocation | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // A1 (correction 35) : l'ecran suit la mission en direct. Auparavant il
  // gardait l'etat de son ouverture : une annulation par le client n'etait
  // pas visible et le chauffeur restait sur « En route vers le client ».
  const missionId = initialMission.id;
  const lastStatusRef = useRef<string>(initialMission.status);

  const applyUpdate = useCallback((updated: Partial<Mission>) => {
    setMission((prev) => ({ ...prev, ...updated }));
    const previous = lastStatusRef.current;
    if (updated.status && updated.status !== previous) {
      lastStatusRef.current = updated.status;
      if (
        updated.status === 'cancelled_client' &&
        (previous === 'accepted' || previous === 'in_progress')
      ) {
        showMessage('Mission annulée', 'Le client a annulé cette mission.');
      }
    }
  }, []);

  useEffect(() => {
    const channel = subscribeToMissionUpdates(missionId, (updated) =>
      applyUpdate(updated as unknown as Partial<Mission>)
    );
    return () => {
      unsubscribeChannel(channel);
    };
  }, [missionId, applyUpdate]);

  // Rechargement a chaque retour sur l'ecran (au cas ou une mise a jour en
  // direct aurait ete manquee, par exemple telephone en veille)
  useFocusEffect(
    useCallback(() => {
      let active = true;
      getMissionById(missionId).then((result) => {
        if (active && result.mission) applyUpdate(result.mission);
      });
      return () => {
        active = false;
      };
    }, [missionId, applyUpdate])
  );

  // Relue a l'ouverture, au retour sur l'ecran et des que la commission est
  // prelevee (mise a jour en direct de la mission)
  useFocusEffect(
    useCallback(() => {
      let active = true;
      getMissionExactLocation(missionId).then((result) => {
        if (active) setExact(result.location);
      });
      return () => {
        active = false;
      };
    }, [missionId, mission.commission_charged_at])
  );

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

  // A1 (migration 074) : la messagerie vocale s'ouvre au prelevement de la
  // commission, en meme temps que l'adresse exacte (auparavant 24 h avant,
  // sur la seule base de l'heure : elle pouvait servir a obtenir l'adresse).
  const voiceChannelOpen =
    (mission.status === 'accepted' || mission.status === 'in_progress') && !!mission.commission_charged_at;

  const openMaps = (lat: number, lng: number) => {
    const url =
      Platform.OS === 'ios'
        ? `maps://?daddr=${lat},${lng}`
        : `https://maps.google.com/?daddr=${lat},${lng}`;
    Linking.openURL(url);
  };

  // A1 (correction 18) : les boutons « Ouvrir dans Maps » n'affichaient qu'un
  // message. Ils ouvrent un point (coordonnees) ou une adresse ecrite.
  const openMapsAddress = (address: string, city: string) => {
    const query = encodeURIComponent([address, city, 'Maroc'].filter(Boolean).join(', '));
    Linking.openURL(`https://www.google.com/maps/dir/?api=1&destination=${query}`);
  };

  // A1 (migration 072) : avant la commission, Maps ouvre seulement le
  // quartier ou la ville (la fiche ne contient que « quartier, ville ») ;
  // apres, le point exact.
  const openPickupInMaps = () => {
    if (exact?.pickup_lat != null && exact?.pickup_lng != null) openMaps(exact.pickup_lat, exact.pickup_lng);
    else if (exact?.pickup_address) openMapsAddress(exact.pickup_address, mission.pickup_city);
    else openMapsAddress(mission.pickup_address, '');
  };

  // Destination : adresse ecrite exacte (comme avant, plus fiable quand
  // l'adresse a ete placee au centre de la ville faute d'etre trouvee).
  const openDropoffInMaps = () => {
    if (exact?.dropoff_address) openMapsAddress(exact.dropoff_address, mission.dropoff_city);
    else openMapsAddress(mission.dropoff_address, '');
  };

  const handleStart = async () => {
    const result = await startMission(mission.id, mission.driver_id ?? '');
    if (result.error) {
      // A1 (migration 074) : demarrage refuse tant que la commission n'est pas prelevee
      showMessage(
        result.error.includes('demarrage_impossible') ? 'Démarrage impossible' : 'Erreur',
        cleanServerMessage(result.error)
      );
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

  // A1 F4 : annulation par le chauffeur. Les conditions (delai reglable par
  // categorie, commission deja prelevee) sont calculees par le serveur ; a
  // moins du delai, le chauffeur est prevenu qu'il perd le remboursement.
  const handleCancelByDriver = async () => {
    if (isCancelling) return;
    setIsCancelling(true);
    const { terms, error: termsError } = await getDriverCancelTerms(mission.id);
    if (termsError) {
      setIsCancelling(false);
      showMessage('Erreur', termsError);
      return;
    }
    const amount = Number(terms?.commission_amount ?? mission.commission_amount ?? 0);
    let message = 'Voulez-vous vraiment annuler cette mission ? Le client sera prévenu.';
    if (terms?.refund_lost_if_cancelled) {
      message =
        `⚠️ La mission commence dans moins de ${terms.delay_hours} h. ` +
        `Si vous annulez maintenant, la commission de ${amount} DH déjà prélevée ne sera pas remboursée.\n\n` +
        'Voulez-vous vraiment annuler ?';
    } else if (terms?.commission_charged) {
      message +=
        `\n\nLa commission de ${amount} DH déjà prélevée pourra vous être remboursée : ` +
        'faites la demande après l\'annulation.';
    }
    const confirmed = await confirmAction('Annuler la mission', message, {
      confirmLabel: 'Oui, annuler',
      cancelLabel: 'Non, garder la mission',
      destructive: true,
    });
    if (!confirmed) {
      setIsCancelling(false);
      return;
    }
    const result = await cancelMission(mission.id, mission.driver_id ?? '', 'driver');
    setIsCancelling(false);
    if (result.error) {
      showMessage('Erreur', result.error);
    } else if (result.mission) {
      setMission(result.mission);
    }
  };

  if (mission.status === 'accepted') {
    return (
      <View style={styles.container}>
        {/* A1 : bouton « Retour » (constat du 30/10/2026) */}
        <BackButton style={styles.backButton} />
        <Text style={styles.phaseTitle}>🚗 En route vers le client</Text>

        <View style={styles.addressCard}>
          <Text style={styles.addressLabel}>📍 Point de chargement</Text>
          {exact?.pickup_address ? (
            <>
              <Text style={styles.addressText}>{exact.pickup_address}</Text>
              <Text style={styles.cityText}>{mission.pickup_city}</Text>
            </>
          ) : (
            <>
              <Text style={styles.addressText}>{mission.pickup_address}</Text>
              <Text style={styles.hintText}>{exactAddressHint(mission.scheduled_pickup_time)}</Text>
            </>
          )}
          {/* A1 F6 : poids et volume du chargement */}
          <Text style={styles.cityText}>
            ⚖️ {formatCargo(mission.cargo_weight_kg, mission.cargo_volume_m3) ?? 'Poids et volume non indiqués'}
          </Text>
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
        <TouchableOpacity
          style={styles.cancelButton}
          onPress={handleCancelByDriver}
          disabled={isCancelling}
        >
          <Text style={styles.cancelButtonText}>
            {isCancelling ? 'Vérification...' : 'Annuler la mission'}
          </Text>
        </TouchableOpacity>
      </View>
    );
  }

  if (mission.status === 'in_progress') {
    return (
      <View style={styles.container}>
        <BackButton style={styles.backButton} />
        <Text style={styles.phaseTitle}>🚚 Mission en cours</Text>
        <Text style={styles.missionNumber}>N° {mission.mission_number}</Text>

        <View style={styles.addressCard}>
          <Text style={styles.addressLabel}>🏁 Destination</Text>
          {exact?.dropoff_address ? (
            <>
              <Text style={styles.addressText}>{exact.dropoff_address}</Text>
              <Text style={styles.cityText}>{mission.dropoff_city}</Text>
            </>
          ) : (
            <Text style={styles.addressText}>{mission.dropoff_address}</Text>
          )}
          <Text style={styles.cityText}>
            ⚖️ {formatCargo(mission.cargo_weight_kg, mission.cargo_volume_m3) ?? 'Poids et volume non indiqués'}
          </Text>
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

  // A1 F9 (migration 071) : une mission conclue non demarree est cloturee par
  // le serveur (etat expired) : remboursement possible sur demande, comme une
  // annulation.
  const isNotPerformed = mission.status === 'expired';
  const isCancelled =
    mission.status === 'cancelled_client' || mission.status === 'cancelled_driver' || isNotPerformed;
  // A1 F4 : pas de demande de remboursement si le chauffeur a annule a moins
  // du delai (le serveur la refuse aussi).
  const canRequestRefund =
    isCancelled && !!mission.commission_charged_at && !mission.refund_forfeited;
  const statusLabel =
    mission.status === 'cancelled_driver'
      ? '❌ Mission annulée par vous'
      : mission.status === 'cancelled_client'
        ? '❌ Mission annulée par le client'
        : isNotPerformed
          ? '⏱️ Mission non réalisée : elle n’a pas démarré et a été clôturée'
          : mission.status === 'completed'
            ? '✅ Mission terminée'
            : `Statut : ${mission.status}`;

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
      <Text style={styles.missionNumber}>N° {mission.mission_number}</Text>
      <Text style={styles.missionNumber}>{statusLabel}</Text>
      {mission.refund_forfeited && (
        <Text style={styles.missionNumber}>
          Annulation à moins du délai prévu : la commission prélevée ne sera pas remboursée.
        </Text>
      )}
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
      {/* A1 (retouche 36) : rien n'a ete preleve (commission prelevee 24 h
          avant le chargement seulement) : on le dit au chauffeur */}
      {isCancelled && !mission.commission_charged_at && (
        <Text style={styles.missionNumber}>
          Aucune commission n’a été prélevée pour cette mission : rien à rembourser.
        </Text>
      )}
      {refundRequested && (
        <Text style={styles.missionNumber}>Demande de remboursement envoyee.</Text>
      )}
      {/* A1 (retouche 37) : retour a l'accueil depuis une mission terminee,
          annulee ou non realisee */}
      <TouchableOpacity style={styles.mapsButton} onPress={() => navigation.popToTop()}>
        <Text style={styles.mapsButtonText}>🏠 Retour à l’accueil</Text>
      </TouchableOpacity>
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
  backButton: { position: 'absolute', top: SPACING.sm, left: SPACING.sm },
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
  hintText: { fontSize: 13, color: COLORS.textSecondary, fontStyle: 'italic', marginTop: 4 },
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
  cancelButton: {
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.alert,
  },
  cancelButtonText: { color: COLORS.alert, fontSize: 15, fontWeight: '600' },
});
