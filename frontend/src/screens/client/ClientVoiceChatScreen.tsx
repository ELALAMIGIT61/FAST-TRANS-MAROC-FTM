import React, { useEffect, useRef } from 'react';
import VoiceChatScreen from '../mission/VoiceChatScreen';
import { subscribeToMissionUpdates, unsubscribeChannel } from '../../services/realtimeService';
import type { RealtimeChannel } from '@supabase/supabase-js';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type ClientStackParamList = {
  VoiceChat: { mission: Record<string, unknown> };
};

type Props = NativeStackScreenProps<ClientStackParamList, 'VoiceChat'>;

const CANCELLED_STATUSES = ['cancelled_client', 'cancelled_driver'];

export default function ClientVoiceChatScreen({ route, navigation }: Props) {
  const { mission } = route.params;
  const missionId = mission.id as string;
  const clientId = mission.client_id as string;
  const missionNumber = (mission.mission_number as string) ?? '';
  const channelRef = useRef<RealtimeChannel | null>(null);

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

  return (
    <VoiceChatScreen
      missionId={missionId}
      currentProfileId={clientId}
      missionNumber={missionNumber}
    />
  );
}
