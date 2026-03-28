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
