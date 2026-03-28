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
