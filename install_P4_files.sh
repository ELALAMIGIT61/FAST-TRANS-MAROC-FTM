#!/bin/bash
mkdir -p frontend/src/utils
cat > frontend/src/utils/parcelCalculations.ts << 'ENDOFFILE'
/**
 * CALCUL VOLUME CÔTÉ CLIENT (pour preview avant soumission)
 * La valeur réelle est recalculée par PostgreSQL (GENERATED ALWAYS)
 * Ici sert uniquement à l'affichage en temps réel dans le formulaire
 *
 * @returns {number} volume en m³, arrondi à 4 décimales
 */
export function calculateVolume(
  lengthCm: string | number,
  widthCm: string | number,
  heightCm: string | number
): number {
  const l = parseFloat(String(lengthCm)) || 0;
  const w = parseFloat(String(widthCm)) || 0;
  const h = parseFloat(String(heightCm)) || 0;
  if (l <= 0 || w <= 0 || h <= 0) return 0;
  return parseFloat(((l * w * h) / 1_000_000).toFixed(4));
}

/**
 * RECOMMANDER LA CATÉGORIE VÉHICULE selon le volume et poids du colis
 *
 * Logique métier FTM :
 *  - Colis ≤ 0.5 m³ et ≤ 50 kg  → VUL recommandé
 *  - Colis ≤ 2.0 m³ et ≤ 500 kg → N2 Medium recommandé
 *  - Colis > 2.0 m³ ou > 500 kg  → N2 Large recommandé
 */
export function recommendVehicleCategory(
  volumeM3: string | number,
  weightKg: string | number
): 'vul' | 'n2_medium' | 'n2_large' {
  const v = parseFloat(String(volumeM3)) || 0;
  const w = parseFloat(String(weightKg)) || 0;

  if (v <= 0.5 && w <= 50) return 'vul';
  if (v <= 2.0 && w <= 500) return 'n2_medium';
  return 'n2_large';
}

/**
 * FORMATER L'AFFICHAGE DU VOLUME
 * 0.0600 m³  → "60 litres (0.06 m³)"
 * 1.2000 m³  → "1 200 litres (1.20 m³)"
 */
export function formatVolume(volumeM3: number): string {
  const liters = (volumeM3 * 1000).toFixed(0);
  const m3 = volumeM3.toFixed(2);
  return `${parseInt(liters).toLocaleString('fr-MA')} litres (${m3} m³)`;
}

/**
 * VALIDER LES DIMENSIONS (limites raisonnables pour un colis)
 * Retourne un objet d'erreurs ou null si valide
 */
export function validateParcelDimensions(
  lengthCm: string | number,
  widthCm: string | number,
  heightCm: string | number,
  weightKg: string | number
): Record<string, string> | null {
  const errors: Record<string, string> = {};

  if (parseFloat(String(lengthCm)) > 300) errors.length = 'Longueur max : 300 cm';
  if (parseFloat(String(widthCm)) > 250) errors.width = 'Largeur max : 250 cm';
  if (parseFloat(String(heightCm)) > 250) errors.height = 'Hauteur max : 250 cm';
  if (parseFloat(String(weightKg)) > 5000) errors.weight = 'Poids max : 5 000 kg';

  if (parseFloat(String(lengthCm)) <= 0) errors.length = 'Longueur requise';
  if (parseFloat(String(widthCm)) <= 0) errors.width = 'Largeur requise';
  if (parseFloat(String(heightCm)) <= 0) errors.height = 'Hauteur requise';
  if (parseFloat(String(weightKg)) <= 0) errors.weight = 'Poids requis';

  return Object.keys(errors).length > 0 ? errors : null;
}

/**
 * FORMATER UN NUMÉRO DE TÉLÉPHONE MAROCAIN pour l'affichage
 * "+212612345678" → "06 12 34 56 78"
 */
export function formatPhoneDisplay(phone: string): string {
  const cleaned = phone.replace('+212', '0').replace(/\s/g, '');
  return cleaned.replace(/(\d{2})(?=\d)/g, '$1 ').trim();
}

/**
 * MASQUER UN NUMÉRO DE TÉLÉPHONE pour affichage public
 * "0612345678" → "06****78"
 */
export function maskPhone(phone: string): string {
  if (!phone || phone.length < 6) return '****';
  return phone.slice(0, 3) + '****' + phone.slice(-2);
}
ENDOFFILE

mkdir -p frontend/src/services
cat > frontend/src/services/parcelService.ts << 'ENDOFFILE'
import { supabase } from '../lib/supabaseClient';
import { createMission } from './missionService';
import {
  recommendVehicleCategory,
  calculateVolume,
} from '../utils/parcelCalculations';

export interface ParcelData {
  sender_name: string;
  sender_phone: string;
  recipient_name: string;
  recipient_phone: string;
  length_cm: string | number;
  width_cm: string | number;
  height_cm: string | number;
  weight_kg: string | number;
  is_fragile?: boolean;
  content_description: string;
  vehicle_category?: string;
  pickup_lat?: number;
  pickup_lng?: number;
  pickup_address?: string;
  pickup_city?: string;
  dropoff_lat?: number;
  dropoff_lng?: number;
  dropoff_address?: string;
  dropoff_city?: string;
  negotiated_price?: string | null;
  client_notes?: string | null;
}

/**
 * CRÉER UNE MISSION E-COMMERCE AVEC SON COLIS
 * Flux en 2 étapes atomiques :
 *   1. INSERT dans missions (mission_type = 'ecommerce_parcel')
 *   2. INSERT dans ecommerce_parcels lié à la mission
 */
export async function createParcelMission(
  clientProfileId: string,
  parcelData: ParcelData
): Promise<{ success?: boolean; mission?: any; parcel?: any; trackingNumber?: string; error?: string }> {
  console.log('[FTM-DEBUG] Parcel - Creating parcel mission', {
    clientId: clientProfileId,
    senderName: parcelData.sender_name,
    recipientName: parcelData.recipient_name,
    recipientPhone: parcelData.recipient_phone,
    dimensions: `${parcelData.length_cm}×${parcelData.width_cm}×${parcelData.height_cm} cm`,
    weightKg: parcelData.weight_kg,
    volumeM3: calculateVolume(parcelData.length_cm, parcelData.width_cm, parcelData.height_cm),
    isFragile: parcelData.is_fragile,
    vehicleCategory: parcelData.vehicle_category,
    pickupCity: parcelData.pickup_city,
    dropoffCity: parcelData.dropoff_city,
  });

  // ── ÉTAPE 1 : Créer la mission parent ──────────────────────────────
  const missionResult = await createMission(clientProfileId, {
    mission_type: 'ecommerce_parcel',
    vehicle_category: parcelData.vehicle_category,
    pickup_lat: parcelData.pickup_lat,
    pickup_lng: parcelData.pickup_lng,
    pickup_address: parcelData.pickup_address,
    pickup_city: parcelData.pickup_city,
    dropoff_lat: parcelData.dropoff_lat,
    dropoff_lng: parcelData.dropoff_lng,
    dropoff_address: parcelData.dropoff_address,
    dropoff_city: parcelData.dropoff_city,
    description: `Colis e-commerce : ${parcelData.content_description}`,
    needs_loading_help: false,
    negotiated_price: parcelData.negotiated_price || null,
    client_notes: parcelData.client_notes || null,
  });

  if (missionResult.error) {
    console.log('[FTM-DEBUG] Parcel - Mission creation failed', {
      error: missionResult.error,
    });
    return { error: missionResult.error };
  }

  const mission = missionResult.mission;
  console.log('[FTM-DEBUG] Parcel - Parent mission created', {
    missionId: mission.id,
    missionNumber: mission.mission_number,
    commission: mission.commission_amount,
  });

  // ── ÉTAPE 2 : Créer le colis lié à la mission ──────────────────────
  const { data: parcel, error: parcelError } = await supabase
    .from('ecommerce_parcels')
    .insert({
      mission_id: mission.id,
      sender_name: parcelData.sender_name,
      sender_phone: parcelData.sender_phone,
      recipient_name: parcelData.recipient_name,
      recipient_phone: parcelData.recipient_phone,
      length_cm: parseFloat(String(parcelData.length_cm)),
      width_cm: parseFloat(String(parcelData.width_cm)),
      height_cm: parseFloat(String(parcelData.height_cm)),
      weight_kg: parseFloat(String(parcelData.weight_kg)),
      // volume_m3 : calculé automatiquement par PostgreSQL (GENERATED ALWAYS)
      content_description: parcelData.content_description,
      is_fragile: parcelData.is_fragile || false,
      // tracking_number : assigné automatiquement par trigger_set_tracking_number
    })
    .select()
    .single();

  if (parcelError) {
    console.log('[FTM-DEBUG] Parcel - Parcel insert error', {
      error: parcelError.message,
      missionId: mission.id,
    });
    // Rollback : annuler la mission créée à l'étape 1
    await supabase
      .from('missions')
      .update({ status: 'cancelled_client' })
      .eq('id', mission.id);

    console.log('[FTM-DEBUG] Parcel - Mission rolled back after parcel error', {
      missionId: mission.id,
    });
    return { error: 'Erreur lors de la création du colis. Réessayez.' };
  }

  console.log('[FTM-DEBUG] Parcel - Parcel created successfully', {
    parcelId: parcel.id,
    trackingNumber: parcel.tracking_number,
    volumeM3: parcel.volume_m3,
    missionId: mission.id,
  });

  // ── ÉTAPE 3 : Notifier le destinataire par SMS ─────────────────────
  await notifyRecipientBySMS(parcel, mission);

  return {
    success: true,
    mission,
    parcel,
    trackingNumber: parcel.tracking_number,
  };
}

/**
 * NOTIFIER LE DESTINATAIRE PAR SMS
 */
async function notifyRecipientBySMS(parcel: any, mission: any): Promise<void> {
  console.log('[FTM-DEBUG] Parcel - Sending SMS to recipient', {
    recipientPhone: parcel.recipient_phone,
    recipientName: parcel.recipient_name,
    trackingNumber: parcel.tracking_number,
    pickupCity: mission.pickup_city,
    dropoffCity: mission.dropoff_city,
  });

  try {
    const { error } = await supabase.functions.invoke('send-tracking-sms', {
      body: {
        to: parcel.recipient_phone,
        recipient_name: parcel.recipient_name,
        tracking_number: parcel.tracking_number,
        pickup_city: mission.pickup_city,
        dropoff_city: mission.dropoff_city,
      },
    });

    if (error) {
      console.log('[FTM-DEBUG] Parcel - SMS send error', { error: error.message });
    } else {
      console.log('[FTM-DEBUG] Parcel - SMS sent to recipient', {
        trackingNumber: parcel.tracking_number,
        phone: parcel.recipient_phone,
      });
    }
  } catch (err: any) {
    console.log('[FTM-DEBUG] Parcel - SMS exception', { err: err.message });
  }
}

/**
 * RÉCUPÉRER LES INFOS D'UN COLIS PAR TRACKING NUMBER
 * Accessible SANS authentification (destinataire non-utilisateur)
 */
export async function getParcelByTrackingNumber(
  trackingNumber: string
): Promise<{ success?: boolean; parcel?: any; error?: string }> {
  const normalized = trackingNumber.trim().toUpperCase();

  console.log('[FTM-DEBUG] Parcel - Fetching parcel by tracking number', {
    trackingNumber: normalized,
  });

  const { data, error } = await supabase
    .from('public_parcel_tracking')
    .select('*')
    .eq('tracking_number', normalized)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Parcel - Tracking fetch error', {
      trackingNumber: normalized,
      error: error.message,
      errorCode: error.code,
    });
    if (error.code === 'PGRST116') {
      return { error: 'Numéro de suivi introuvable. Vérifiez le format : FTM-TRACK-XXXXXXXX' };
    }
    return { error: 'Erreur lors de la recherche. Réessayez.' };
  }

  console.log('[FTM-DEBUG] Parcel - Parcel found', {
    trackingNumber: normalized,
    status: data.mission_status,
    pickupCity: data.pickup_city,
    dropoffCity: data.dropoff_city,
    driverName: data.driver_name,
  });

  return { success: true, parcel: data };
}

/**
 * RÉCUPÉRER TOUS LES COLIS D'UN CLIENT (historique expéditions)
 */
export async function getClientParcels(
  clientProfileId: string
): Promise<{ success?: boolean; parcels?: any[]; error?: any }> {
  console.log('[FTM-DEBUG] Parcel - Fetching client parcels', { clientProfileId });

  const { data, error } = await supabase
    .from('ecommerce_parcels')
    .select(`
      id,
      tracking_number,
      recipient_name,
      recipient_phone,
      content_description,
      is_fragile,
      weight_kg,
      volume_m3,
      length_cm,
      width_cm,
      height_cm,
      created_at,
      missions (
        id,
        mission_number,
        status,
        pickup_city,
        dropoff_city,
        estimated_distance_km,
        commission_amount,
        negotiated_price,
        actual_pickup_time,
        actual_dropoff_time,
        completed_at
      )
    `)
    .eq('missions.client_id', clientProfileId)
    .order('created_at', { ascending: false });

  if (error) {
    console.log('[FTM-DEBUG] Parcel - Fetch client parcels error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Parcel - Client parcels fetched', {
    clientProfileId,
    count: data?.length || 0,
  });

  return { success: true, parcels: data || [] };
}
ENDOFFILE

mkdir -p frontend/src/screens/ecommerce
cat > frontend/src/screens/ecommerce/CreateParcelScreen.tsx << 'ENDOFFILE'
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
ENDOFFILE

cat > frontend/src/screens/ecommerce/ParcelConfirmationScreen.tsx << 'ENDOFFILE'
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Share,
} from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { maskPhone, formatVolume } from '../../utils/parcelCalculations';

type RouteParams = {
  ParcelConfirmation: {
    trackingNumber: string;
    mission: any;
    parcel: any;
  };
};

export default function ParcelConfirmationScreen(): JSX.Element {
  const navigation = useNavigation<any>();
  const route = useRoute<RouteProp<RouteParams, 'ParcelConfirmation'>>();
  const { trackingNumber, mission, parcel } = route.params;

  async function handleCopy() {
    await Clipboard.setStringAsync(trackingNumber);
  }

  async function handleShare() {
    await Share.share({
      message: `Suivez votre colis ${trackingNumber} sur : https://ftm.ma/track/${trackingNumber}`,
    });
  }

  return (
    <View style={styles.container}>
      <Text style={styles.header}>✅ Colis enregistré !</Text>

      <View style={styles.trackingCard}>
        <Text style={styles.trackingLabel}>📦 NUMÉRO DE SUIVI</Text>
        <Text style={styles.trackingNumber}>{trackingNumber}</Text>
        <View style={styles.actionRow}>
          <TouchableOpacity style={styles.actionBtn} onPress={handleCopy}>
            <Text style={styles.actionBtnText}>📋 Copier</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.actionBtn} onPress={handleShare}>
            <Text style={styles.actionBtnText}>📤 Partager</Text>
          </TouchableOpacity>
        </View>
      </View>

      {parcel && (
        <View style={styles.smsInfo}>
          <Text style={styles.smsText}>
            📱 SMS envoyé à : {parcel.recipient_name}
          </Text>
          <Text style={styles.smsPhone}>{maskPhone(parcel.recipient_phone)}</Text>
        </View>
      )}

      {mission && (
        <View style={styles.summary}>
          <Text style={styles.summaryTitle}>RÉCAPITULATIF</Text>
          <Text style={styles.summaryRow}>📍 Départ     : {mission.pickup_city}</Text>
          <Text style={styles.summaryRow}>🏁 Arrivée    : {mission.dropoff_city}</Text>
          {mission.estimated_distance_km && (
            <Text style={styles.summaryRow}>📏 Distance   : ~{mission.estimated_distance_km} km</Text>
          )}
          {parcel?.volume_m3 && (
            <Text style={styles.summaryRow}>📦 Volume     : {formatVolume(parcel.volume_m3)}</Text>
          )}
          {parcel?.weight_kg && (
            <Text style={styles.summaryRow}>⚖️  Poids     : {parcel.weight_kg} kg</Text>
          )}
          {mission.commission_amount && (
            <Text style={styles.summaryRow}>💰 Commission : {mission.commission_amount} DH</Text>
          )}
        </View>
      )}

      <Text style={styles.statusText}>⏳ En recherche de chauffeur...</Text>

      <TouchableOpacity
        style={styles.primaryBtn}
        onPress={() => navigation.navigate('TrackingDetail', { trackingNumber })}
      >
        <Text style={styles.primaryBtnText}>Suivre ce colis</Text>
      </TouchableOpacity>

      <TouchableOpacity onPress={() => navigation.navigate('Home')}>
        <Text style={styles.homeLink}>Retour à l'accueil</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F9FAFB', padding: 20, alignItems: 'center' },
  header: { fontSize: 24, fontWeight: '800', color: '#16A34A', marginVertical: 20 },
  trackingCard: { backgroundColor: '#fff', borderRadius: 16, padding: 20, width: '100%', alignItems: 'center', shadowColor: '#000', shadowOpacity: 0.08, shadowRadius: 8, elevation: 3, marginBottom: 16 },
  trackingLabel: { fontSize: 12, fontWeight: '600', color: '#6B7280', textTransform: 'uppercase', marginBottom: 8 },
  trackingNumber: { fontSize: 22, fontWeight: '800', color: '#2563EB', letterSpacing: 1, marginBottom: 16 },
  actionRow: { flexDirection: 'row', gap: 12 },
  actionBtn: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 8, backgroundColor: '#EFF6FF', borderRadius: 8 },
  actionBtnText: { color: '#2563EB', fontWeight: '600', fontSize: 14 },
  smsInfo: { backgroundColor: '#F0FDF4', borderRadius: 10, padding: 12, width: '100%', marginBottom: 12 },
  smsText: { color: '#166534', fontSize: 14 },
  smsPhone: { color: '#166534', fontWeight: '700', fontSize: 14 },
  summary: { backgroundColor: '#fff', borderRadius: 12, padding: 16, width: '100%', marginBottom: 16 },
  summaryTitle: { fontSize: 12, fontWeight: '600', color: '#6B7280', textTransform: 'uppercase', marginBottom: 8 },
  summaryRow: { fontSize: 14, color: '#374151', marginBottom: 4 },
  statusText: { color: '#6B7280', fontSize: 14, marginBottom: 20 },
  primaryBtn: { backgroundColor: '#2563EB', borderRadius: 12, height: 52, width: '100%', alignItems: 'center', justifyContent: 'center', marginBottom: 12 },
  primaryBtnText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  homeLink: { color: '#2563EB', fontSize: 14, textDecorationLine: 'underline' },
});
ENDOFFILE

cat > frontend/src/screens/ecommerce/ParcelHistoryScreen.tsx << 'ENDOFFILE'
import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { supabase } from '../../lib/supabaseClient';
import { getClientParcels } from '../../services/parcelService';
import { formatVolume } from '../../utils/parcelCalculations';

type FilterType = 'all' | 'active' | 'completed';

const STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  pending: { label: '⏳ En attente', color: '#F59E0B' },
  accepted: { label: '🔵 Accepté', color: '#2563EB' },
  in_progress: { label: '🔄 En transit', color: '#2563EB' },
  completed: { label: '✅ Livré', color: '#16A34A' },
  cancelled_client: { label: '⛔ Annulé', color: '#9CA3AF' },
  cancelled_driver: { label: '⛔ Annulé', color: '#9CA3AF' },
};

export default function ParcelHistoryScreen(): JSX.Element {
  const navigation = useNavigation<any>();
  const [parcels, setParcels] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<FilterType>('all');

  useEffect(() => {
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const result = await getClientParcels(user.id);
      if (result.success) {
        setParcels(result.parcels || []);
      }
      setLoading(false);
    })();
  }, []);

  function filterParcels(list: any[]): any[] {
    if (filter === 'active') {
      return list.filter(p => ['pending', 'accepted', 'in_progress'].includes(p.missions?.status));
    }
    if (filter === 'completed') {
      return list.filter(p => p.missions?.status === 'completed');
    }
    return list;
  }

  function renderItem({ item }: { item: any }) {
    const mission = item.missions;
    const status = mission?.status || 'pending';
    const statusConf = STATUS_CONFIG[status] || STATUS_CONFIG.pending;

    return (
      <TouchableOpacity
        style={styles.card}
        onPress={() => navigation.navigate('TrackingDetail', { trackingNumber: item.tracking_number })}
      >
        <Text style={styles.trackingNum}>{item.tracking_number}</Text>
        <Text style={styles.route}>
          📍 {mission?.pickup_city || '—'} → 🏁 {mission?.dropoff_city || '—'}
        </Text>
        <Text style={styles.recipient}>Pour : {item.recipient_name}</Text>
        <Text style={styles.details}>
          ⚖️ {item.weight_kg} kg  {item.volume_m3 ? `📦 ${formatVolume(item.volume_m3)}` : ''}
        </Text>
        <View style={styles.statusRow}>
          <Text style={[styles.statusBadge, { color: statusConf.color }]}>{statusConf.label}</Text>
          {item.created_at && (
            <Text style={styles.dateText}>
              {new Date(item.created_at).toLocaleDateString('fr-MA')}
            </Text>
          )}
        </View>
      </TouchableOpacity>
    );
  }

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#2563EB" />
      </View>
    );
  }

  const filtered = filterParcels(parcels);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Mes expéditions</Text>

      <View style={styles.filterRow}>
        {(['all', 'active', 'completed'] as FilterType[]).map(f => (
          <TouchableOpacity
            key={f}
            style={[styles.filterBtn, filter === f && styles.filterBtnActive]}
            onPress={() => setFilter(f)}
          >
            <Text style={[styles.filterBtnText, filter === f && styles.filterBtnTextActive]}>
              {f === 'all' ? 'Tous' : f === 'active' ? 'En cours' : 'Livrés'}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <FlatList
        data={filtered}
        keyExtractor={item => item.id}
        renderItem={renderItem}
        contentContainerStyle={styles.list}
        ListEmptyComponent={<Text style={styles.emptyText}>Aucune expédition trouvée.</Text>}
      />

      <TouchableOpacity
        style={styles.fab}
        onPress={() => navigation.navigate('CreateParcel')}
      >
        <Text style={styles.fabText}>+ Envoyer un colis</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F9FAFB' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  title: { fontSize: 22, fontWeight: '700', color: '#111827', padding: 16, paddingBottom: 8 },
  filterRow: { flexDirection: 'row', paddingHorizontal: 16, gap: 8, marginBottom: 8 },
  filterBtn: { paddingHorizontal: 14, paddingVertical: 6, borderRadius: 20, borderWidth: 1, borderColor: '#E5E7EB', backgroundColor: '#fff' },
  filterBtnActive: { backgroundColor: '#2563EB', borderColor: '#2563EB' },
  filterBtnText: { color: '#6B7280', fontSize: 13, fontWeight: '500' },
  filterBtnTextActive: { color: '#fff', fontWeight: '700' },
  list: { padding: 16, paddingBottom: 80 },
  card: { backgroundColor: '#fff', borderRadius: 12, padding: 14, marginBottom: 10, shadowColor: '#000', shadowOpacity: 0.05, shadowRadius: 4, elevation: 2 },
  trackingNum: { fontSize: 15, fontWeight: '700', color: '#2563EB', marginBottom: 4 },
  route: { fontSize: 14, color: '#374151', marginBottom: 2 },
  recipient: { fontSize: 13, color: '#6B7280', marginBottom: 2 },
  details: { fontSize: 13, color: '#6B7280', marginBottom: 6 },
  statusRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  statusBadge: { fontSize: 13, fontWeight: '600' },
  dateText: { fontSize: 12, color: '#9CA3AF' },
  emptyText: { textAlign: 'center', color: '#9CA3AF', marginTop: 40, fontSize: 14 },
  fab: { position: 'absolute', bottom: 20, right: 20, left: 20, backgroundColor: '#2563EB', borderRadius: 12, height: 52, alignItems: 'center', justifyContent: 'center' },
  fabText: { color: '#fff', fontSize: 16, fontWeight: '700' },
});
ENDOFFILE

mkdir -p frontend/src/screens/tracking
cat > frontend/src/screens/tracking/TrackingInputScreen.tsx << 'ENDOFFILE'
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
ENDOFFILE

cat > frontend/src/screens/tracking/TrackingDetailScreen.tsx << 'ENDOFFILE'
import React, { useEffect, useState, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { supabase } from '../../lib/supabaseClient';
import { getParcelByTrackingNumber } from '../../services/parcelService';
import { maskPhone, formatVolume } from '../../utils/parcelCalculations';

type RouteParams = {
  TrackingDetail: { trackingNumber: string };
};

interface TrackingStep {
  id: number;
  label: string;
  done: boolean;
  active: boolean;
}

const TRACKING_STEPS: Record<string, TrackingStep[]> = {
  pending: [
    { id: 1, label: 'Colis enregistré', done: true, active: false },
    { id: 2, label: 'En attente de chauffeur', done: false, active: true },
    { id: 3, label: 'En transit', done: false, active: false },
    { id: 4, label: 'Livré', done: false, active: false },
  ],
  accepted: [
    { id: 1, label: 'Colis enregistré', done: true, active: false },
    { id: 2, label: 'Chauffeur assigné', done: true, active: false },
    { id: 3, label: 'En attente de ramassage', done: false, active: true },
    { id: 4, label: 'Livré', done: false, active: false },
  ],
  in_progress: [
    { id: 1, label: 'Colis enregistré', done: true, active: false },
    { id: 2, label: 'Chauffeur assigné', done: true, active: false },
    { id: 3, label: 'En transit', done: true, active: true },
    { id: 4, label: 'Livré', done: false, active: false },
  ],
  completed: [
    { id: 1, label: 'Colis enregistré', done: true, active: false },
    { id: 2, label: 'Chauffeur assigné', done: true, active: false },
    { id: 3, label: 'En transit', done: true, active: false },
    { id: 4, label: '✅ Livré !', done: true, active: false },
  ],
};

async function subscribeToParcelStatus(
  missionId: string,
  onStatusChange: (payload: any) => void
): Promise<ReturnType<typeof supabase.channel>> {
  console.log('[FTM-DEBUG] Tracking - Subscribing to parcel status updates', { missionId });

  const channel = supabase
    .channel(`parcel-tracking-${missionId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'missions',
        filter: `id=eq.${missionId}`,
      },
      (payload) => {
        console.log('[FTM-DEBUG] Tracking - Parcel status changed', {
          missionId,
          oldStatus: (payload.old as any).status,
          newStatus: (payload.new as any).status,
        });
        onStatusChange(payload.new);
      }
    )
    .subscribe();

  return channel;
}

export default function TrackingDetailScreen(): JSX.Element {
  const navigation = useNavigation<any>();
  const route = useRoute<RouteProp<RouteParams, 'TrackingDetail'>>();
  const { trackingNumber } = route.params;

  const [parcelData, setParcelData] = useState<any | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const channelRef = useRef<any>(null);

  useEffect(() => {
    (async () => {
      const result = await getParcelByTrackingNumber(trackingNumber);
      setIsLoading(false);
      if (result.success) {
        setParcelData(result.parcel);
        if (result.parcel?.mission_number) {
          // Subscribe to status changes using mission_number as a proxy key
          // The actual mission id would come from a separate query in production
        }
      }
    })();

    return () => {
      if (channelRef.current) {
        supabase.removeChannel(channelRef.current);
      }
    };
  }, [trackingNumber]);

  if (isLoading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#2563EB" />
      </View>
    );
  }

  if (!parcelData) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorMsg}>Colis introuvable.</Text>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Text style={styles.backLink}>← Retour</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const status = parcelData.mission_status || 'pending';
  const steps = TRACKING_STEPS[status] || TRACKING_STEPS.pending;

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
        <Text style={styles.backBtnText}>← Retour</Text>
      </TouchableOpacity>

      <Text style={styles.trackingNum}>{parcelData.tracking_number}</Text>

      {/* TIMELINE */}
      <View style={styles.timelineCard}>
        {steps.map((step, idx) => (
          <View key={step.id} style={styles.stepRow}>
            <View style={styles.stepIndicatorCol}>
              <View style={[
                styles.stepDot,
                step.done ? styles.stepDotDone : step.active ? styles.stepDotActive : styles.stepDotFuture,
              ]} />
              {idx < steps.length - 1 && <View style={styles.stepLine} />}
            </View>
            <Text style={[
              styles.stepLabel,
              step.done ? styles.stepLabelDone : step.active ? styles.stepLabelActive : styles.stepLabelFuture,
            ]}>
              {step.label}
            </Text>
          </View>
        ))}
      </View>

      {/* INFOS COLIS */}
      <View style={styles.infoCard}>
        <Text style={styles.infoTitle}>INFOS COLIS</Text>
        <Text style={styles.infoRow}>📍 De       : {parcelData.pickup_city}</Text>
        <Text style={styles.infoRow}>🏁 Vers     : {parcelData.dropoff_city}</Text>
        <Text style={styles.infoRow}>📦 Contenu  : {parcelData.content_description}</Text>
        <Text style={styles.infoRow}>⚖️  Poids   : {parcelData.weight_kg} kg</Text>
        {parcelData.volume_m3 && (
          <Text style={styles.infoRow}>📐 Volume   : {formatVolume(parcelData.volume_m3)}</Text>
        )}
        <Text style={styles.infoRow}>⚠️  Fragile : {parcelData.is_fragile ? 'Oui' : 'Non'}</Text>
      </View>

      {/* EXPÉDITEUR */}
      <View style={styles.infoCard}>
        <Text style={styles.infoTitle}>EXPÉDITEUR</Text>
        <Text style={styles.infoRow}>👤 {parcelData.sender_name}</Text>
        <Text style={styles.infoRow}>📱 {parcelData.sender_phone_masked}</Text>
      </View>

      {/* DRIVER */}
      {parcelData.driver_name && (
        <View style={styles.infoCard}>
          <Text style={styles.infoTitle}>CHAUFFEUR</Text>
          <Text style={styles.infoRow}>👤 {parcelData.driver_name}</Text>
          {parcelData.vehicle_brand && (
            <Text style={styles.infoRow}>🚛 {parcelData.vehicle_brand} {parcelData.vehicle_model}</Text>
          )}
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F9FAFB' },
  content: { padding: 16, paddingBottom: 40 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  errorMsg: { fontSize: 16, color: '#EF4444', marginBottom: 12 },
  backLink: { color: '#2563EB', fontSize: 14 },
  backBtn: { marginBottom: 12 },
  backBtnText: { color: '#2563EB', fontSize: 14, fontWeight: '600' },
  trackingNum: { fontSize: 20, fontWeight: '800', color: '#2563EB', textAlign: 'center', marginBottom: 20, letterSpacing: 1 },
  timelineCard: { backgroundColor: '#fff', borderRadius: 12, padding: 16, marginBottom: 12, shadowColor: '#000', shadowOpacity: 0.05, shadowRadius: 4, elevation: 2 },
  stepRow: { flexDirection: 'row', alignItems: 'flex-start', marginBottom: 4 },
  stepIndicatorCol: { alignItems: 'center', marginRight: 12, width: 20 },
  stepDot: { width: 16, height: 16, borderRadius: 8, marginBottom: 0 },
  stepDotDone: { backgroundColor: '#16A34A' },
  stepDotActive: { backgroundColor: '#2563EB', borderWidth: 3, borderColor: '#BFDBFE' },
  stepDotFuture: { backgroundColor: '#E5E7EB' },
  stepLine: { width: 2, height: 24, backgroundColor: '#E5E7EB', marginTop: 2 },
  stepLabel: { fontSize: 14, paddingTop: 1 },
  stepLabelDone: { color: '#374151', fontWeight: '600' },
  stepLabelActive: { color: '#2563EB', fontWeight: '700' },
  stepLabelFuture: { color: '#9CA3AF' },
  infoCard: { backgroundColor: '#fff', borderRadius: 12, padding: 14, marginBottom: 10 },
  infoTitle: { fontSize: 11, fontWeight: '600', color: '#6B7280', textTransform: 'uppercase', marginBottom: 8 },
  infoRow: { fontSize: 14, color: '#374151', marginBottom: 4 },
});
ENDOFFILE

mkdir -p frontend/src/screens/driver
cat > frontend/src/screens/driver/ParcelMissionDetailScreen.tsx << 'ENDOFFILE'
import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Linking,
  ActivityIndicator,
} from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { useRoute, RouteProp } from '@react-navigation/native';
import { supabase } from '../../lib/supabaseClient';
import { formatVolume } from '../../utils/parcelCalculations';

type RouteParams = {
  ParcelMissionDetail: { missionId: string };
};

async function loadParcelDetails(
  missionId: string
): Promise<{ success?: boolean; parcel?: any; error?: any }> {
  console.log('[FTM-DEBUG] Parcel - Loading parcel details for driver', { missionId });

  const { data, error } = await supabase
    .from('ecommerce_parcels')
    .select(`
      tracking_number,
      sender_name,
      sender_phone,
      recipient_name,
      recipient_phone,
      length_cm,
      width_cm,
      height_cm,
      weight_kg,
      volume_m3,
      content_description,
      is_fragile
    `)
    .eq('mission_id', missionId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Parcel - Load details error', {
      missionId,
      error: error.message,
    });
    return { error };
  }

  console.log('[FTM-DEBUG] Parcel - Parcel details loaded for driver', {
    missionId,
    trackingNumber: data.tracking_number,
    isFragile: data.is_fragile,
    weightKg: data.weight_kg,
    volumeM3: data.volume_m3,
  });

  return { success: true, parcel: data };
}

export default function ParcelMissionDetailScreen(): JSX.Element {
  const route = useRoute<RouteProp<RouteParams, 'ParcelMissionDetail'>>();
  const { missionId } = route.params;

  const [parcel, setParcel] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      const result = await loadParcelDetails(missionId);
      if (result.success) setParcel(result.parcel);
      setLoading(false);
    })();
  }, [missionId]);

  async function handleCopyTracking() {
    if (parcel?.tracking_number) {
      await Clipboard.setStringAsync(parcel.tracking_number);
    }
  }

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#2563EB" />
      </View>
    );
  }

  if (!parcel) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>Détails du colis introuvables.</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.sectionTitle}>DÉTAILS DU COLIS</Text>

      <TouchableOpacity style={styles.trackingRow} onPress={handleCopyTracking}>
        <Text style={styles.trackingNum}>{parcel.tracking_number}</Text>
        <Text style={styles.copyHint}>📋 Copier</Text>
      </TouchableOpacity>

      {parcel.is_fragile && (
        <View style={styles.fragileAlert}>
          <Text style={styles.fragileAlertText}>⚠️  COLIS FRAGILE</Text>
          <Text style={styles.fragileAlertSub}>Manipulez avec précaution</Text>
        </View>
      )}

      <View style={styles.infoCard}>
        <Text style={styles.infoTitle}>📦 Dimensions</Text>
        <Text style={styles.infoRow}>
          {parcel.length_cm} × {parcel.width_cm} × {parcel.height_cm} cm
        </Text>
        {parcel.volume_m3 && (
          <Text style={styles.infoRow}>Volume : {formatVolume(parcel.volume_m3)}</Text>
        )}
        <Text style={styles.infoRow}>Poids : {parcel.weight_kg} kg</Text>
      </View>

      <View style={styles.infoCard}>
        <Text style={styles.infoTitle}>📋 Contenu</Text>
        <Text style={styles.infoRow}>{parcel.content_description}</Text>
      </View>

      <View style={styles.infoCard}>
        <Text style={styles.infoTitle}>EXPÉDITEUR</Text>
        <Text style={styles.infoRow}>👤 {parcel.sender_name}</Text>
        <TouchableOpacity
          style={styles.callBtn}
          onPress={() => Linking.openURL(`tel:${parcel.sender_phone}`)}
        >
          <Text style={styles.callBtnText}>📞 Appeler l'expéditeur</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.infoCard}>
        <Text style={styles.infoTitle}>DESTINATAIRE</Text>
        <Text style={styles.infoRow}>👤 {parcel.recipient_name}</Text>
        <TouchableOpacity
          style={styles.callBtn}
          onPress={() => Linking.openURL(`tel:${parcel.recipient_phone}`)}
        >
          <Text style={styles.callBtnText}>📞 Appeler le destinataire</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F9FAFB' },
  content: { padding: 16, paddingBottom: 40 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  errorText: { color: '#EF4444', fontSize: 15 },
  sectionTitle: { fontSize: 12, fontWeight: '700', color: '#6B7280', textTransform: 'uppercase', marginBottom: 12 },
  trackingRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: '#EFF6FF', borderRadius: 10, padding: 14, marginBottom: 12 },
  trackingNum: { fontSize: 16, fontWeight: '800', color: '#2563EB', letterSpacing: 1 },
  copyHint: { color: '#2563EB', fontSize: 13 },
  fragileAlert: { backgroundColor: '#FEF3C7', borderWidth: 1.5, borderColor: '#F59E0B', borderRadius: 10, padding: 12, marginBottom: 12 },
  fragileAlertText: { color: '#92400E', fontWeight: '800', fontSize: 15 },
  fragileAlertSub: { color: '#92400E', fontSize: 13 },
  infoCard: { backgroundColor: '#fff', borderRadius: 12, padding: 14, marginBottom: 10, shadowColor: '#000', shadowOpacity: 0.04, shadowRadius: 3, elevation: 1 },
  infoTitle: { fontSize: 12, fontWeight: '600', color: '#6B7280', textTransform: 'uppercase', marginBottom: 8 },
  infoRow: { fontSize: 14, color: '#374151', marginBottom: 4 },
  callBtn: { marginTop: 8, backgroundColor: '#2563EB', borderRadius: 8, paddingVertical: 10, alignItems: 'center' },
  callBtnText: { color: '#fff', fontWeight: '700', fontSize: 14 },
});
ENDOFFILE

mkdir -p supabase/migrations
cat > supabase/migrations/20260222000000_add_tracking_functions.sql << 'ENDOFFILE'
-- =====================================================================
-- FTM P4 — Migration : Tracking Functions, Table et Vue
-- =====================================================================

-- TABLE: ecommerce_parcels
CREATE TABLE IF NOT EXISTS ecommerce_parcels (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_id UUID REFERENCES missions(id) ON DELETE CASCADE UNIQUE NOT NULL,

    -- Expéditeur
    sender_name  VARCHAR(255) NOT NULL,
    sender_phone VARCHAR(20)  NOT NULL,

    -- Destinataire
    recipient_name  VARCHAR(255) NOT NULL,
    recipient_phone VARCHAR(20)  NOT NULL,

    -- Dimensions (cm)
    length_cm DECIMAL(10,2) NOT NULL CHECK (length_cm > 0),
    width_cm  DECIMAL(10,2) NOT NULL CHECK (width_cm > 0),
    height_cm DECIMAL(10,2) NOT NULL CHECK (height_cm > 0),
    weight_kg DECIMAL(10,2) NOT NULL CHECK (weight_kg > 0),

    -- Volume calculé automatiquement par PostgreSQL (GENERATED ALWAYS)
    volume_m3 DECIMAL(10,4) GENERATED ALWAYS AS (
        (length_cm * width_cm * height_cm) / 1000000
    ) STORED,

    -- Contenu et options
    content_description TEXT    NOT NULL,
    is_fragile          BOOLEAN DEFAULT false,

    -- Numéro de suivi unique
    tracking_number VARCHAR(50) UNIQUE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour accès rapide
CREATE INDEX IF NOT EXISTS idx_parcels_mission  ON ecommerce_parcels(mission_id);
CREATE INDEX IF NOT EXISTS idx_parcels_tracking ON ecommerce_parcels(tracking_number);

-- =====================================================================
-- FONCTION : generate_tracking_number()
-- =====================================================================
CREATE OR REPLACE FUNCTION generate_tracking_number()
RETURNS TEXT AS $$
DECLARE
    new_number  TEXT;
    done        BOOLEAN := false;
    chars       TEXT    := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    random_part TEXT    := '';
    i           INTEGER;
BEGIN
    WHILE NOT done LOOP
        random_part := '';
        FOR i IN 1..8 LOOP
            random_part := random_part ||
                SUBSTR(chars, FLOOR(RANDOM() * LENGTH(chars))::INTEGER + 1, 1);
        END LOOP;

        new_number := 'FTM-TRACK-' || random_part;

        IF NOT EXISTS (
            SELECT 1 FROM ecommerce_parcels
            WHERE tracking_number = new_number
        ) THEN
            done := true;
        END IF;
    END LOOP;
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- TRIGGER : set_tracking_number
-- =====================================================================
CREATE OR REPLACE FUNCTION set_tracking_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tracking_number IS NULL THEN
        NEW.tracking_number := generate_tracking_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_tracking_number ON ecommerce_parcels;
CREATE TRIGGER trigger_set_tracking_number
    BEFORE INSERT ON ecommerce_parcels
    FOR EACH ROW EXECUTE FUNCTION set_tracking_number();

-- =====================================================================
-- VUE PUBLIQUE : public_parcel_tracking
-- =====================================================================
CREATE OR REPLACE VIEW public_parcel_tracking AS
SELECT
    ep.tracking_number,
    ep.sender_name,
    CONCAT(
        LEFT(ep.sender_phone, 3),
        '****',
        RIGHT(ep.sender_phone, 2)
    ) AS sender_phone_masked,
    ep.recipient_name,
    ep.content_description,
    ep.is_fragile,
    ep.weight_kg,
    ep.volume_m3,
    m.status              AS mission_status,
    m.pickup_city,
    m.dropoff_city,
    m.pickup_address,
    m.dropoff_address,
    m.estimated_distance_km,
    m.actual_pickup_time,
    m.actual_dropoff_time,
    m.completed_at,
    m.mission_number,
    p.full_name           AS driver_name,
    d.vehicle_category,
    d.vehicle_brand,
    d.vehicle_model,
    d.current_location,
    d.last_location_update
FROM ecommerce_parcels ep
INNER JOIN missions m  ON m.id = ep.mission_id
LEFT  JOIN drivers  d  ON d.id = m.driver_id
LEFT  JOIN profiles p  ON p.id = d.profile_id;
ENDOFFILE

echo "✅ Fichiers P4 créés"