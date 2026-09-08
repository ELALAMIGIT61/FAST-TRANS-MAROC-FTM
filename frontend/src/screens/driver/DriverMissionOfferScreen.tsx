import React from 'react';
import MissionOfferScreen from './MissionOfferScreen';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type DriverStackParamList = {
  MissionOffer: { missionId: string; driverId: string };
  MissionActive: { mission: Record<string, unknown> };
};

type Props = NativeStackScreenProps<DriverStackParamList, 'MissionOffer'>;

export default function DriverMissionOfferScreen({ route, navigation }: Props) {
  const { missionId, driverId } = route.params;

  return (
    <MissionOfferScreen
      missionId={missionId}
      driverId={driverId}
      role="driver"
      onMissionResolved={(mission) => {
        navigation.replace('MissionActive', { mission });
      }}
    />
  );
}
