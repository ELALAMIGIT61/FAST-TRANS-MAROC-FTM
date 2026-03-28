import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  ScrollView,
  TouchableOpacity,
  Switch,
  StyleSheet,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { COLORS } from '../../constants/theme';
import {
  calculateVolume,
  recommendVehicleCategory,
  formatVolume,
  validateParcelDimensions,
} from '../../utils/parcelCalculations';
import { createParcelMission } from '../../services/parcelService';
import { supabase } from '../../lib/supabaseClient';

type VehicleCategory = 'vul' | 'n2_medium' | 'n2_large';

interface FormState {
  senderName: string;
  senderPhone: string;
  recipientName: string;
  recipientPhone: string;
  lengthCm: string;
  widthCm: string;
  heightCm: string;
  weightKg: string;
  volumeM3: number;
  isFragile: boolean;
  contentDescription: string;
  pickupCity: string;
  pickupAddress: string;
  pickupLat: number | null;
  pickupLng: number | null;
  dropoffCity: string;
  dropoffAddress: string;
  dropoffLat: number | null;
  dropoffLng: number | null;
  recommendedCategory: VehicleCategory;
  selectedCategory: VehicleCategory;
  negotiatedPrice: string;
  dimensionErrors: Record<string, string> | null;
  isLoading: boolean;
}

const VEHICLE_LABELS: Record<VehicleCategory, string> = {
  vul: '🚐 VUL',
  n2_medium: '🚛 N2 Med',
  n2_large: '🚚 N2 Lrg',
};

export default function CreateParcelScreen(): JSX.Element {
  const navigation = useNavigation<any>();
  const [state, setState] = useState<FormState>({
    senderName: '',
    senderPhone: '',
    recipientName: '',
    recipientPhone: '',
    lengthCm: '',
    widthCm: '',
    heightCm: '',
    weightKg: '',
    volumeM3: 0,
    isFragile: false,
    contentDescription: '',
    pickupCity: '',
    pickupAddress: '',
    pickupLat: null,
    pickupLng: null,
    dropoffCity: '',
    dropoffAddress: '',
    dropoffLat: null,
    dropoffLng: null,
    recommendedCategory: 'vul',
    selectedCategory: 'vul',
    negotiatedPrice: '',
    dimensionErrors: null,
    isLoading: false,
  });

  useEffect(() => {
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data: profile } = await supabase
        .from('profiles')
        .select('full_name, phone_number')
        .eq('id', user.id)
        .single();
      if (profile) {
        setState(prev => ({
          ...prev,
          senderName: profile.full_name || '',
          senderPhone: profile.phone_number || '',
        }));
      }
    })();
  }, []);

  function onDimensionChange(field: keyof FormState, value: string) {
    setState(prev => {
      const dims = {
        lengthCm: field === 'lengthCm' ? value : prev.lengthCm,
        widthCm: field === 'widthCm' ? value : prev.widthCm,
        heightCm: field === 'heightCm' ? value : prev.heightCm,
        weightKg: field === 'weightKg' ? value : prev.weightKg,
      };
      const vol = calculateVolume(dims.lengthCm, dims.widthCm, dims.heightCm);
      const cat = recommendVehicleCategory(vol, dims.weightKg);

      console.log('[FTM-DEBUG] Parcel - Dimensions updated', {
        field,
        value,
        volumeM3: vol,
        recommended: cat,
      });

      return {
        ...prev,
        [field]: value,
        volumeM3: vol,
        recommendedCategory: cat,
        selectedCategory: cat,
      };
    });
  }

  const isFormValid =
    state.senderName.trim() &&
    state.senderPhone.trim() &&
    state.recipientName.trim() &&
    state.recipientPhone.trim() &&
    state.lengthCm.trim() &&
    state.widthCm.trim() &&
    state.heightCm.trim() &&
    state.weightKg.trim() &&
    state.contentDescription.trim() &&
    state.pickupCity.trim() &&
    state.dropoffCity.trim();

  async function handleSubmit() {
    const dimErrors = validateParcelDimensions(
      state.lengthCm,
      state.widthCm,
      state.heightCm,
      state.weightKg
    );
    if (dimErrors) {
      setState(prev => ({ ...prev, dimensionErrors: dimErrors }));
      return;
    }

    setState(prev => ({ ...prev, isLoading: true, dimensionErrors: null }));

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      setState(prev => ({ ...prev, isLoading: false }));
      Alert.alert('Erreur', 'Vous devez être connecté.');
      return;
    }

    const result = await createParcelMission(user.id, {
      sender_name: state.senderName,
      sender_phone: state.senderPhone,
      recipient_name: state.recipientName,
      recipient_phone: state.recipientPhone,
      length_cm: state.lengthCm,
      width_cm: state.widthCm,
      height_cm: state.heightCm,
      weight_kg: state.weightKg,
      is_fragile: state.isFragile,
      content_description: state.contentDescription,
      vehicle_category: state.selectedCategory,
      pickup_city: state.pickupCity,
      pickup_address: state.pickupAddress,
      pickup_lat: state.pickupLat ?? undefined,
      pickup_lng: state.pickupLng ?? undefined,
      dropoff_city: state.dropoffCity,
      dropoff_address: state.dropoffAddress,
      dropoff_lat: state.dropoffLat ?? undefined,
      dropoff_lng: state.dropoffLng ?? undefined,
      negotiated_price: state.negotiatedPrice || null,
    });

    setState(prev => ({ ...prev, isLoading: false }));

    if (result.error) {
      Alert.alert('Erreur', result.error);
      return;
    }

    navigation.navigate('ParcelConfirmation', {
      trackingNumber: result.trackingNumber,
      mission: result.mission,
      parcel: result.parcel,
    });
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>Envoyer un colis</Text>

      {/* EXPÉDITEUR */}
      <Text style={styles.sectionTitle}>Expéditeur</Text>
      <TextInput
        style={styles.input}
        placeholder="Votre nom"
        value={state.senderName}
        onChangeText={v => setState(prev => ({ ...prev, senderName: v }))}
      />
      <TextInput
        style={styles.input}
        placeholder="Votre téléphone"
        value={state.senderPhone}
        keyboardType="phone-pad"
        onChangeText={v => setState(prev => ({ ...prev, senderPhone: v }))}
      />

      {/* DESTINATAIRE */}
      <Text style={styles.sectionTitle}>Destinataire</Text>
      <TextInput
        style={styles.input}
        placeholder="Nom du destinataire *"
        value={state.recipientName}
        onChangeText={v => setState(prev => ({ ...prev, recipientName: v }))}
      />
      <TextInput
        style={styles.input}
        placeholder="+212 6XX XXX XXX *"
        value={state.recipientPhone}
        keyboardType="phone-pad"
        onChangeText={v => setState(prev => ({ ...prev, recipientPhone: v }))}
      />

      {/* DIMENSIONS */}
      <Text style={styles.sectionTitle}>Dimensions du colis</Text>
      <View style={styles.row}>
        <TextInput
          style={[styles.input, styles.flex1, state.dimensionErrors?.length ? styles.inputError : null]}
          placeholder="L (cm) *"
          value={state.lengthCm}
          keyboardType="numeric"
          onChangeText={v => onDimensionChange('lengthCm', v)}
        />
        <TextInput
          style={[styles.input, styles.flex1, state.dimensionErrors?.width ? styles.inputError : null]}
          placeholder="l (cm) *"
          value={state.widthCm}
          keyboardType="numeric"
          onChangeText={v => onDimensionChange('widthCm', v)}
        />
        <TextInput
          style={[styles.input, styles.flex1, state.dimensionErrors?.height ? styles.inputError : null]}
          placeholder="h (cm) *"
          value={state.heightCm}
          keyboardType="numeric"
          onChangeText={v => onDimensionChange('heightCm', v)}
        />
      </View>
      {state.dimensionErrors?.length && <Text style={styles.errorText}>{state.dimensionErrors.length}</Text>}
      {state.dimensionErrors?.width && <Text style={styles.errorText}>{state.dimensionErrors.width}</Text>}
      {state.dimensionErrors?.height && <Text style={styles.errorText}>{state.dimensionErrors.height}</Text>}

      <TextInput
        style={[styles.input, state.dimensionErrors?.weight ? styles.inputError : null]}
        placeholder="Poids (kg) *"
        value={state.weightKg}
        keyboardType="numeric"
        onChangeText={v => onDimensionChange('weightKg', v)}
      />
      {state.dimensionErrors?.weight && <Text style={styles.errorText}>{state.dimensionErrors.weight}</Text>}

      {state.volumeM3 > 0 && (
        <View style={styles.volumeCard}>
          <Text style={styles.volumeText}>📦 Volume calculé : {formatVolume(state.volumeM3)}</Text>
        </View>
      )}

      <View style={styles.fragileRow}>
        <Text style={styles.fragileLabel}>⚠️ Colis fragile</Text>
        <Switch
          value={state.isFragile}
          onValueChange={v => setState(prev => ({ ...prev, isFragile: v }))}
          trackColor={{ true: (COLORS as any).cta || '#F59E0B' }}
        />
      </View>
      {state.isFragile && (
        <Text style={styles.fragileNote}>Manipulation avec précaution requise</Text>
      )}

      {/* CONTENU */}
      <Text style={styles.sectionTitle}>Contenu</Text>
      <TextInput
        style={[styles.input, styles.multiline]}
        placeholder='Description du contenu * (ex: "Vêtements, 3 cartons")'
        value={state.contentDescription}
        multiline
        numberOfLines={3}
        onChangeText={v => setState(prev => ({ ...prev, contentDescription: v }))}
      />

      {/* ITINÉRAIRE */}
      <Text style={styles.sectionTitle}>Itinéraire</Text>
      <TextInput
        style={styles.input}
        placeholder="📍 Ville de départ *"
        value={state.pickupCity}
        onChangeText={v => setState(prev => ({ ...prev, pickupCity: v }))}
      />
      <TextInput
        style={styles.input}
        placeholder="🏁 Ville d'arrivée *"
        value={state.dropoffCity}
        onChangeText={v => setState(prev => ({ ...prev, dropoffCity: v }))}
      />

      {/* VÉHICULE RECOMMANDÉ */}
      <Text style={styles.sectionTitle}>Véhicule recommandé</Text>
      {state.volumeM3 > 0 && (
        <Text style={styles.recommendText}>
          💡 Pour ce colis, nous recommandons : {VEHICLE_LABELS[state.recommendedCategory]}
        </Text>
      )}
      <View style={styles.row}>
        {(['vul', 'n2_medium', 'n2_large'] as VehicleCategory[]).map(cat => (
          <TouchableOpacity
            key={cat}
            style={[
              styles.categoryBtn,
              state.selectedCategory === cat && styles.categoryBtnActive,
            ]}
            onPress={() => setState(prev => ({ ...prev, selectedCategory: cat }))}
          >
            <Text style={[
              styles.categoryBtnText,
              state.selectedCategory === cat && styles.categoryBtnTextActive,
            ]}>
              {VEHICLE_LABELS[cat]}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <TextInput
        style={styles.input}
        placeholder="Prix proposé (DH) — optionnel"
        value={state.negotiatedPrice}
        keyboardType="numeric"
        onChangeText={v => setState(prev => ({ ...prev, negotiatedPrice: v }))}
      />

      <TouchableOpacity
        style={[styles.submitBtn, !isFormValid && styles.submitBtnDisabled]}
        onPress={handleSubmit}
        disabled={!isFormValid || state.isLoading}
      >
        {state.isLoading
          ? <ActivityIndicator color="#fff" />
          : <Text style={styles.submitBtnText}>Envoyer ce colis →</Text>
        }
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F9FAFB' },
  content: { padding: 16, paddingBottom: 40 },
  title: { fontSize: 22, fontWeight: '700', color: '#111827', marginBottom: 20 },
  sectionTitle: { fontSize: 13, fontWeight: '600', color: '#6B7280', textTransform: 'uppercase', marginTop: 20, marginBottom: 8 },
  input: { backgroundColor: '#fff', borderWidth: 1, borderColor: '#E5E7EB', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 10, fontSize: 15, marginBottom: 8 },
  inputError: { borderColor: '#EF4444' },
  errorText: { color: '#EF4444', fontSize: 12, marginTop: -4, marginBottom: 6 },
  row: { flexDirection: 'row', gap: 8 },
  flex1: { flex: 1 },
  multiline: { minHeight: 80, textAlignVertical: 'top' },
  volumeCard: { backgroundColor: '#EFF6FF', borderRadius: 8, padding: 10, marginBottom: 8 },
  volumeText: { color: '#1D4ED8', fontWeight: '600', fontSize: 14 },
  fragileRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginVertical: 8 },
  fragileLabel: { fontSize: 15, color: '#374151' },
  fragileNote: { color: '#F59E0B', fontSize: 13, marginBottom: 8 },
  recommendText: { color: '#374151', fontSize: 14, marginBottom: 8 },
  categoryBtn: { flex: 1, padding: 10, borderRadius: 8, borderWidth: 1, borderColor: '#E5E7EB', alignItems: 'center', backgroundColor: '#fff' },
  categoryBtnActive: { borderColor: '#2563EB', backgroundColor: '#EFF6FF' },
  categoryBtnText: { fontSize: 13, color: '#6B7280', fontWeight: '500' },
  categoryBtnTextActive: { color: '#2563EB', fontWeight: '700' },
  submitBtn: { marginTop: 24, backgroundColor: '#2563EB', borderRadius: 12, height: 52, alignItems: 'center', justifyContent: 'center' },
  submitBtnDisabled: { backgroundColor: '#93C5FD' },
  submitBtnText: { color: '#fff', fontSize: 16, fontWeight: '700' },
});
