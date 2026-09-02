import { supabase } from '../lib/supabaseClient';
import type { RealtimeChannel } from '@supabase/supabase-js';

export function subscribeToMissionUpdates(
  missionId: string,
  onUpdate: (mission: Record<string, unknown>) => void
): RealtimeChannel {
  console.log('[FTM-DEBUG] Realtime - Subscribing to mission updates', { missionId });

  const channel = supabase
    .channel(`mission-${missionId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'missions',
        filter: `id=eq.${missionId}`,
      },
      (payload) => {
        console.log('[FTM-DEBUG] Realtime - Mission update received', {
          missionId,
          oldStatus: (payload.old as Record<string, unknown>).status,
          newStatus: (payload.new as Record<string, unknown>).status,
          driverId: (payload.new as Record<string, unknown>).driver_id,
        });
        onUpdate(payload.new as Record<string, unknown>);
      }
    )
    .subscribe((status) => {
      console.log('[FTM-DEBUG] Realtime - Mission subscription status', { missionId, status });
    });

  return channel;
}

export function subscribeToNewMissions(
  vehicleCategory: string,
  _driverLocation: { lat: number; lng: number } | null,
  onNewMission: (mission: Record<string, unknown>) => void
): RealtimeChannel {
  console.log('[FTM-DEBUG] Realtime - Subscribing to new missions', { vehicleCategory });

  const channel = supabase
    .channel(`new-missions-${vehicleCategory}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'missions',
        filter: `vehicle_category=eq.${vehicleCategory}`,
      },
      (payload) => {
        const mission = payload.new as Record<string, unknown>;
        console.log('[FTM-DEBUG] Realtime - New mission received', {
          missionId: mission.id,
          missionNumber: mission.mission_number,
          pickupCity: mission.pickup_city,
          dropoffCity: mission.dropoff_city,
          commission: mission.commission_amount,
        });
        onNewMission(mission);
      }
    )
    .subscribe();

  return channel;
}

export function subscribeToDriverLocation(
  driverId: string,
  onLocationUpdate: (driver: Record<string, unknown>) => void
): RealtimeChannel {
  console.log('[FTM-DEBUG] Realtime - Subscribing to driver location', { driverId });

  const channel = supabase
    .channel(`driver-location-${driverId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'drivers',
        filter: `id=eq.${driverId}`,
      },
      (payload) => {
        console.log('[FTM-DEBUG] Realtime - Driver location update', {
          driverId,
          lastUpdate: (payload.new as Record<string, unknown>).last_location_update,
        });
        onLocationUpdate(payload.new as Record<string, unknown>);
      }
    )
    .subscribe();

  return channel;
}

export async function unsubscribeChannel(channel: RealtimeChannel | null): Promise<void> {
  if (channel) {
    await supabase.removeChannel(channel);
    console.log('[FTM-DEBUG] Realtime - Channel unsubscribed');
  }
}

export function subscribeToMissionOffers(
  missionId: string,
  onOfferChange: (offer: Record<string, unknown>) => void
): RealtimeChannel {
  console.log('[FTM-DEBUG] Realtime - Subscribing to mission offers (client side)', { missionId });

  const channel = supabase
    .channel(`mission-offers-${missionId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'mission_offers',
        filter: `mission_id=eq.${missionId}`,
      },
      (payload) => {
        const offer = payload.new as Record<string, unknown>;
        console.log('[FTM-DEBUG] Realtime - New offer received', {
          missionId,
          offerId: offer.id,
          driverId: offer.driver_id,
          offeredPrice: offer.offered_price,
        });
        onOfferChange(offer);
      }
    )
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'mission_offers',
        filter: `mission_id=eq.${missionId}`,
      },
      (payload) => {
        const offer = payload.new as Record<string, unknown>;
        console.log('[FTM-DEBUG] Realtime - Offer updated', {
          missionId,
          offerId: offer.id,
          status: offer.status,
          roundNumber: offer.round_number,
          offeredPrice: offer.offered_price,
        });
        onOfferChange(offer);
      }
    )
    .subscribe((status) => {
      console.log('[FTM-DEBUG] Realtime - Mission offers subscription status', { missionId, status });
    });

  return channel;
}

export function subscribeToDriverOffers(
  driverId: string,
  onOfferChange: (offer: Record<string, unknown>) => void
): RealtimeChannel {
  console.log('[FTM-DEBUG] Realtime - Subscribing to driver offers', { driverId });

  const channel = supabase
    .channel(`driver-offers-${driverId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'mission_offers',
        filter: `driver_id=eq.${driverId}`,
      },
      (payload) => {
        const offer = payload.new as Record<string, unknown>;
        console.log('[FTM-DEBUG] Realtime - Offer update received (driver side)', {
          driverId,
          offerId: offer.id,
          missionId: offer.mission_id,
          status: offer.status,
          roundNumber: offer.round_number,
          offeredPrice: offer.offered_price,
        });
        onOfferChange(offer);
      }
    )
    .subscribe((status) => {
      console.log('[FTM-DEBUG] Realtime - Driver offers subscription status', { driverId, status });
    });

  return channel;
}
