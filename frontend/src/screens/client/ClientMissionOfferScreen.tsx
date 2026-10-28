import React from 'react';
import { View } from 'react-native';
import { COLORS } from '../../constants/theme';
import BackButton from '../../components/BackButton';
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
    <View style={{ flex: 1, backgroundColor: COLORS.background }}>
      <BackButton />
      <MissionOfferScreen
        missionId={missionId}
        role="client"
        onMissionResolved={(mission) => {
          // A1 (correction 30) : si le suivi de la mission est deja ouvert juste
          // en dessous, on y revient (il se met a jour tout seul) au lieu d'en
          // ouvrir un second par-dessus.
          const routes = navigation.getState().routes;
          const previous = routes[routes.length - 2];
          if (previous?.name === 'MissionTracking') navigation.goBack();
          else navigation.replace('MissionTracking', { mission });
        }}
      />
    </View>
  );
}
