// /screens/driver/onboarding/LegalDocumentsScreen.tsx
// Fast Trans Maroc — P2 — Step 2

import React, { useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity,
  ScrollView, StyleSheet, ActivityIndicator, Alert, Platform,
} from 'react-native';
import DateTimePicker from '@react-native-community/datetimepicker';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { saveDriverDocuments } from '../../../services/driverService';
import { COLORS } from '../../../constants/theme';

type Props = {
  navigation: NativeStackNavigationProp<any>;
  route:      RouteProp<{ LegalDocuments: { driverId: string } }, 'LegalDocuments'>;
};

function formatDateForSQL(date: Date | null): string | null {
  if (!date) return null;
  return date.toISOString().split('T')[0];
}

function validateExpiryDate(date: Date | null, label: string): string | null {
  if (!date) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  if (date < today) {
    console.log('[FTM-DEBUG] Document - Expired date detected', {
      documentLabel: label, expiry: date.toISOString(),
    });
    return `${label} est déjà expiré(e). Renouvelez-le avant de vous inscrire.`;
  }
  return null;
}

interface DateFieldProps {
  label: string;
  value: Date | null;
  onChange: (d: Date) => void;
  error?: string | null;
}

function DateField({ label, value, onChange, error }: DateFieldProps) {
  const [show, setShow] = useState(false);

  return (
    <View style={{ marginBottom: 14 }}>
      <Text style={dfStyles.label}>{label}</Text>
      <TouchableOpacity
        style={[dfStyles.picker, error ? dfStyles.pickerError : null]}
        onPress={() => setShow(true)}
      >
        <Text style={{ color: value ? '#1A1A2E' : '#999', fontSize: 15 }}>
          {value ? value.toLocaleDateString('fr-FR') : 'Sélectionner une date'}
        </Text>
      </TouchableOpacity>
      {show && (
        <DateTimePicker
          value={value ?? new Date()}
          mode="date"
          display={Platform.OS === 'ios' ? 'spinner' : 'default'}
          minimumDate={new Date()}
          onChange={(_e, d) => { setShow(false); if (d) onChange(d); }}
        />
      )}
      {error ? <Text style={dfStyles.errorText}>{error}</Text> : null}
    </View>
  );
}

const dfStyles = StyleSheet.create({
  label:       { fontSize: 13, color: '#666', marginBottom: 4 },
  picker:      {
    borderWidth: 1, borderColor: '#DDD', borderRadius: 10,
    padding: 14, backgroundColor: '#FAFAFA',
  },
  pickerError: { borderColor: '#DC3545' },
  errorText:   { color: '#DC3545', fontSize: 12, marginTop: 4 },
});

export default function LegalDocumentsScreen({ navigation, route }: Props) {
  const { driverId } = route.params;

  const [licenseNumber,   setLicenseNumber]   = useState('');
  const [licenseExpiry,   setLicenseExpiry]   = useState<Date | null>(null);
  const [regNumber,       setRegNumber]       = useState('');
  const [insuranceNumber, setInsuranceNumber] = useState('');
  const [insuranceExpiry, setInsuranceExpiry] = useState<Date | null>(null);
  const [techExpiry,      setTechExpiry]      = useState<Date | null>(null);
  const [isLoading,       setIsLoading]       = useState(false);

  const licenseExpiryError   = validateExpiryDate(licenseExpiry,   'Le permis de conduire');
  const insuranceExpiryError = validateExpiryDate(insuranceExpiry, "L'assurance");
  const techExpiryError      = validateExpiryDate(techExpiry,      'La visite technique');

  const hasErrors = Boolean(licenseExpiryError || insuranceExpiryError || techExpiryError);
  const isFormValid =
    licenseNumber.trim() && licenseExpiry &&
    regNumber.trim() &&
    insuranceNumber.trim() && insuranceExpiry &&
    techExpiry && !hasErrors;

  async function handleNext() {
    if (!isFormValid) return;
    setIsLoading(true);

    const result = await saveDriverDocuments(driverId, {
      driver_license_number:       licenseNumber.trim(),
      driver_license_expiry:       formatDateForSQL(licenseExpiry)!,
      vehicle_registration_number: regNumber.trim(),
      insurance_number:            insuranceNumber.trim(),
      insurance_expiry:            formatDateForSQL(insuranceExpiry)!,
      technical_inspection_expiry: formatDateForSQL(techExpiry)!,
    });

    setIsLoading(false);

    if (result.error) {
      Alert.alert('Erreur', result.error);
      return;
    }

    navigation.navigate('DocumentUpload', { driverId });
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.step}>Étape 2 sur 4</Text>
      <View style={styles.progressBar}>
        <View style={[styles.progressFill, { width: '50%' }]} />
      </View>

      <Text style={styles.title}>Documents légaux</Text>

      <Text style={styles.sectionTitle}>🪪 Permis de conduire</Text>
      <TextInput
        style={styles.input}
        placeholder="Numéro de permis"
        value={licenseNumber}
        onChangeText={setLicenseNumber}
      />
      <DateField
        label="Date d'expiration"
        value={licenseExpiry}
        onChange={setLicenseExpiry}
        error={licenseExpiryError}
      />

      <Text style={styles.sectionTitle}>📄 Carte grise</Text>
      <TextInput
        style={styles.input}
        placeholder="Numéro d'immatriculation"
        value={regNumber}
        onChangeText={setRegNumber}
      />

      <Text style={styles.sectionTitle}>🛡️ Assurance</Text>
      <TextInput
        style={styles.input}
        placeholder="Numéro de police"
        value={insuranceNumber}
        onChangeText={setInsuranceNumber}
      />
      <DateField
        label="Date d'expiration"
        value={insuranceExpiry}
        onChange={setInsuranceExpiry}
        error={insuranceExpiryError}
      />

      <Text style={styles.sectionTitle}>🔧 Visite technique</Text>
      <DateField
        label="Date d'expiration"
        value={techExpiry}
        onChange={setTechExpiry}
        error={techExpiryError}
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
  container:     { padding: 20, paddingBottom: 40 },
  step:          { color: '#888', fontSize: 13, marginBottom: 6 },
  progressBar:   { height: 6, backgroundColor: '#E0E0E0', borderRadius: 3, marginBottom: 24 },
  progressFill:  { height: '100%', backgroundColor: COLORS.primary, borderRadius: 3 },
  title:         { fontSize: 22, fontWeight: '700', marginBottom: 20, color: '#1A1A2E' },
  sectionTitle:  { fontSize: 15, fontWeight: '700', color: '#1A1A2E', marginBottom: 10, marginTop: 6 },
  input:         {
    borderWidth: 1, borderColor: '#DDD', borderRadius: 10,
    padding: 14, marginBottom: 14, fontSize: 15, backgroundColor: '#FAFAFA',
  },
  button:        {
    backgroundColor: COLORS.primary, borderRadius: 12,
    padding: 16, alignItems: 'center', marginTop: 8,
  },
  buttonDisabled: { backgroundColor: '#B0BEC5' },
  buttonText:    { color: '#fff', fontWeight: '700', fontSize: 16 },
});
