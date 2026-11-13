import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Switch,
  ActivityIndicator,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { showMessage, confirmAction } from '../../utils/dialogs';
import { COLORS, FONTS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { getClientCurrentLocation, reverseGeocode } from '../../services/locationService';
import { createMission, VehicleCategory } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import NotificationBell from '../../components/NotificationBell';
import { signOutAndUnregisterDevice as handleSignOut } from '../../services/pushSetup';
import DateTimeField, { formatMissionDateTime } from '../../components/DateTimeField';
import { useFocusEffect } from '@react-navigation/native';
import { supabase } from '../../lib/supabaseClient';
import CityPicker from '../../components/CityPicker';
import { findCity } from '../../constants/moroccoCities';
import { MAX_LOAD_KG, formatTonnes, parseQuantity } from '../../utils/cargo';
import { usePendingNavigation } from '../../hooks/usePendingNavigation';
import { ensureGeocodingPermission, geocodeInCity, districtAt, GeoPoint } from '../../services/geocodingService';
import { getCommissionAmounts, DEFAULT_COMMISSION_AMOUNTS } from '../../services/settingsService';
import { SavedAddress, listSavedAddresses, markSavedAddressUsed } from '../../services/savedAddressService';
import SavedAddressList from '../../components/SavedAddressList';

type RootStackParamList = {
  CreateMission: { clientProfileId: string };
  MissionTracking: { mission: Record<string, unknown> };
  Rating: { mission: Record<string, unknown> };
};

type Props = NativeStackScreenProps<RootStackParamList, 'CreateMission'>;

// A1 F6 : charge utile maximale indiquee au client sous chaque categorie (MAX_LOAD_KG)
const VEHICLE_OPTIONS: { key: VehicleCategory; label: string; commission: number; icon: string }[] = [
  { key: 'vul', label: 'VUL', commission: 25, icon: '🚐' },
  { key: 'n2_medium', label: 'N2 Moyen', commission: 40, icon: '🚛' },
  { key: 'n2_large', label: 'N2 Grand', commission: 50, icon: '🚚' },
];

export default function CreateMissionScreen({ route, navigation }: Props) {
  const { clientProfileId } = route.params;
  // A1 (migration 073) : montants de commission en vigueur, lus sur le serveur
  // (reglables par l'admin) ; valeurs de depart affichees en attendant.
  const [commissions, setCommissions] = useState(DEFAULT_COMMISSION_AMOUNTS);
  useEffect(() => {
    let active = true;
    getCommissionAmounts().then(({ amounts }) => {
      if (active && amounts && Object.keys(amounts).length > 0) setCommissions({ ...DEFAULT_COMMISSION_AMOUNTS, ...amounts });
    });
    return () => {
      active = false;
    };
  }, []);
  // A1 (correction 31) : ecran demande par une notification (offres, suivi, notation)
  usePendingNavigation(
    route.params as unknown as Record<string, unknown>,
    navigation as unknown as Parameters<typeof usePendingNavigation>[1]
  );

  // A1 (correction 20) : missions du client encore ouvertes (en attente, conclues
  // ou en cours), pour pouvoir y revenir apres une fermeture de l'application.
  const [openMissions, setOpenMissions] = useState<Record<string, unknown>[]>([]);

  useFocusEffect(
    useCallback(() => {
      if (!clientProfileId) return;
      let cancelled = false;
      (async () => {
        // A1 (migration 077) : bouton « Noter » seulement pendant le delai
        // pour noter (7 jours apres la fin de la mission, reglable)
        const { data: windowDays } = await supabase.rpc('rating_window_days');
        const days = Number(windowDays) > 0 ? Number(windowDays) : 7;
        const cutoff = new Date(Date.now() - days * 24 * 3600 * 1000).toISOString();
        const { data, error } = await supabase
          .from('missions')
          .select('*')
          .eq('client_id', clientProfileId)
          // A1 F8 : aussi les missions terminees pas encore notees (bouton « Noter »)
          .or(`status.in.(pending,accepted,in_progress),and(status.eq.completed,client_rating.is.null,completed_at.gte."${cutoff}")`)
          .order('created_at', { ascending: false })
          .limit(5);
        if (cancelled) return;
        if (error) {
          console.log('[FTM-DEBUG] Client - Open missions read failed', { error: error.message });
          return;
        }
        setOpenMissions((data as Record<string, unknown>[]) ?? []);
      })();
      return () => {
        cancelled = true;
      };
    }, [clientProfileId])
  );

  const missionStatusLabel = (status: unknown) =>
    status === 'completed'
      ? '🏁 Terminée'
      : status === 'in_progress'
        ? '🚚 En cours'
        : status === 'accepted'
          ? '✅ Chauffeur trouvé'
          : '⏳ Recherche de chauffeur';

  // A1 (correction 15) : pickupCoords n'est rempli que par « Ma position actuelle ».
  // Toute adresse tapee est situee a l'envoi a partir du texte (adresse + ville).
  const [pickupCoords, setPickupCoords] = useState<{ lat: number; lng: number } | null>(null);
  const [pickupAddress, setPickupAddress] = useState('');
  const [pickupCity, setPickupCity] = useState('');
  const [dropoffAddress, setDropoffAddress] = useState('');
  const [dropoffCity, setDropoffCity] = useState('');
  // Lot 5 (C1) : repere facultatif du depart et de l'arrivee (200 caracteres au
  // plus) ; le serveur le range avec l'adresse exacte (migration 078).
  const [pickupLandmark, setPickupLandmark] = useState('');
  const [dropoffLandmark, setDropoffLandmark] = useState('');
  // Lot 5 (C3) : adresses enregistrees (« Mes adresses »). L'adresse choisie est
  // gardee tant que le client ne modifie ni l'adresse ni la ville ; son point
  // precis, s'il existe, remplace alors la localisation a partir du texte.
  const [savedAddresses, setSavedAddresses] = useState<SavedAddress[]>([]);
  const [savedListFor, setSavedListFor] = useState<'pickup' | 'dropoff' | null>(null);
  const [pickupSaved, setPickupSaved] = useState<SavedAddress | null>(null);
  const [dropoffSaved, setDropoffSaved] = useState<SavedAddress | null>(null);
  const [scheduledPickupTime, setScheduledPickupTime] = useState<Date | null>(null);
  const [vehicleCategory, setVehicleCategory] = useState<VehicleCategory | null>(null);
  const [needsLoading, setNeedsLoading] = useState(false);
  const [description, setDescription] = useState('');
  const [negotiatedPrice, setNegotiatedPrice] = useState('');
  // A1 F6 : poids (obligatoire pour N2, facultatif pour VUL) et volume (facultatif)
  const [cargoWeight, setCargoWeight] = useState('');
  const [cargoVolume, setCargoVolume] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isLocating, setIsLocating] = useState(false);

  const loadSavedAddresses = useCallback(async () => {
    if (!clientProfileId) return;
    const { addresses } = await listSavedAddresses(clientProfileId);
    setSavedAddresses(addresses);
    // Adresse choisie puis renommee : nom a jour ; supprimee : plus utilisee
    setPickupSaved((cur) => (cur ? addresses.find((a) => a.id === cur.id) ?? null : null));
    setDropoffSaved((cur) => (cur ? addresses.find((a) => a.id === cur.id) ?? null : null));
  }, [clientProfileId]);

  useFocusEffect(
    useCallback(() => {
      loadSavedAddresses();
    }, [loadSavedAddresses])
  );

  const chooseSaved = (which: 'pickup' | 'dropoff', a: SavedAddress) => {
    const known = findCity(a.city);
    if (which === 'pickup') {
      setPickupAddress(a.address);
      setPickupCity(known ? known.name : a.city);
      setPickupLandmark(a.landmark ?? '');
      setPickupCoords(null);
      setPickupSaved(a);
    } else {
      setDropoffAddress(a.address);
      setDropoffCity(known ? known.name : a.city);
      setDropoffLandmark(a.landmark ?? '');
      setDropoffSaved(a);
    }
    setSavedListFor(null);
  };

  const locateClient = useCallback(async () => {
    setIsLocating(true);
    const result = await getClientCurrentLocation();
    if (result.success && result.latitude && result.longitude) {
      setPickupCoords({ lat: result.latitude, lng: result.longitude });
      setPickupSaved(null);
      const geo = await reverseGeocode(result.latitude, result.longitude);
      setPickupAddress(geo.address);
      const known = findCity(geo.city);
      setPickupCity(known ? known.name : geo.city);
    } else {
      showMessage('Localisation', result.error ?? 'Erreur inconnue');
    }
    setIsLocating(false);
  }, []);

  // Session 3.4 : plus de localisation automatique a l'ouverture de la page.
  // Le client la demande lui-meme avec le bouton « Ma position actuelle ».

  const selectedVehicle = VEHICLE_OPTIONS.find((v) => v.key === vehicleCategory);
  const weightRequired = vehicleCategory === 'n2_medium' || vehicleCategory === 'n2_large';
  // A1 (correction 15) : le GPS n'est plus obligatoire ; il faut une adresse et une ville.
  const canSubmit =
    !!pickupAddress.trim() && !!pickupCity && !!dropoffAddress.trim() && !!dropoffCity &&
    !!vehicleCategory && !!scheduledPickupTime && !isLoading &&
    (!weightRequired || !!cargoWeight.trim());

  // Situe une adresse tapee. Si elle est introuvable, le client choisit :
  // corriger l'adresse, ou continuer avec le centre de la ville choisie.
  const resolvePoint = async (
    address: string,
    city: string,
    label: string,
    permission: boolean
  ): Promise<(GeoPoint & { precise: boolean }) | null> => {
    const precise = permission ? await geocodeInCity(address, city) : null;
    if (precise) return { ...precise, precise: true };
    const center = findCity(city);
    if (!center) {
      showMessage(label, `Choisissez la ville dans la liste pour situer l'adresse « ${address} ».`);
      return null;
    }
    const reason = permission
      ? `L'adresse « ${address} » n'a pas pu être située précisément.`
      : `Sans l'accès à la position, l'adresse « ${address} » ne peut pas être située précisément.`;
    const goOn = await confirmAction(
      label,
      `${reason} La mission sera placée au centre de ${center.name}. Le chauffeur verra votre adresse complète.`,
      { confirmLabel: 'Continuer', cancelLabel: "Corriger l'adresse" }
    );
    return goOn ? { lat: center.lat, lng: center.lng, precise: false } : null;
  };

  const handleSubmit = async () => {
    if (!canSubmit) return;
    // A1 F6 : controle du poids et du volume saisis
    const weight = parseQuantity(cargoWeight);
    const volume = parseQuantity(cargoVolume);
    if ((weight !== null && !(weight > 0)) || (volume !== null && !(volume > 0))) {
      showMessage('Chargement', 'Le poids et le volume doivent être des nombres positifs.');
      return;
    }
    if (weightRequired && weight === null) {
      showMessage('Chargement', 'Merci d\'indiquer le poids approximatif du chargement.');
      return;
    }
    setIsLoading(true);
    try {
      const maxLoad = vehicleCategory ? MAX_LOAD_KG[vehicleCategory] : undefined;
      if (weight !== null && maxLoad && weight > maxLoad) {
        const keep = await confirmAction(
          'Charge élevée',
          `⚠️ ${weight.toLocaleString('fr-FR')} kg dépasse la charge utile habituelle d'un ` +
            `${selectedVehicle?.label ?? 'véhicule de cette catégorie'} (${formatTonnes(maxLoad)}). ` +
            'Voulez-vous choisir une autre catégorie ?',
          { confirmLabel: 'Continuer quand même', cancelLabel: 'Changer de catégorie' }
        );
        if (!keep) return;
      }
      // A1 (correction 23) : confirmation de la date et de l'heure avant l'envoi.
      const timeOk = await confirmAction(
        'Date et heure de prise en charge',
        `Prise en charge le ${formatMissionDateTime(scheduledPickupTime!)}. Confirmer ?`,
        { confirmLabel: 'Confirmer', cancelLabel: 'Modifier' }
      );
      if (!timeOk) return;
      const permission = await ensureGeocodingPermission();
      // Lot 5 (C3) : point precis d'une adresse enregistree, s'il existe
      const savedPoint = (a: SavedAddress | null) =>
        a && a.lat != null && a.lng != null ? { lat: a.lat, lng: a.lng, precise: true } : null;
      const pickup = pickupCoords
        ? { ...pickupCoords, precise: true }
        : savedPoint(pickupSaved) ??
          (await resolvePoint(pickupAddress.trim(), pickupCity, 'Adresse de départ', permission));
      if (!pickup) return;
      const dropoff =
        savedPoint(dropoffSaved) ??
        (await resolvePoint(dropoffAddress.trim(), dropoffCity, "Adresse d'arrivée", permission));
      if (!dropoff) return;
      // A1 (migration 072) : quartier deduit de la position (pas de saisie du
      // client). Pas de quartier si l'adresse a ete placee au centre de la
      // ville : il serait faux ; la ville seule est alors montree.
      const [pickupDistrict, dropoffDistrict] = await Promise.all([
        permission && pickup.precise ? districtAt(pickup) : Promise.resolve(null),
        permission && dropoff.precise ? districtAt(dropoff) : Promise.resolve(null),
      ]);

      const result = await createMission(clientProfileId, {
        vehicle_category: vehicleCategory!,
        pickup_lat: pickup.lat,
        pickup_lng: pickup.lng,
        pickup_address: pickupAddress.trim(),
        pickup_city: pickupCity,
        dropoff_lat: dropoff.lat,
        dropoff_lng: dropoff.lng,
        dropoff_address: dropoffAddress.trim(),
        dropoff_city: dropoffCity,
        pickup_district: pickupDistrict,
        dropoff_district: dropoffDistrict,
        pickup_landmark: pickupLandmark.trim() || undefined,
        dropoff_landmark: dropoffLandmark.trim() || undefined,
        description: description || undefined,
        needs_loading_help: needsLoading,
        negotiated_price: negotiatedPrice ? parseFloat(negotiatedPrice) : undefined,
        scheduled_pickup_time: scheduledPickupTime!.toISOString(),
        cargo_weight_kg: weight ?? undefined,
        cargo_volume_m3: volume ?? undefined,
      });

      if (result.error) {
        showMessage('Erreur', result.error);
      } else if (result.mission) {
        // Lot 5 (C3) : date de dernier usage des adresses enregistrees choisies
        [pickupSaved?.id, dropoffSaved?.id].forEach((id) => {
          if (id) markSavedAddressUsed(id);
        });
        // A1 : l'accueil reste sous le suivi (retour possible par le bouton
        // « Retour » et par la touche retour du telephone) ; auparavant le
        // suivi remplacait l'accueil et le client restait bloque.
        navigation.reset({
          index: 1,
          routes: [
            { name: route.name, params: route.params },
            { name: 'MissionTracking', params: { mission: result.mission as unknown as Record<string, unknown> } },
          ],
        } as never);
      }
    } finally {
      setIsLoading(false);
    }
  };
  // Lot 5 (C3) : texte sous une adresse enregistree choisie
  const savedHint = (a: SavedAddress) =>
    a.lat != null && a.lng != null
      ? `🏷 Adresse enregistrée${a.label ? ` « ${a.label} »` : ''} : son point précis sera utilisé.`
      : `🏷 Adresse enregistrée${a.label ? ` « ${a.label} »` : ''} : elle sera située à partir du texte.`;

  // Lot 5 (C3) : bouton « Mes adresses » et liste, sous le depart ou l'arrivee
  const renderSavedToggle = (which: 'pickup' | 'dropoff') => (
    <>
      <TouchableOpacity
        style={styles.gpsButton}
        onPress={() => setSavedListFor(savedListFor === which ? null : which)}
      >
        <Text style={styles.gpsButtonText}>
          📍 Mes adresses ({savedAddresses.length}) {savedListFor === which ? '▲' : '▼'}
        </Text>
      </TouchableOpacity>
      {savedListFor === which && (
        <SavedAddressList
          addresses={savedAddresses}
          onChoose={(a) => chooseSaved(which, a)}
          onChanged={loadSavedAddresses}
        />
      )}
    </>
  );

  const handleLogout = async () => {
    const ok = await confirmAction('Déconnexion', 'Voulez-vous vraiment vous déconnecter ?', {
      confirmLabel: 'Se déconnecter',
      destructive: true,
    });
    if (!ok) return;
    const result = await handleSignOut();
    if (result.error) showMessage('Erreur', result.error);
  };


  return (
    <KeyboardAvoidingView
      style={styles.flex}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        <View style={styles.headerRow}>
          <Text style={styles.title}>Nouvelle mission</Text>
          <NotificationBell />
          <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
            <Text style={styles.logoutButtonText}>🚪 Se déconnecter</Text>
          </TouchableOpacity>
        </View>

        {openMissions.length > 0 && (
          <View style={styles.openMissionsBox}>
            <Text style={styles.openMissionsTitle}>Mes missions en cours</Text>
            {openMissions.map((m) => (
              <TouchableOpacity
                key={String(m.id)}
                style={styles.openMissionRow}
                onPress={() =>
                  m.status === 'completed'
                    ? navigation.navigate('Rating', { mission: m })
                    : navigation.navigate('MissionTracking', { mission: m })
                }
              >
                <Text style={styles.openMissionText}>
                  {missionStatusLabel(m.status)} — N° {String(m.mission_number ?? '')}
                </Text>
                <Text style={styles.openMissionLink}>
                  {m.status === 'completed' ? '⭐ Noter' : 'Suivre →'}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        )}

        {/* DÉPART */}
        <Text style={styles.sectionLabel}>📍 DÉPART</Text>
        <TouchableOpacity style={styles.gpsButton} onPress={locateClient} disabled={isLocating}>
          {isLocating ? (
            <ActivityIndicator color={COLORS.primary} />
          ) : (
            <Text style={styles.gpsButtonText}>🎯 Ma position actuelle</Text>
          )}
        </TouchableOpacity>
        <TextInput
          style={styles.input}
          value={pickupAddress}
          onChangeText={(text) => {
            // Adresse modifiee a la main : la position GPS n'est plus utilisee.
            setPickupAddress(text);
            setPickupCoords(null);
            setPickupSaved(null);
          }}
          placeholder="Adresse de départ"
          placeholderTextColor={COLORS.textSecondary}
        />
        <CityPicker
          value={pickupCity}
          onChange={(city) => {
            setPickupCity(city);
            setPickupCoords(null);
            setPickupSaved(null);
          }}
          placeholder="Ville de départ"
        />
        <TextInput
          style={styles.input}
          value={pickupLandmark}
          onChangeText={setPickupLandmark}
          placeholder="Repère (optionnel) : ex. en face de la pharmacie, portail bleu"
          placeholderTextColor={COLORS.textSecondary}
          maxLength={200}
        />
        <Text style={styles.pickupHint}>
          {pickupCoords
            ? '📍 Votre position actuelle sera utilisée comme point de départ.'
            : pickupSaved
              ? savedHint(pickupSaved)
              : 'Tapez l\'adresse et choisissez la ville, ou touchez « 🎯 Ma position actuelle ».'}
        </Text>
        {renderSavedToggle('pickup')}

        {/* ARRIVÉE */}
        <Text style={styles.sectionLabel}>🏁 ARRIVÉE</Text>
        <TextInput
          style={styles.input}
          value={dropoffAddress}
          onChangeText={(text) => {
            setDropoffAddress(text);
            setDropoffSaved(null);
          }}
          placeholder="Adresse de livraison"
          placeholderTextColor={COLORS.textSecondary}
        />
        <CityPicker
          value={dropoffCity}
          onChange={(city) => {
            setDropoffCity(city);
            setDropoffSaved(null);
          }}
          placeholder="Ville d'arrivée"
        />
        <TextInput
          style={styles.input}
          value={dropoffLandmark}
          onChangeText={setDropoffLandmark}
          placeholder="Repère (optionnel) : ex. à côté de la mosquée, 2e étage"
          placeholderTextColor={COLORS.textSecondary}
          maxLength={200}
        />
        {dropoffSaved && <Text style={styles.pickupHint}>{savedHint(dropoffSaved)}</Text>}
        {renderSavedToggle('dropoff')}

        {/* VÉHICULE */}
        <Text style={styles.sectionLabel}>VÉHICULE</Text>
        <View style={styles.vehicleRow}>
          {VEHICLE_OPTIONS.map((v) => (
            <TouchableOpacity
              key={v.key}
              style={[styles.vehicleCard, vehicleCategory === v.key && styles.vehicleCardActive]}
              onPress={() => setVehicleCategory(v.key)}
            >
              <Text style={styles.vehicleIcon}>{v.icon}</Text>
              <Text style={[styles.vehicleLabel, vehicleCategory === v.key && styles.vehicleLabelActive]}>
                {v.label}
              </Text>
              <Text style={[styles.vehicleCommission, vehicleCategory === v.key && styles.vehicleCommissionActive]}>
                {commissions[v.key] ?? v.commission} DH
              </Text>
              <Text style={styles.vehicleLoad}>jusqu'à {formatTonnes(MAX_LOAD_KG[v.key])}</Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* A1 F6 : CHARGEMENT */}
        <Text style={styles.sectionLabel}>CHARGEMENT</Text>
        <TextInput
          style={styles.input}
          value={cargoWeight}
          onChangeText={setCargoWeight}
          placeholder={
            weightRequired
              ? 'Poids approximatif en kg (obligatoire)'
              : 'Poids approximatif en kg (optionnel)'
          }
          placeholderTextColor={COLORS.textSecondary}
          keyboardType="decimal-pad"
          maxLength={7}
        />
        <TextInput
          style={styles.input}
          value={cargoVolume}
          onChangeText={setCargoVolume}
          placeholder="Volume approximatif en m³ (optionnel)"
          placeholderTextColor={COLORS.textSecondary}
          keyboardType="decimal-pad"
          maxLength={6}
        />
        <Text style={styles.cargoHelp}>
          Repères : 1 palette ≈ 1,5 m³ · 1 réfrigérateur ≈ 1 m³ · un studio ≈ 10 m³ · un 3 pièces ≈ 25 m³
        </Text>

        {/* DATE / HEURE DE PRISE EN CHARGE */}
        <Text style={styles.sectionLabel}>DATE ET HEURE DE PRISE EN CHARGE</Text>
        <DateTimeField
          label="Quand souhaitez-vous être pris en charge ?"
          value={scheduledPickupTime}
          onChange={setScheduledPickupTime}
          variant="mission"
        />

        {/* OPTIONS */}
        <Text style={styles.sectionLabel}>OPTIONS</Text>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>💪 Manutention nécessaire</Text>
          <Switch
            value={needsLoading}
            onValueChange={setNeedsLoading}
            trackColor={{ false: COLORS.border, true: COLORS.primary }}
            thumbColor={needsLoading ? '#fff' : '#f4f3f4'}
          />
        </View>
        <TextInput
          style={[styles.input, styles.textArea]}
          value={description}
          onChangeText={setDescription}
          // A1 (R-DESC, decision du porteur du 04/11/2026) : le texte oriente vers la marchandise
          placeholder="Décrivez la marchandise : nature, quantité, précautions de chargement… (optionnel)"
          placeholderTextColor={COLORS.textSecondary}
          multiline
          numberOfLines={3}
        />
        <TextInput
          style={styles.input}
          value={negotiatedPrice}
          onChangeText={setNegotiatedPrice}
          placeholder="Prix proposé en DH (optionnel)"
          placeholderTextColor={COLORS.textSecondary}
          keyboardType="numeric"
        />

        {/* RÉSUMÉ */}
        {selectedVehicle && (
          <View style={styles.summaryBox}>
            <Text style={styles.summaryText}>
              Commission : <Text style={styles.summaryHighlight}>{commissions[selectedVehicle.key] ?? selectedVehicle.commission} DH</Text>
            </Text>
          </View>
        )}

        <TouchableOpacity
          style={[styles.submitButton, !canSubmit && styles.submitButtonDisabled]}
          onPress={handleSubmit}
          disabled={!canSubmit}
        >
          {isLoading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.submitButtonText}>Trouver un chauffeur</Text>
          )}
        </TouchableOpacity>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: COLORS.background },
  container: { flex: 1 },
  content: { padding: SPACING.md, paddingBottom: 40 },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.text,
  },
  openMissionsBox: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.primary,
  },
  openMissionsTitle: { fontSize: 15, fontWeight: '700', color: COLORS.primary, marginBottom: 6 },
  openMissionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
  },
  openMissionText: { fontSize: 14, color: COLORS.text, flexShrink: 1 },
  openMissionLink: { fontSize: 14, color: COLORS.primary, fontWeight: '600', marginLeft: 8 },
  sectionLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: COLORS.textSecondary,
    letterSpacing: 1,
    marginTop: SPACING.md,
    marginBottom: SPACING.sm,
  },
  gpsButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.sm,
    borderRadius: BORDER_RADIUS.md,
    backgroundColor: COLORS.primary + '15',
    marginBottom: SPACING.sm,
    minHeight: 44,
  },
  gpsButtonText: { color: COLORS.primary, fontWeight: '600', fontSize: 15 },
  pickupHint: { color: COLORS.textSecondary, fontSize: 13, marginTop: -4, marginBottom: 8 },
  input: {
    backgroundColor: COLORS.surface,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
    color: COLORS.text,
    fontSize: 15,
    marginBottom: SPACING.sm,
  },
  textArea: { minHeight: 80, textAlignVertical: 'top' },
  vehicleRow: { flexDirection: 'row', gap: SPACING.sm, marginBottom: SPACING.sm },
  vehicleCard: {
    flex: 1,
    alignItems: 'center',
    padding: SPACING.sm,
    borderRadius: BORDER_RADIUS.md,
    borderWidth: 2,
    borderColor: COLORS.border,
    backgroundColor: COLORS.surface,
  },
  vehicleCardActive: {
    borderColor: COLORS.primary,
    backgroundColor: COLORS.primary + '10',
  },
  vehicleIcon: { fontSize: 24, marginBottom: 4 },
  vehicleLabel: { fontSize: 12, fontWeight: '600', color: COLORS.textSecondary },
  vehicleLabelActive: { color: COLORS.primary },
  vehicleCommission: { fontSize: 13, fontWeight: '700', color: COLORS.text, marginTop: 2 },
  vehicleCommissionActive: { color: COLORS.primary },
  vehicleLoad: { fontSize: 11, color: COLORS.textSecondary, marginTop: 2 },
  cargoHelp: { fontSize: 12, color: COLORS.textSecondary, marginTop: -4, marginBottom: 8 },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: SPACING.sm,
    paddingVertical: SPACING.xs,
  },
  toggleLabel: { fontSize: 15, color: COLORS.text, flex: 1 },
  summaryBox: {
    backgroundColor: COLORS.primary + '10',
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.sm,
    marginVertical: SPACING.sm,
    alignItems: 'center',
  },
  summaryText: { fontSize: 15, color: COLORS.text },
  summaryHighlight: { fontWeight: '700', color: COLORS.primary },
  submitButton: {
    backgroundColor: COLORS.primary,
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    marginTop: SPACING.md,
    minHeight: 52,
    justifyContent: 'center',
  },
  submitButtonDisabled: { opacity: 0.5 },
  submitButtonText: { color: '#fff', fontSize: 17, fontWeight: '700' },
  logoutButton: {
    paddingVertical: 4,
    paddingHorizontal: 8,
  },
  logoutButtonText: {
    fontSize: 12,
    color: '#DC3545',
  },
});
