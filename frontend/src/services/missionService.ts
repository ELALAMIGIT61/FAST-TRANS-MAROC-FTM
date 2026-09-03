import { supabase } from '../lib/supabaseClient';
import { notifyMissionStarted, notifyMissionAccepted, notifyMissionCompleted, notifyMissionCancelled, notifyClientOfferUpdate, notifyDriverCounterOffer, notifyOfferAcceptancePending, notifyDriverOfferNotSelected } from './notificationTemplates';
import { insertNotification } from './pushNotificationService';

export type VehicleCategory = 'vul' | 'n2_medium' | 'n2_large';
export type MissionType = 'transport' | 'ecommerce_parcel';
export type MissionStatus =
  | 'pending'
  | 'accepted'
  | 'in_progress'
  | 'completed'
  | 'cancelled_client'
  | 'cancelled_driver'
  | 'expired';

export interface CreateMissionData {
  mission_type?: MissionType;
  vehicle_category: VehicleCategory;
  pickup_lat: number;
  pickup_lng: number;
  pickup_address: string;
  pickup_city: string;
  dropoff_lat: number;
  dropoff_lng: number;
  dropoff_address: string;
  dropoff_city: string;
  description?: string;
  needs_loading_help?: boolean;
  negotiated_price?: number;
  client_notes?: string;
  scheduled_pickup_time: string;
}

export interface Mission {
  id: string;
  mission_number: string;
  client_id: string | null;
  driver_id: string | null;
  mission_type: MissionType;
  vehicle_category: VehicleCategory;
  pickup_address: string;
  pickup_city: string;
  dropoff_address: string;
  dropoff_city: string;
  estimated_distance_km: number | null;
  description: string | null;
  needs_loading_help: boolean;
  negotiated_price: number | null;
  commission_amount: number | null;
  payment_method: string;
  status: MissionStatus;
  scheduled_pickup_time: string | null;
  actual_pickup_time: string | null;
  actual_dropoff_time: string | null;
  client_notes: string | null;
  driver_notes: string | null;
  client_rating: number | null;
  driver_rating: number | null;
  client_review: string | null;
  created_at: string;
  updated_at: string;
  completed_at: string | null;
}

export interface NearbyDriver {
  id: string;
  full_name: string;
  phone_number: string;
  vehicle_category: VehicleCategory;
  vehicle_brand: string;
  vehicle_model: string;
  license_plate: string;
  rating_average: number;
  total_missions: number;
  distance_km: number;
  last_location_update: string;
}

export async function createMission(
  clientProfileId: string,
  missionData: CreateMissionData
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  console.log('[FTM-DEBUG] Mission - Creating mission', {
    clientId: clientProfileId,
    vehicleCategory: missionData.vehicle_category,
    pickupCity: missionData.pickup_city,
    dropoffCity: missionData.dropoff_city,
    needsLoading: missionData.needs_loading_help,
    missionType: missionData.mission_type,
  });

  const { data, error } = await supabase
    .from('missions')
    .insert({
      client_id: clientProfileId,
      mission_type: missionData.mission_type ?? 'transport',
      vehicle_category: missionData.vehicle_category,
      pickup_location: `POINT(${missionData.pickup_lng} ${missionData.pickup_lat})`,
      pickup_address: missionData.pickup_address,
      pickup_city: missionData.pickup_city,
      dropoff_location: `POINT(${missionData.dropoff_lng} ${missionData.dropoff_lat})`,
      dropoff_address: missionData.dropoff_address,
      dropoff_city: missionData.dropoff_city,
      description: missionData.description ?? null,
      needs_loading_help: missionData.needs_loading_help ?? false,
      negotiated_price: missionData.negotiated_price ?? null,
      client_notes: missionData.client_notes ?? null,
      scheduled_pickup_time: missionData.scheduled_pickup_time,
      payment_method: 'cash',
      status: 'pending',
    })
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Creation error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Mission - Created successfully', {
    missionId: data.id,
    missionNumber: data.mission_number,
    commission: data.commission_amount,
    distanceKm: data.estimated_distance_km,
    status: data.status,
  });

  return { success: true, mission: data as Mission };
}

export async function findNearbyDrivers(
  clientLat: number,
  clientLng: number,
  vehicleCategory: VehicleCategory,
  radiusKm = 60
): Promise<{ success?: boolean; drivers?: NearbyDriver[]; error?: string }> {
  console.log('[FTM-DEBUG] GPS - Searching nearby drivers', {
    clientLat,
    clientLng,
    vehicleCategory,
    radiusKm,
  });

  const radiusMeters = radiusKm * 1000;
  const clientPoint = `POINT(${clientLng} ${clientLat})`;

  const { data, error } = await supabase.rpc('find_nearby_drivers', {
    client_point: clientPoint,
    radius_meters: radiusMeters,
    p_vehicle_category: vehicleCategory,
  });

  if (error) {
    console.log('[FTM-DEBUG] GPS - Find nearby drivers error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] GPS - Nearby drivers found', {
    count: data?.length ?? 0,
    vehicleCategory,
    radiusKm,
    drivers: (data as NearbyDriver[])?.map((d) => ({
      driverId: d.id,
      name: d.full_name,
      distanceKm: d.distance_km,
      rating: d.rating_average,
    })),
  });

  return { success: true, drivers: (data as NearbyDriver[]) ?? [] };
}

export async function acceptMission(
  missionId: string,
  driverId: string
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  console.log('[FTM-DEBUG] Mission - Driver accepting mission', { missionId, driverId });

  const { data, error } = await supabase
    .from('missions')
    .update({
      driver_id: driverId,
      status: 'accepted',
    })
    .eq('id', missionId)
    .eq('status', 'pending')
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Accept error', { error: error.message });
    return { error: error.message };
  }

  if (!data) {
    console.log('[FTM-DEBUG] Mission - Accept failed: mission already taken', { missionId });
    return { error: 'Cette mission a déjà été acceptée par un autre chauffeur.' };
  }

  console.log('[FTM-DEBUG] Mission - Accepted successfully', {
    missionId: data.id,
    missionNumber: data.mission_number,
    driverId: data.driver_id,
    status: data.status,
  });

  if (data.client_id) {
    try {
      const { data: driverProfile } = await supabase
        .from('drivers')
        .select('profiles ( full_name )')
        .eq('id', driverId)
        .single();
      const driverName = (driverProfile?.profiles as { full_name?: string } | null)?.full_name ?? 'Votre chauffeur';
      await notifyMissionAccepted(data.client_id, { id: data.id, mission_number: data.mission_number }, driverName);
    } catch (notifyError) {
      console.log('[FTM-DEBUG] Mission - Notify accepted failed (non-blocking)', { notifyError });
    }
  }

  return { success: true, mission: data as Mission };
}

export async function startMission(
  missionId: string,
  driverId: string
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  console.log('[FTM-DEBUG] Mission - Starting mission', { missionId, driverId });

  const { data, error } = await supabase
    .from('missions')
    .update({
      status: 'in_progress',
      actual_pickup_time: new Date().toISOString(),
    })
    .eq('id', missionId)
    .eq('driver_id', driverId)
    .eq('status', 'accepted')
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Start error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Mission - Started', {
    missionId,
    pickupTime: data.actual_pickup_time,
  });

  if (data.client_id) {
    try {
      await notifyMissionStarted(data.client_id, {
        id: data.id,
        mission_number: data.mission_number,
        dropoff_city: data.dropoff_city,
      });
    } catch (notifyError) {
      console.log('[FTM-DEBUG] Mission - Notify started failed (non-blocking)', { notifyError });
    }
  }

  return { success: true, mission: data as Mission };
}

export async function completeMission(
  missionId: string,
  driverId: string,
  driverNotes?: string
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  console.log('[FTM-DEBUG] Mission - Completing mission', { missionId, driverId });

  const { data, error } = await supabase
    .from('missions')
    .update({
      status: 'completed',
      actual_dropoff_time: new Date().toISOString(),
      completed_at: new Date().toISOString(),
      driver_notes: driverNotes ?? null,
    })
    .eq('id', missionId)
    .eq('driver_id', driverId)
    .eq('status', 'in_progress')
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Complete error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Mission - Completed successfully', {
    missionId: data.id,
    missionNumber: data.mission_number,
    commission: data.commission_amount,
    dropoffTime: data.actual_dropoff_time,
  });

  if (data.client_id) {
    try {
      const { data: driverProfile } = await supabase
        .from('drivers')
        .select('profiles ( id )')
        .eq('id', driverId)
        .single();
      const driverProfileId = (driverProfile?.profiles as { id?: string } | null)?.id;
      if (driverProfileId) {
        await notifyMissionCompleted(data.client_id, driverProfileId, {
          id: data.id,
          mission_number: data.mission_number,
          dropoff_city: data.dropoff_city,
          commission_amount: data.commission_amount ?? 0,
        });
      } else {
        await insertNotification(
          data.client_id,
          'mission_completed',
          '🏁 Mission terminée !',
          `Mission ${data.mission_number} livrée à ${data.dropoff_city}. Évaluez votre chauffeur.`,
          { mission_id: data.id, screen: 'RatingScreen' }
        );
        console.log('[FTM-DEBUG] Mission - Driver profileId not resolved, client notified alone', { driverId });
      }
    } catch (notifyError) {
      console.log('[FTM-DEBUG] Mission - Notify completed failed (non-blocking)', { notifyError });
    }
  }

  return { success: true, mission: data as Mission };
}

export async function cancelMission(
  missionId: string,
  userId: string,
  cancelledBy: 'client' | 'driver'
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  const newStatus: MissionStatus =
    cancelledBy === 'client' ? 'cancelled_client' : 'cancelled_driver';
  console.log('[FTM-DEBUG] Mission - Cancelling mission', {
    missionId,
    cancelledBy,
    newStatus,
  });
  const { data, error } = await supabase
    .from('missions')
    .update({ status: newStatus })
    .eq('id', missionId)
    .in('status', ['pending', 'accepted'])
    .select()
    .single();
  if (error) {
    console.log('[FTM-DEBUG] Mission - Cancel error', { error: error.message });
    return { error: error.message };
  }
  console.log('[FTM-DEBUG] Mission - Cancelled', {
    missionId,
    status: data.status,
  });

  try {
    if (cancelledBy === 'driver') {
      if (data.client_id) {
        await notifyMissionCancelled(
          data.client_id,
          { id: data.id, mission_number: data.mission_number },
          cancelledBy
        );
      }
    } else {
      if (!data.driver_id) {
        console.log('[FTM-DEBUG] Mission - Cancelled before driver assignment, no driver to notify', { missionId });
      } else {
        const { data: driverProfile } = await supabase
          .from('drivers')
          .select('profiles ( id )')
          .eq('id', data.driver_id)
          .single();
        const driverProfileId = (driverProfile?.profiles as { id?: string } | null)?.id;
        if (driverProfileId) {
          await notifyMissionCancelled(
            driverProfileId,
            { id: data.id, mission_number: data.mission_number },
            cancelledBy
          );
        } else {
          console.log('[FTM-DEBUG] Mission - Notify cancelled skipped: driver profileId not resolved', { driverId: data.driver_id });
        }
      }
    }
  } catch (notifyError) {
    console.log('[FTM-DEBUG] Mission - Notify cancelled failed (non-blocking)', { notifyError });
  }

  return { success: true, mission: data as Mission };
}
export async function submitClientRating(
  missionId: string,
  rating: number,
  review?: string
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  console.log('[FTM-DEBUG] Mission - Submitting client rating', {
    missionId,
    rating,
    hasReview: !!review,
  });

  const { data, error } = await supabase
    .from('missions')
    .update({
      client_rating: rating,
      client_review: review ?? null,
    })
    .eq('id', missionId)
    .eq('status', 'completed')
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Rating error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Mission - Rating submitted', {
    missionId,
    rating,
  });

  return { success: true, mission: data as Mission };
}

export async function expireMission(
  missionId: string
): Promise<{ success?: boolean; mission?: Mission; error?: string }> {
  console.log('[FTM-DEBUG] Mission - Expiring mission', { missionId });

  const { data, error } = await supabase
    .from('missions')
    .update({ status: 'expired' })
    .eq('id', missionId)
    .eq('status', 'pending')
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Expire error', { error: error.message });
    return { error: error.message };
  }

  if (!data) {
    console.log('[FTM-DEBUG] Mission - Expire skipped: mission no longer pending', { missionId });
    return { error: 'Cette mission a déjà changé de statut.' };
  }

  console.log('[FTM-DEBUG] Mission - Expired successfully', {
    missionId: data.id,
    missionNumber: data.mission_number,
  });

  return { success: true, mission: data as Mission };
}

export type OfferStatus = 'pending' | 'accepted' | 'not_selected';

export interface MissionOffer {
  id: string;
  mission_id: string;
  driver_id: string;
  round_number: 1 | 2;
  offered_price: number;
  client_accepted: boolean;
  driver_accepted: boolean;
  status: OfferStatus;
  message: string | null;
  created_at: string;
  updated_at: string;
}

export async function createMissionOffer(
  missionId: string,
  driverId: string,
  offeredPrice: number,
  message?: string
): Promise<{ success?: boolean; offer?: MissionOffer; error?: string }> {
  console.log('[FTM-DEBUG] MissionOffer - Creating offer', {
    missionId,
    driverId,
    offeredPrice,
  });

  const { data: mission, error: missionError } = await supabase
    .from('missions')
    .select('id, mission_number, client_id, status')
    .eq('id', missionId)
    .single();

  if (missionError || !mission) {
    console.log('[FTM-DEBUG] MissionOffer - Creation refused: mission not found', { missionId });
    return { error: 'Mission introuvable.' };
  }

  if (mission.status !== 'pending') {
    console.log('[FTM-DEBUG] MissionOffer - Creation refused: mission not pending', {
      missionId,
      status: mission.status,
    });
    return { error: 'Cette mission n\'est plus disponible.' };
  }

  const { data, error } = await supabase
    .from('mission_offers')
    .insert({
      mission_id: missionId,
      driver_id: driverId,
      round_number: 1,
      offered_price: offeredPrice,
      client_accepted: false,
      driver_accepted: false,
      status: 'pending',
      message: message ?? null,
    })
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] MissionOffer - Creation error', { error: error.message });
    if (error.code === '23505') {
      return { error: 'Vous avez déjà une offre active sur cette mission.' };
    }
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] MissionOffer - Created successfully', {
    offerId: data.id,
    missionId: data.mission_id,
    driverId: data.driver_id,
    offeredPrice: data.offered_price,
  });

  if (mission.client_id) {
    try {
      const { data: driverProfile } = await supabase
        .from('drivers')
        .select('profiles ( full_name )')
        .eq('id', driverId)
        .single();
      const driverName = (driverProfile?.profiles as { full_name?: string } | null)?.full_name ?? 'Un chauffeur';
      await notifyClientOfferUpdate(
        mission.client_id,
        { id: mission.id, mission_number: mission.mission_number },
        driverName,
        offeredPrice,
        1
      );
    } catch (notifyError) {
      console.log('[FTM-DEBUG] MissionOffer - Notify client (create) failed (non-blocking)', { notifyError });
    }
  }

  return { success: true, offer: data as MissionOffer };
}

export async function counterMissionOffer(
  offerId: string,
  newPrice: number,
  actor: 'client' | 'driver'
): Promise<{ success?: boolean; offer?: MissionOffer; error?: string }> {
  console.log('[FTM-DEBUG] MissionOffer - Countering offer', {
    offerId,
    newPrice,
    actor,
  });

  const nextRound = actor === 'client' ? 1 : 2;

  const { data, error } = await supabase
    .from('mission_offers')
    .update({
      offered_price: newPrice,
      round_number: nextRound,
    })
    .eq('id', offerId)
    .eq('status', 'pending')
    .eq('round_number', 1)
    .select('*, missions ( id, mission_number, client_id )')
    .single();

  if (error) {
    console.log('[FTM-DEBUG] MissionOffer - Counter error', { error: error.message });
    return { error: 'Impossible de proposer un nouveau prix pour le moment.' };
  }

  if (!data) {
    console.log('[FTM-DEBUG] MissionOffer - Counter failed: offer state changed concurrently', { offerId });
    return { error: 'Cette offre ne peut plus être modifiée à ce stade.' };
  }

  console.log('[FTM-DEBUG] MissionOffer - Countered successfully', {
    offerId: data.id,
    newPrice: data.offered_price,
    roundNumber: data.round_number,
  });

  const mission = data.missions as { id: string; mission_number: string; client_id: string | null } | null;

  try {
    if (actor === 'client' && data.driver_id) {
      await notifyDriverCounterOffer(
        data.driver_id,
        { id: mission?.id ?? data.mission_id, mission_number: mission?.mission_number ?? '' },
        newPrice
      );
    } else if (actor === 'driver' && mission?.client_id) {
      const { data: driverProfile } = await supabase
        .from('drivers')
        .select('profiles ( full_name )')
        .eq('id', data.driver_id)
        .single();
      const driverName = (driverProfile?.profiles as { full_name?: string } | null)?.full_name ?? 'Un chauffeur';
      await notifyClientOfferUpdate(
        mission.client_id,
        { id: mission.id, mission_number: mission.mission_number },
        driverName,
        newPrice,
        2
      );
    }
  } catch (notifyError) {
    console.log('[FTM-DEBUG] MissionOffer - Notify counter failed (non-blocking)', { notifyError });
  }

  return { success: true, offer: data as unknown as MissionOffer };
}

export async function acceptMissionOffer(
  offerId: string,
  acceptedBy: 'client' | 'driver'
): Promise<{ success?: boolean; offer?: MissionOffer; error?: string }> {
  console.log('[FTM-DEBUG] MissionOffer - Accepting offer', { offerId, acceptedBy });

  const updatePayload =
    acceptedBy === 'client' ? { client_accepted: true } : { driver_accepted: true };

  const { data, error } = await supabase
    .from('mission_offers')
    .update(updatePayload)
    .eq('id', offerId)
    .eq('status', 'pending')
    .select('*, missions ( id, mission_number, client_id )')
    .single();

  if (error) {
    console.log('[FTM-DEBUG] MissionOffer - Accept error', { error: error.message });
    return { error: error.message };
  }

  if (!data) {
    console.log('[FTM-DEBUG] MissionOffer - Accept failed: offer no longer pending', { offerId });
    return { error: 'Cette offre a déjà été traitée.' };
  }

  console.log('[FTM-DEBUG] MissionOffer - Accepted successfully', {
    offerId: data.id,
    status: data.status,
    clientAccepted: data.client_accepted,
    driverAccepted: data.driver_accepted,
  });

  const mission = data.missions as { id: string; mission_number: string; client_id: string | null } | null;

  try {
    if (data.status === 'accepted') {
      // Le trigger AFTER UPDATE sync_mission_on_offer_accepted s'exécute de façon
      // synchrone dans la même transaction SQL, avant que cette requête ne retourne
      // son résultat — les autres offres de la mission sont donc déjà basculées à
      // 'not_selected' au moment où on les relit ici. Comportement à confirmer lors
      // du test d'exécution réel de cette étape.
      const { data: losingOffers } = await supabase
        .from('mission_offers')
        .select('driver_id')
        .eq('mission_id', data.mission_id)
        .eq('status', 'not_selected');

      if (losingOffers) {
        for (const losingOffer of losingOffers) {
          try {
            await notifyDriverOfferNotSelected(losingOffer.driver_id, {
              id: mission?.id ?? data.mission_id,
              mission_number: mission?.mission_number ?? '',
            });
          } catch (notifyError) {
            console.log('[FTM-DEBUG] MissionOffer - Notify not-selected failed for one driver (non-blocking)', {
              driverId: losingOffer.driver_id,
              notifyError,
            });
          }
        }
      }
    } else if (acceptedBy === 'client') {
      // Le client vient d'accepter : on notifie le chauffeur, dont il faut
      // résoudre le profileId via la jointure drivers -> profiles.
      const { data: driverProfile } = await supabase
        .from('drivers')
        .select('profiles ( id )')
        .eq('id', data.driver_id)
        .single();
      const driverProfileId = (driverProfile?.profiles as { id?: string } | null)?.id;
      if (driverProfileId) {
        await notifyOfferAcceptancePending(
          driverProfileId,
          { id: mission?.id ?? data.mission_id, mission_number: mission?.mission_number ?? '' },
          data.offered_price
        );
      }
    } else if (acceptedBy === 'driver' && mission?.client_id) {
      // Le chauffeur vient d'accepter : on notifie directement le client,
      // dont le profileId est déjà disponible via la jointure missions.
      await notifyOfferAcceptancePending(
        mission.client_id,
        { id: mission.id, mission_number: mission.mission_number },
        data.offered_price
      );
    }
  } catch (notifyError) {
    console.log('[FTM-DEBUG] MissionOffer - Notify acceptance failed (non-blocking)', { notifyError });
  }

  return { success: true, offer: data as unknown as MissionOffer };
}

export async function submitClientCounterOffer(
  missionId: string,
  newPrice: number
): Promise<{ success?: boolean; updatedCount?: number; failedOfferIds?: string[]; error?: string }> {
  console.log('[FTM-DEBUG] MissionOffer - Submitting client counter offer', { missionId, newPrice });

  const { data: offers, error: fetchError } = await supabase
    .from('mission_offers')
    .select('id, driver_id')
    .eq('mission_id', missionId)
    .eq('status', 'pending')
    .eq('round_number', 1);

  if (fetchError) {
    console.log('[FTM-DEBUG] MissionOffer - Counter offer fetch error', { error: fetchError.message });
    return { error: fetchError.message };
  }

  if (!offers || offers.length === 0) {
    console.log('[FTM-DEBUG] MissionOffer - No round-1 pending offers to counter', { missionId });
    return { error: 'Aucune offre en attente pour cette mission.' };
  }

  const failedOfferIds: string[] = [];
  let updatedCount = 0;

  for (const offer of offers) {
    try {
      const result = await counterMissionOffer(offer.id, newPrice, 'client');
      if (result.success) {
        updatedCount += 1;
      } else {
        failedOfferIds.push(offer.id);
        console.log('[FTM-DEBUG] MissionOffer - Counter offer failed for one driver', {
          offerId: offer.id,
          error: result.error,
        });
      }
    } catch (err: unknown) {
      failedOfferIds.push(offer.id);
      const msg = err instanceof Error ? err.message : String(err);
      console.log('[FTM-DEBUG] MissionOffer - Counter offer exception for one driver', {
        offerId: offer.id,
        error: msg,
      });
    }
  }

  console.log('[FTM-DEBUG] MissionOffer - Client counter offer completed', {
    missionId,
    updatedCount,
    failedCount: failedOfferIds.length,
  });

  return { success: updatedCount > 0, updatedCount, failedOfferIds };
}

export async function rejectOfferAcceptance(
  offerId: string,
  rejectedBy: 'client' | 'driver'
): Promise<{ success?: boolean; offer?: MissionOffer; error?: string }> {
  console.log('[FTM-DEBUG] MissionOffer - Rejecting offer acceptance', { offerId, rejectedBy });

  const { data, error } = await supabase
    .from('mission_offers')
    .update({
      client_accepted: false,
      driver_accepted: false,
      status: 'not_selected',
    })
    .eq('id', offerId)
    .eq('status', 'pending')
    .select('*, missions ( id, mission_number, client_id )')
    .single();

  if (error) {
    console.log('[FTM-DEBUG] MissionOffer - Reject error', { error: error.message });
    return { error: error.message };
  }

  if (!data) {
    console.log('[FTM-DEBUG] MissionOffer - Reject failed: offer no longer pending', { offerId });
    return { error: 'Cette offre ne peut plus être annulée à ce stade.' };
  }

  console.log('[FTM-DEBUG] MissionOffer - Acceptance rejected successfully', {
    offerId: data.id,
    rejectedBy,
  });

  const mission = data.missions as { id: string; mission_number: string; client_id: string | null } | null;

  try {
    if (rejectedBy === 'driver' && mission?.client_id) {
      await notifyDriverOfferNotSelected(data.driver_id, {
        id: mission.id,
        mission_number: mission.mission_number,
      });
    } else if (rejectedBy === 'client') {
      const { data: driverProfile } = await supabase
        .from('drivers')
        .select('profiles ( id )')
        .eq('id', data.driver_id)
        .single();
      const driverProfileId = (driverProfile?.profiles as { id?: string } | null)?.id;
      if (driverProfileId) {
        await notifyDriverOfferNotSelected(driverProfileId, {
          id: mission?.id ?? data.mission_id,
          mission_number: mission?.mission_number ?? '',
        });
      }
    }
  } catch (notifyError) {
    console.log('[FTM-DEBUG] MissionOffer - Notify rejection failed (non-blocking)', { notifyError });
  }

  return { success: true, offer: data as unknown as MissionOffer };
}
