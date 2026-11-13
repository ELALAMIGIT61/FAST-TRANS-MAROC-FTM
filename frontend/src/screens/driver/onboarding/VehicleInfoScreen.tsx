// /screens/driver/onboarding/VehicleInfoScreen.tsx
// Fast Trans Maroc — P2 — Step 1

import React, { useState, useEffect } from 'react';
import LogoutButton from '../../../components/LogoutButton';
import {
  View, Text, TextInput, TouchableOpacity,
  ScrollView, StyleSheet, ActivityIndicator,
} from 'react-native';
import { showMessage } from '../../../utils/dialogs';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { createDriverProfile, VehicleCategory } from '../../../services/driverService';
import { supabase } from '../../../lib/supabaseClient';
import { COLORS } from '../../../constants/theme';
import { getCommissionAmounts, type CommissionAmounts } from '../../../services/settingsService';

type Props = {
  navigation: NativeStackNavigationProp<any>;
};

const VEHICLE_CATEGORIES = [
  {
    value:       'vul' as VehicleCategory,
    label_fr:    'VUL',
    description: '≤ 3,5 tonnes',
    commission:  '25 DH',
    icon:        '🚐',
  },
  {
    value:       'n2_medium' as VehicleCategory,
    label_fr:    'N2 Moyen',
    description: '3,5 – 7,5 tonnes',
    commission:  '40 DH',
    icon:        '🚛',
  },
  {
    value:       'n2_large' as VehicleCategory,
    label_fr:    'N2 Grand',
    description: '7,5 – 12 tonnes',
    commission:  '50 DH',
    icon:        '🚚',
  },
];

const LICENSE_PLATE_REGEX = /^[0-9]{1,6}-[A-Z]-[0-9]+$/;

export default function VehicleInfoScreen({ navigation }: Props) {
  const [vehicleCategory, setVehicleCategory] = useState<VehicleCategory | null>(null);
  // A1 (migration 073) : commission en vigueur, lue sur le serveur
  const [commissions, setCommissions] = useState<CommissionAmounts>({});
  useEffect(() => {
    let active = true;
    getCommissionAmounts().then(({ amounts }) => {
      if (active && amounts) setCommissions(amounts);
    });
    return () => {
      active = false;
    };
  }, []);
  const [vehicleBrand,    setVehicleBrand]    = useState('');
  const [vehicleModel,    setVehicleModel]    = useState('');
  const [licensePlate,    setLicensePlate]    = useState('');
  const [capacityKg,      setCapacityKg]      = useState('');
  const [isLoading,       setIsLoading]       = useState(false);
  // Session 2.21 : fiche chauffeur deja creee (retour depuis l'etape 2,
  // ou inscription reprise apres avoir quitte l'application)
  const [existingDriverId, setExistingDriverId] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data: profile } = await supabase
        .from('profiles').select('id').eq('user_id', user.id).maybeSingle();
      if (!profile) return;
      const { data: driver } = await supabase
        .from('drivers')
        .select('id, vehicle_category, vehicle_brand, vehicle_model, license_plate, vehicle_capacity_kg')
        .eq('profile_id', profile.id)
        .maybeSingle();
      if (!driver) return;
      console.log('[FTM-DEBUG] Onboarding - Existing driver found, form prefilled', { driverId: driver.id });
      setExistingDriverId(driver.id as string);
      setVehicleCategory((driver.vehicle_category as VehicleCategory) ?? null);
      setVehicleBrand((driver.vehicle_brand as string) ?? '');
      setVehicleModel((driver.vehicle_model as string) ?? '');
      setLicensePlate((driver.license_plate as string) ?? '');
      setCapacityKg(driver.vehicle_capacity_kg ? String(driver.vehicle_capacity_kg) : '');
    })();
  }, []);

  // Lot 3 (A9) : capacite obligatoire, nombre entier superieur a 0 (avant : un
  // champ vide envoyait 0, refuse par la base avec un message technique). Pas de
  // maximum metier ; 6 chiffres au plus, pour rester dans les limites de la base.
  const isCapacityValid = /^[0-9]{1,6}$/.test(capacityKg.trim()) && parseInt(capacityKg.trim(), 10) > 0;

  const isFormValid =
    vehicleCategory !== null &&
    licensePlate.trim().length > 0 &&
    LICENSE_PLATE_REGEX.test(licensePlate.trim().toUpperCase()) &&
    isCapacityValid;

  async function handleNext() {
    if (!isFormValid) return;
    setIsLoading(true);

    // Session 2.21 : fiche deja existante -> mise a jour du vehicule
    // (une seule fiche chauffeur par compte : une seconde creation echouerait)
    if (existingDriverId) {
      const { error } = await supabase
        .from('drivers')
        .update({
          vehicle_category:    vehicleCategory!,
          vehicle_brand:       vehicleBrand.trim(),
          vehicle_model:       vehicleModel.trim(),
          license_plate:       licensePlate.trim().toUpperCase(),
          vehicle_capacity_kg: parseInt(capacityKg.trim(), 10),
        })
        .eq('id', existingDriverId);
      setIsLoading(false);
      if (error) {
        console.log('[FTM-DEBUG] Onboarding - Vehicle update error', { error: error.message });
        showMessage('Erreur', error.code === '23505'
          ? "Cette plaque d'immatriculation est déjà enregistrée."
          : error.message);
        return;
      }
      navigation.navigate('LegalDocuments', { driverId: existingDriverId });
      return;
    }

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { setIsLoading(false); return; }

    const { data: profile } = await supabase
      .from('profiles')
      .select('id')
      .eq('user_id', user.id)
      .single();

    if (!profile) { setIsLoading(false); return; }

    const result = await createDriverProfile(profile.id as string, {
      vehicle_category:    vehicleCategory!,
      vehicle_brand:       vehicleBrand.trim(),
      vehicle_model:       vehicleModel.trim(),
      license_plate:       licensePlate.trim().toUpperCase(),
      vehicle_capacity_kg: parseInt(capacityKg.trim(), 10),
    });

    setIsLoading(false);

    if (result.error) {
      showMessage('Erreur', result.error);
      return;
    }

    setExistingDriverId((result.driver as any).id);
    navigation.navigate('LegalDocuments', { driverId: (result.driver as any).id });
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <LogoutButton />
      <Text style={styles.step}>Étape 1 sur 4</Text>
      <View style={styles.progressBar}>
        <View style={[styles.progressFill, { width: '25%' }]} />
      </View>

      <Text style={styles.title}>Votre véhicule</Text>

      {/* Category selector */}
      <View style={styles.categoryRow}>
        {VEHICLE_CATEGORIES.map(cat => (
          <TouchableOpacity
            key={cat.value}
            style={[
              styles.categoryCard,
              vehicleCategory === cat.value && styles.categoryCardSelected,
            ]}
            onPress={() => setVehicleCategory(cat.value)}
          >
            <Text style={styles.categoryIcon}>{cat.icon}</Text>
            <Text style={styles.categoryLabel}>{cat.label_fr}</Text>
            <Text style={styles.categoryDesc}>{cat.description}</Text>
            <Text style={styles.categoryCommission}>
              {commissions[cat.value] !== undefined ? `${commissions[cat.value]} DH` : cat.commission}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <TextInput
        style={styles.input}
        placeholder="Marque (ex: Mercedes)"
        value={vehicleBrand}
        onChangeText={setVehicleBrand}
      />
      <TextInput
        style={styles.input}
        placeholder="Modèle (ex: Sprinter)"
        value={vehicleModel}
        onChangeText={setVehicleModel}
      />
      <TextInput
        style={styles.input}
        placeholder="Plaque (ex: 12345-A-1)"
        value={licensePlate}
        onChangeText={t => setLicensePlate(t.toUpperCase())}
        autoCapitalize="characters"
      />
      <TextInput
        style={styles.input}
        placeholder="Capacité max (kg) — obligatoire"
        value={capacityKg}
        onChangeText={setCapacityKg}
        keyboardType="numeric"
      />

      <TouchableOpacity
        style={[styles.button, !isFormValid && styles.buttonDisabled]}
        onPress={handleNext}
        disabled={!isFormValid || isLoading}
      >
        {isLoading
          ? <ActivityIndicator color="#fff" />
          : <Text style={styles.buttonText}>Suivant →</Text>
        }
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container:          { padding: 20, paddingBottom: 40 },
  step:               { color: '#888', fontSize: 13, marginBottom: 6 },
  progressBar:        { height: 6, backgroundColor: '#E0E0E0', borderRadius: 3, marginBottom: 24 },
  progressFill:       { height: '100%', backgroundColor: COLORS.primary, borderRadius: 3 },
  title:              { fontSize: 22, fontWeight: '700', marginBottom: 20, color: '#1A1A2E' },
  categoryRow:        { flexDirection: 'row', gap: 10, marginBottom: 20 },
  categoryCard:       {
    flex: 1, borderWidth: 1.5, borderColor: '#DDD', borderRadius: 12,
    padding: 10, alignItems: 'center',
  },
  categoryCardSelected: { borderColor: COLORS.primary, backgroundColor: '#F0F4FF' },
  categoryIcon:       { fontSize: 24 },
  categoryLabel:      { fontWeight: '700', fontSize: 13, marginTop: 4, color: '#1A1A2E' },
  categoryDesc:       { fontSize: 10, color: '#666', textAlign: 'center' },
  categoryCommission: { fontSize: 11, color: COLORS.primary, fontWeight: '600', marginTop: 2 },
  input:              {
    borderWidth: 1, borderColor: '#DDD', borderRadius: 10,
    padding: 14, marginBottom: 14, fontSize: 15, backgroundColor: '#FAFAFA',
  },
  button:             {
    backgroundColor: COLORS.primary, borderRadius: 12,
    padding: 16, alignItems: 'center', marginTop: 8,
  },
  buttonDisabled:     { backgroundColor: '#B0BEC5' },
  buttonText:         { color: '#fff', fontWeight: '700', fontSize: 16 },
});
