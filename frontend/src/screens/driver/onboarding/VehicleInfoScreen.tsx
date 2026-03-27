// /screens/driver/onboarding/VehicleInfoScreen.tsx
// Fast Trans Maroc — P2 — Step 1

import React, { useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity,
  ScrollView, StyleSheet, ActivityIndicator, Alert,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { createDriverProfile, VehicleCategory } from '../../../services/driverService';
import { supabase } from '../../../lib/supabaseClient';
import { COLORS } from '../../../constants/theme';

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
  const [vehicleBrand,    setVehicleBrand]    = useState('');
  const [vehicleModel,    setVehicleModel]    = useState('');
  const [licensePlate,    setLicensePlate]    = useState('');
  const [capacityKg,      setCapacityKg]      = useState('');
  const [isLoading,       setIsLoading]       = useState(false);

  const isFormValid =
    vehicleCategory !== null &&
    licensePlate.trim().length > 0 &&
    LICENSE_PLATE_REGEX.test(licensePlate.trim().toUpperCase());

  async function handleNext() {
    if (!isFormValid) return;
    setIsLoading(true);

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
      vehicle_capacity_kg: capacityKg ? parseInt(capacityKg, 10) : 0,
    });

    setIsLoading(false);

    if (result.error) {
      Alert.alert('Erreur', result.error);
      return;
    }

    navigation.navigate('LegalDocuments', { driverId: (result.driver as any).id });
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
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
            <Text style={styles.categoryCommission}>{cat.commission}</Text>
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
        placeholder="Capacité max (kg)"
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
