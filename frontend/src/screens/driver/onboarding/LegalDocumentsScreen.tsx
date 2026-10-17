// /screens/driver/onboarding/LegalDocumentsScreen.tsx
// Fast Trans Maroc — P2 — Step 2
// Volet 4b-5 : dates de la carte grise (expiration + 1re mise en circulation),
// saisie des dates sans decalage de fuseau (DateOnlyField), NB visite technique.

import React, { useState } from 'react';
import BackButton from '../../../components/BackButton';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import { showMessage } from '../../../utils/dialogs';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RouteProp } from '@react-navigation/native';
import { saveDriverDocuments } from '../../../services/driverService';
import { saveRegistrationDates } from '../../../services/documentService';
import DateOnlyField, { todayIsoDate } from '../../../components/DateOnlyField';
import { COLORS } from '../../../constants/theme';

type Props = {
  navigation: NativeStackNavigationProp<any>;
  route:      RouteProp<{ LegalDocuments: { driverId: string } }, 'LegalDocuments'>;
};

const TECHNICAL_INSPECTION_HINT =
  "NB : véhicule de moins de 5 ans — indiquez la date à laquelle la visite " +
  "technique deviendra obligatoire (date de 1re mise en circulation + 5 ans) " +
  "et déposez, à l'étape suivante, une 2e copie de la carte grise à la place " +
  "de la visite technique.";

// Dates au format 'YYYY-MM-DD' : la comparaison de chaines suffit.
function validateExpiryDate(value: string | null, label: string): string | null {
  if (!value) return null;
  if (value < todayIsoDate()) {
    console.log('[FTM-DEBUG] Document - Expired date detected', {
      documentLabel: label, expiry: value,
    });
    return `${label} est déjà expiré(e). Renouvelez-le avant de vous inscrire.`;
  }
  return null;
}

function validatePastDate(value: string | null): string | null {
  if (!value) return null;
  if (value > todayIsoDate()) {
    return 'La date de 1re mise en circulation ne peut pas être dans le futur.';
  }
  return null;
}

export default function LegalDocumentsScreen({ navigation, route }: Props) {
  const { driverId } = route.params;

  const [licenseNumber,    setLicenseNumber]    = useState('');
  const [licenseExpiry,    setLicenseExpiry]    = useState<string | null>(null);
  const [regNumber,        setRegNumber]        = useState('');
  const [regExpiry,        setRegExpiry]        = useState<string | null>(null);
  const [firstServiceDate, setFirstServiceDate] = useState<string | null>(null);
  const [insuranceNumber,  setInsuranceNumber]  = useState('');
  const [insuranceExpiry,  setInsuranceExpiry]  = useState<string | null>(null);
  const [techExpiry,       setTechExpiry]       = useState<string | null>(null);
  const [isLoading,        setIsLoading]        = useState(false);

  const today = todayIsoDate();

  const licenseExpiryError   = validateExpiryDate(licenseExpiry,   'Le permis de conduire');
  const regExpiryError       = validateExpiryDate(regExpiry,       'La carte grise');
  const firstServiceError    = validatePastDate(firstServiceDate);
  const insuranceExpiryError = validateExpiryDate(insuranceExpiry, "L'assurance");
  const techExpiryError      = validateExpiryDate(techExpiry,      'La visite technique');

  const hasErrors = Boolean(
    licenseExpiryError || regExpiryError || firstServiceError ||
    insuranceExpiryError || techExpiryError
  );
  const isFormValid =
    licenseNumber.trim() && licenseExpiry &&
    regNumber.trim() && regExpiry && firstServiceDate &&
    insuranceNumber.trim() && insuranceExpiry &&
    techExpiry && !hasErrors;

  async function handleNext() {
    if (!isFormValid) return;
    setIsLoading(true);

    const result = await saveDriverDocuments(driverId, {
      driver_license_number:       licenseNumber.trim(),
      driver_license_expiry:       licenseExpiry!,
      vehicle_registration_number: regNumber.trim(),
      insurance_number:            insuranceNumber.trim(),
      insurance_expiry:            insuranceExpiry!,
      technical_inspection_expiry: techExpiry!,
    });

    if (result.error) {
      setIsLoading(false);
      showMessage('Erreur', result.error);
      return;
    }

    const regResult = await saveRegistrationDates(driverId, regExpiry!, firstServiceDate!);

    setIsLoading(false);

    if (regResult.error) {
      showMessage('Erreur', regResult.error);
      return;
    }

    navigation.navigate('DocumentUpload', { driverId });
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <BackButton />
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
      <DateOnlyField
        label="Date d'expiration"
        value={licenseExpiry}
        onChange={setLicenseExpiry}
        minDate={today}
        error={licenseExpiryError}
      />

      <Text style={styles.sectionTitle}>📄 Carte grise</Text>
      <TextInput
        style={styles.input}
        placeholder="Numéro d'immatriculation"
        value={regNumber}
        onChangeText={setRegNumber}
      />
      <DateOnlyField
        label="Date d'expiration"
        value={regExpiry}
        onChange={setRegExpiry}
        minDate={today}
        error={regExpiryError}
      />
      <DateOnlyField
        label="Date de 1re mise en circulation"
        value={firstServiceDate}
        onChange={setFirstServiceDate}
        maxDate={today}
        error={firstServiceError}
      />

      <Text style={styles.sectionTitle}>🛡️ Assurance</Text>
      <TextInput
        style={styles.input}
        placeholder="Numéro de police"
        value={insuranceNumber}
        onChangeText={setInsuranceNumber}
      />
      <DateOnlyField
        label="Date d'expiration"
        value={insuranceExpiry}
        onChange={setInsuranceExpiry}
        minDate={today}
        error={insuranceExpiryError}
      />

      <Text style={styles.sectionTitle}>🔧 Visite technique</Text>
      <DateOnlyField
        label="Date d'expiration"
        value={techExpiry}
        onChange={setTechExpiry}
        minDate={today}
        hint={TECHNICAL_INSPECTION_HINT}
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
