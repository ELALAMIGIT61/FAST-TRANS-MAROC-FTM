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
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { COLORS, FONTS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { getClientCurrentLocation, reverseGeocode } from '../../services/locationService';
import { createMission, VehicleCategory } from '../../services/missionService';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type RootStackParamList = {
  CreateMission: { clientProfileId: string };
  MissionTracking: { mission: Record<string, unknown> };
};

type Props = NativeStackScreenProps<RootStackParamList, 'CreateMission'>;

const VEHICLE_OPTIONS: { key: VehicleCategory; label: string; commission: number; icon: string }[] = [
  { key: 'vul', label: 'VUL', commission: 25, icon: '🚐' },
  { key: 'n2_medium', label: 'N2 Moyen', commission: 40, icon: '🚛' },
  { key: 'n2_large', label: 'N2 Grand', commission: 50, icon: '🚚' },
];

export default function CreateMissionScreen({ route, navigation }: Props) {
  const { clientProfileId } = route.params;

  const [pickupCoords, setPickupCoords] = useState<{ lat: number; lng: number } | null>(null);
  const [pickupAddress, setPickupAddress] = useState('');
  const [pickupCity, setPickupCity] = useState('');
  const [dropoffAddress, setDropoffAddress] = useState('');
  const [dropoffCity, setDropoffCity] = useState('');
  const [dropoffCoords] = useState<{ lat: number; lng: number } | null>(null);
  const [vehicleCategory, setVehicleCategory] = useState<VehicleCategory | null>(null);
  const [needsLoading, setNeedsLoading] = useState(false);
  const [description, setDescription] = useState('');
  const [negotiatedPrice, setNegotiatedPrice] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isLocating, setIsLocating] = useState(false);

  const locateClient = useCallback(async () => {
    setIsLocating(true);
    const result = await getClientCurrentLocation();
    if (result.success && result.latitude && result.longitude) {
      setPickupCoords({ lat: result.latitude, lng: result.longitude });
      const geo = await reverseGeocode(result.latitude, result.longitude);
      setPickupAddress(geo.address);
      setPickupCity(geo.city);
    } else {
      Alert.alert('Localisation', result.error ?? 'Erreur inconnue');
    }
    setIsLocating(false);
  }, []);

  useEffect(() => {
    locateClient();
  }, [locateClient]);

  const selectedVehicle = VEHICLE_OPTIONS.find((v) => v.key === vehicleCategory);
  const canSubmit = !!pickupCoords && !!dropoffAddress && !!vehicleCategory && !isLoading;

  const handleSubmit = async () => {
    if (!canSubmit || !pickupCoords) return;
    setIsLoading(true);

    const result = await createMission(clientProfileId, {
      vehicle_category: vehicleCategory!,
      pickup_lat: pickupCoords.lat,
      pickup_lng: pickupCoords.lng,
      pickup_address: pickupAddress,
      pickup_city: pickupCity,
      dropoff_lat: dropoffCoords?.lat ?? pickupCoords.lat,
      dropoff_lng: dropoffCoords?.lng ?? pickupCoords.lng,
      dropoff_address: dropoffAddress,
      dropoff_city: dropoffCity,
      description: description || undefined,
      needs_loading_help: needsLoading,
      negotiated_price: negotiatedPrice ? parseFloat(negotiatedPrice) : undefined,
    });

    setIsLoading(false);

    if (result.error) {
      Alert.alert('Erreur', result.error);
    } else if (result.mission) {
      navigation.replace('MissionTracking', { mission: result.mission as unknown as Record<string, unknown> });
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.flex}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        <Text style={styles.title}>Nouvelle mission</Text>

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
          onChangeText={setPickupAddress}
          placeholder="Adresse de départ"
          placeholderTextColor={COLORS.textSecondary}
        />

        {/* ARRIVÉE */}
        <Text style={styles.sectionLabel}>🏁 ARRIVÉE</Text>
        <TextInput
          style={styles.input}
          value={dropoffAddress}
          onChangeText={setDropoffAddress}
          placeholder="Adresse de livraison"
          placeholderTextColor={COLORS.textSecondary}
        />
        <TextInput
          style={styles.input}
          value={dropoffCity}
          onChangeText={setDropoffCity}
          placeholder="Ville d'arrivée"
          placeholderTextColor={COLORS.textSecondary}
        />

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
                {v.commission} DH
              </Text>
            </TouchableOpacity>
          ))}
        </View>

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
          placeholder="Description du chargement (optionnel)"
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
              Commission : <Text style={styles.summaryHighlight}>{selectedVehicle.commission} DH</Text>
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
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: SPACING.lg,
  },
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
});
