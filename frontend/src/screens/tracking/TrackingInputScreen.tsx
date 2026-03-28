import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { getParcelByTrackingNumber } from '../../services/parcelService';

function autoFormatTracking(raw: string): string {
  let cleaned = raw.toUpperCase().replace(/[\s\-_]/g, '');
  if (cleaned.startsWith('FTMTRACK')) {
    cleaned = 'FTM-TRACK-' + cleaned.replace('FTMTRACK', '');
  } else if (!cleaned.startsWith('FTM')) {
    cleaned = 'FTM-TRACK-' + cleaned;
  }
  return cleaned;
}

export default function TrackingInputScreen(): JSX.Element {
  const navigation = useNavigation<any>();
  const [trackingInput, setTrackingInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSearch() {
    const formatted = autoFormatTracking(trackingInput);

    console.log('[FTM-DEBUG] Tracking - Search initiated', {
      raw: trackingInput,
      formatted,
    });

    if (formatted.length < 18) {
      console.log('[FTM-DEBUG] Tracking - Invalid format', { formatted });
      setError('Format invalide. Exemple : FTM-TRACK-K7X2MQ4R');
      return;
    }

    setIsLoading(true);
    setError(null);

    const result = await getParcelByTrackingNumber(formatted);
    setIsLoading(false);

    if (result.error) {
      console.log('[FTM-DEBUG] Tracking - Not found', { formatted, error: result.error });
      setError(result.error);
      return;
    }

    console.log('[FTM-DEBUG] Tracking - Found, navigating to details', {
      trackingNumber: formatted,
      status: result.parcel?.mission_status,
    });

    navigation.navigate('TrackingDetail', { trackingNumber: formatted });
  }

  return (
    <View style={styles.container}>
      <Text style={styles.logo}>📦 FTM</Text>
      <Text style={styles.title}>Suivre votre colis</Text>

      <TextInput
        style={[styles.input, error ? styles.inputError : null]}
        placeholder="FTM-TRACK-XXXXXXXX"
        value={trackingInput}
        autoCapitalize="characters"
        onChangeText={v => {
          setTrackingInput(v);
          setError(null);
        }}
        onSubmitEditing={handleSearch}
        returnKeyType="search"
      />
      {error && <Text style={styles.errorText}>{error}</Text>}

      <TouchableOpacity
        style={styles.searchBtn}
        onPress={handleSearch}
        disabled={isLoading || !trackingInput.trim()}
      >
        {isLoading
          ? <ActivityIndicator color="#fff" />
          : <Text style={styles.searchBtnText}>Rechercher</Text>
        }
      </TouchableOpacity>

      <Text style={styles.orText}>── OU ──</Text>

      <TouchableOpacity style={styles.qrBtn} onPress={() => Alert.alert('Scanner QR', 'Fonctionnalité disponible prochainement.')}>
        <Text style={styles.qrBtnText}>📷 Scanner le QR code</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F9FAFB', padding: 24, justifyContent: 'center', alignItems: 'center' },
  logo: { fontSize: 48, marginBottom: 8 },
  title: { fontSize: 24, fontWeight: '700', color: '#111827', marginBottom: 24 },
  input: { width: '100%', backgroundColor: '#fff', borderWidth: 1.5, borderColor: '#E5E7EB', borderRadius: 10, paddingHorizontal: 16, paddingVertical: 14, fontSize: 18, letterSpacing: 1, textAlign: 'center', marginBottom: 8 },
  inputError: { borderColor: '#EF4444' },
  errorText: { color: '#EF4444', fontSize: 13, marginBottom: 12, textAlign: 'center' },
  searchBtn: { width: '100%', backgroundColor: '#2563EB', borderRadius: 12, height: 52, alignItems: 'center', justifyContent: 'center', marginBottom: 20 },
  searchBtnText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  orText: { color: '#9CA3AF', fontSize: 14, marginBottom: 20 },
  qrBtn: { width: '100%', borderWidth: 1.5, borderColor: '#2563EB', borderRadius: 12, height: 52, alignItems: 'center', justifyContent: 'center' },
  qrBtnText: { color: '#2563EB', fontSize: 15, fontWeight: '600' },
});
