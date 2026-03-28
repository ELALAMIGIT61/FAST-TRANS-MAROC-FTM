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
