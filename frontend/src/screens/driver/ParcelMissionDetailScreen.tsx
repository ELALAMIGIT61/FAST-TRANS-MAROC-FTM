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
