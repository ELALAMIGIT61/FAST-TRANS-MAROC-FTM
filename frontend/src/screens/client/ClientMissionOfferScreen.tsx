import React from 'react';
import MissionOfferScreen from '../driver/MissionOfferScreen';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type ClientStackParamList = {
  MissionOffer: { missionId: string };
  MissionTracking: { mission: Record<string, unknown> };
};

type Props = NativeStackScreenProps<ClientStackParamList, 'MissionOffer'>;

export default function ClientMissionOfferScreen({ route, navigation }: Props) {
  const { missionId } = route.params;

  return (
    <MissionOfferScreen
      missionId={missionId}
      role="client"
      onMissionResolved={(mission) => {
        navigation.replace('MissionTracking', { mission });
      }}
    />
  );
}
