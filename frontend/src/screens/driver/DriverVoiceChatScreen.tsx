import React, { useEffect, useRef, useState } from 'react';
import { View, ActivityIndicator, Text, StyleSheet } from 'react-native';
import VoiceChatScreen from '../mission/VoiceChatScreen';
import { getDriverProfileId } from '../../services/missionService';
import { subscribeToMissionUpdates, unsubscribeChannel } from '../../services/realtimeService';
import type { RealtimeChannel } from '@supabase/supabase-js';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type DriverStackParamList = {
  VoiceChat: { mission: Record<string, unknown> };
};

type Props = NativeStackScreenProps<DriverStackParamList, 'VoiceChat'>;

const CANCELLED_STATUSES = ['cancelled_client', 'cancelled_driver'];

export default function DriverVoiceChatScreen({ route, navigation }: Props) {
  const { mission } = route.params;
  const missionId = mission.id as string;
  const missionNumber = (mission.mission_number as string) ?? '';
  const driverId = mission.driver_id as string;

  const [profileId, setProfileId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const channelRef = useRef<RealtimeChannel | null>(null);

  useEffect(() => {
    let cancelled = false;
    getDriverProfileId(driverId).then((result) => {
      if (cancelled) return;
      if (result.success && result.profileId) {
        setProfileId(result.profileId);
      } else {
        setError(result.error ?? 'Impossible de récupérer le profil.');
      }
    });
    return () => {
      cancelled = true;
    };
  }, [driverId]);

  useEffect(() => {
    channelRef.current = subscribeToMissionUpdates(missionId, (updated) => {
      const newStatus = (updated as Record<string, unknown>).status as string;
      if (CANCELLED_STATUSES.includes(newStatus)) {
        navigation.goBack();
      }
    });
    return () => {
      unsubscribeChannel(channelRef.current);
    };
  }, [missionId, navigation]);

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>{error}</Text>
      </View>
    );
  }

  if (!profileId) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  return (
    <VoiceChatScreen
      missionId={missionId}
      currentProfileId={profileId}
      missionNumber={missionNumber}
    />
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  errorText: { fontSize: 14, color: '#DC3545', textAlign: 'center', padding: 20 },
});
