import React from 'react';
import { View } from 'react-native';
import { COLORS } from '../../constants/theme';
import BackButton from '../../components/BackButton';
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
    <View style={{ flex: 1, backgroundColor: COLORS.background }}>
      <BackButton />
      <MissionOfferScreen
        missionId={missionId}
        driverId={driverId}
        role="driver"
        onMissionResolved={(mission) => {
          navigation.replace('MissionActive', { mission });
        }}
      />
    </View>
  );
}
