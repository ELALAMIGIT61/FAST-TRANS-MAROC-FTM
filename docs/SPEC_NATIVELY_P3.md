# SPEC NATIVELY — Fast Trans Maroc (FTM)
# PARTIE P3 : Missions & Géolocalisation PostGIS
# Fichier : docs/SPEC_NATIVELY_P3.md
# Version : 1.0 | Backend : Supabase/PostGIS | App : Natively.dev
# =====================================================================
# PRÉREQUIS : P1 (Auth + profiles), P2 (drivers vérifié, wallet créé)
# TABLES SQL  : missions, drivers, profiles
# VUES SQL    : available_drivers, driver_dashboard
# FONCTIONS   : calculate_distance(), calculate_commission(), generate_mission_number()
# TRIGGERS    : trigger_set_mission_number, trigger_set_commission, trigger_set_distance
#               trigger_process_commission, trigger_update_rating
# EXTENSIONS  : postgis (GEOGRAPHY, ST_Distance, ST_DWithin)
# =====================================================================

---

## 1. CONTEXTE & FLUX GÉNÉRAL

```
CLIENT                          SERVEUR (Supabase)              DRIVER
  │                                     │                          │
  ├─ Saisit pickup + dropoff           │                          │
  ├─ Choisit vehicle_category          │                          │
  ├─ INSERT missions (status=pending) ──→ Trigger auto :          │
  │                                     │  • mission_number       │
  │                                     │  • commission_amount    │
  │                                     │  • estimated_distance   │
  │                                     │                          │
  │  Realtime : nouvelle mission ───────────────────────────────→ │
  │  (chauffeurs dans le rayon)         │    Notification Push     │
  │                                     │                          │
  │                                     │  ←── UPDATE status=accepted
  │  Realtime : mission acceptée ←──────│                          │
  │  (affiche infos driver)             │                          │
  │                                     │  ←── UPDATE status=in_progress
  │  Tracking GPS temps réel ←──────────│  (position driver live)  │
  │                                     │                          │
  │                                     │  ←── UPDATE status=completed
  │  Écran évaluation ←─────────────────│                          │
  │  client_rating + client_review      │                          │
  │                                     │  Trigger auto :          │
  │                                     │  • commission prélevée   │
  │                                     │  • transaction créée     │
  │                                     │  • driver stats MàJ      │
```

---

## 2. STRUCTURE SQL DE RÉFÉRENCE

### 2.1 Table missions

```sql
-- TABLE: missions — Source de vérité complète pour P3
CREATE TABLE missions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_number VARCHAR(20) UNIQUE NOT NULL,
    -- Auto-généré par trigger_set_mission_number → format 'FTM20260220XXXX'

    -- Parties
    client_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    driver_id UUID REFERENCES drivers(id)  ON DELETE SET NULL,

    -- Type & catégorie
    mission_type     mission_type     NOT NULL DEFAULT 'transport',
    -- 'transport' | 'ecommerce_parcel'
    vehicle_category vehicle_category NOT NULL,
    -- 'vul' | 'n2_medium' | 'n2_large'

    -- Localisation (PostGIS GEOGRAPHY)
    pickup_location  GEOGRAPHY(POINT, 4326) NOT NULL,
    pickup_address   TEXT NOT NULL,
    pickup_city      VARCHAR(100) NOT NULL,

    dropoff_location GEOGRAPHY(POINT, 4326) NOT NULL,
    dropoff_address  TEXT NOT NULL,
    dropoff_city     VARCHAR(100) NOT NULL,

    estimated_distance_km DECIMAL(10,2),
    -- Auto-calculé par trigger_set_distance via calculate_distance()

    -- Détails
    description        TEXT,
    needs_loading_help BOOLEAN DEFAULT false,

    -- Prix
    negotiated_price  DECIMAL(10,2),
    commission_amount DECIMAL(10,2),
    -- Auto-calculé par trigger_set_commission :
    -- vul=25 DH | n2_medium=40 DH | n2_large=50 DH
    payment_method    VARCHAR(20) DEFAULT 'cash',

    -- Statut & timing
    status                  mission_status DEFAULT 'pending',
    -- 'pending' | 'accepted' | 'in_progress' | 'completed'
    -- 'cancelled_client' | 'cancelled_driver'
    scheduled_pickup_time   TIMESTAMP WITH TIME ZONE,
    actual_pickup_time      TIMESTAMP WITH TIME ZONE,
    actual_dropoff_time     TIMESTAMP WITH TIME ZONE,

    -- Notes & évaluation
    client_notes    TEXT,
    driver_notes    TEXT,
    client_rating   INTEGER CHECK (client_rating >= 1 AND client_rating <= 5),
    driver_rating   INTEGER CHECK (driver_rating >= 1 AND driver_rating <= 5),
    client_review   TEXT,

    created_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at  TIMESTAMP WITH TIME ZONE
);
```

### 2.2 Vue available_drivers

```sql
-- VUE: available_drivers — Chauffeurs vérifiés ET disponibles
CREATE OR REPLACE VIEW available_drivers AS
SELECT
    d.id,
    d.profile_id,
    p.full_name,
    p.phone_number,
    d.vehicle_category,
    d.vehicle_brand,
    d.vehicle_model,
    d.license_plate,
    d.current_location,       -- GEOGRAPHY(POINT) pour ST_DWithin
    d.rating_average,
    d.total_missions,
    d.last_location_update
FROM drivers d
INNER JOIN profiles p ON p.id = d.profile_id
WHERE d.is_verified  = true   -- Tous les 4 documents vérifiés
  AND d.is_available = true   -- Driver en service
  AND p.is_active    = true;  -- Compte non suspendu
```

### 2.3 Fonctions SQL utilisées

```sql
-- Calcul commission par catégorie
SELECT calculate_commission('vul');       -- → 25.00
SELECT calculate_commission('n2_medium'); -- → 40.00
SELECT calculate_commission('n2_large'); -- → 50.00

-- Calcul distance entre deux points géographiques (en km)
SELECT calculate_distance(
    ST_GeographyFromText('POINT(-5.8 34.0)'),  -- Casablanca lng/lat
    ST_GeographyFromText('POINT(-7.5 33.5)')   -- Rabat lng/lat
); -- → ~180.50 km

-- Trouver les drivers dans un rayon (ST_DWithin — en mètres)
SELECT * FROM available_drivers
WHERE ST_DWithin(
    current_location,
    ST_GeographyFromText('POINT(-7.589843 33.573110)'), -- Point client
    15000  -- Rayon 15 km
)
AND vehicle_category = 'vul'
ORDER BY ST_Distance(current_location,
    ST_GeographyFromText('POINT(-7.589843 33.573110)')) ASC;
```

---

## 3. GÉOLOCALISATION — BACKGROUND LOCATION (CRITIQUE)

> ⚠️ INSTRUCTION SPÉCIFIQUE NATIVELY : Section la plus critique de P3.
> Le chauffeur DOIT être tracé même téléphone en poche ou app en arrière-plan.

### 3.1 Permissions Requises

```javascript
// /services/locationService.js

/**
 * PERMISSIONS NATIVELY À DÉCLARER :
 *
 * ANDROID (AndroidManifest.xml via Natively config) :
 *   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
 *   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
 *   <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
 *   <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
 *   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
 *
 * iOS (Info.plist via Natively config) :
 *   NSLocationWhenInUseUsageDescription
 *     → "FTM utilise votre position pour les missions en cours"
 *   NSLocationAlwaysAndWhenInUseUsageDescription
 *     → "FTM a besoin de votre position en arrière-plan pour informer les clients"
 *   NSLocationAlwaysUsageDescription
 *     → "FTM trace votre position même en arrière-plan pour la sécurité des missions"
 *   UIBackgroundModes : location (dans Capabilities)
 *
 * NATIVELY CONFIG :
 *   Dans le dashboard Natively, activer :
 *   ✅ Geolocation
 *   ✅ Background Location
 *   ✅ Foreground Service (Android)
 */
```

### 3.2 Demande de Permissions (Double étape obligatoire)

```javascript
// /services/locationService.js

import * as Location from 'expo-location'; // ou Natively Location API

/**
 * ÉTAPE 1 : Demander "When In Use" d'abord
 * ÉTAPE 2 : Demander "Always" (Background) ensuite
 * iOS exige cet ordre — refus direct de "Always" sans étape 1
 */
export async function requestLocationPermissions() {
  console.log('[FTM-DEBUG] GPS - Requesting location permissions');

  // Étape 1 : permission foreground
  const { status: fgStatus } = await Location.requestForegroundPermissionsAsync();

  if (fgStatus !== 'granted') {
    console.log('[FTM-DEBUG] GPS - Foreground permission denied', { status: fgStatus });
    return {
      granted: false,
      error: 'Permission de localisation refusée. Activez-la dans les réglages.',
    };
  }

  console.log('[FTM-DEBUG] GPS - Foreground permission granted');

  // Étape 2 : permission background (CRITIQUE pour le tracking chauffeur)
  const { status: bgStatus } = await Location.requestBackgroundPermissionsAsync();

  if (bgStatus !== 'granted') {
    console.log('[FTM-DEBUG] GPS - Background permission denied', { status: bgStatus });
    // On continue mais en mode dégradé (pas de tracking en arrière-plan)
    return {
      granted: true,
      backgroundGranted: false,
      warning: 'Tracking arrière-plan non autorisé. Gardez l\'app ouverte pendant les missions.',
    };
  }

  console.log('[FTM-DEBUG] GPS - Background permission granted (full tracking active)');
  return { granted: true, backgroundGranted: true };
}
```

### 3.3 Service de Tracking Continu (Foreground Service Android)

```javascript
// /services/locationService.js (suite)

/**
 * DÉMARRAGE DU TRACKING EN ARRIÈRE-PLAN
 * Android : Foreground Service avec notification persistante
 * iOS     : Background Location mode "Always"
 *
 * Ce service tourne INDÉPENDAMMENT de l'état de l'app :
 * - App ouverte         ✅ tracking actif
 * - App en arrière-plan ✅ tracking actif  ← CRITIQUE
 * - Écran verrouillé    ✅ tracking actif  ← CRITIQUE
 * - App fermée          ✅ tracking actif (Android Foreground Service)
 */

const TRACKING_CONFIG = {
  accuracy:          Location.Accuracy.High,   // GPS précis (±5m)
  timeInterval:      15000,                    // Toutes les 15 secondes
  distanceInterval:  50,                       // Ou tous les 50 mètres
  foregroundService: {
    notificationTitle:    'Fast Trans Maroc — En service',
    notificationBody:     'Votre position est partagée avec vos clients.',
    notificationColor:    '#0056B3', // COLORS.primary
  },
};

let locationSubscription = null;

export async function startBackgroundTracking(driverId) {
  console.log('[FTM-DEBUG] GPS - Starting background tracking', { driverId });

  // Vérifier permissions avant démarrage
  const perms = await requestLocationPermissions();
  if (!perms.granted) {
    console.log('[FTM-DEBUG] GPS - Cannot start tracking: permissions denied');
    return { error: perms.error };
  }

  // Arrêter tout tracking existant
  await stopBackgroundTracking();

  try {
    // Démarrer le tracking continu
    locationSubscription = await Location.watchPositionAsync(
      TRACKING_CONFIG,
      async (location) => {
        const { latitude, longitude, accuracy } = location.coords;

        console.log('[FTM-DEBUG] GPS - Position update', {
          driverId,
          lat:      latitude,
          lng:      longitude,
          accuracy: Math.round(accuracy) + 'm',
          timestamp: new Date(location.timestamp).toISOString(),
        });

        // Envoyer la position vers Supabase
        await updateDriverLocation(driverId, latitude, longitude);
      }
    );

    console.log('[FTM-DEBUG] GPS - Background tracking started successfully', {
      driverId,
      interval: TRACKING_CONFIG.timeInterval / 1000 + 's',
      distance: TRACKING_CONFIG.distanceInterval + 'm',
    });

    return { success: true };

  } catch (err) {
    console.log('[FTM-DEBUG] GPS - Start tracking error', { err: err.message });
    return { error: err.message };
  }
}

export async function stopBackgroundTracking() {
  if (locationSubscription) {
    locationSubscription.remove();
    locationSubscription = null;
    console.log('[FTM-DEBUG] GPS - Background tracking stopped');
  }
}

/**
 * MISE À JOUR POSITION DANS SUPABASE
 * Colonne : drivers.current_location (GEOGRAPHY POINT)
 * Format PostGIS : longitude EN PREMIER, latitude EN SECOND (standard GeoJSON)
 */
async function updateDriverLocation(driverId, latitude, longitude) {
  const { error } = await supabase
    .from('drivers')
    .update({
      current_location:     `POINT(${longitude} ${latitude})`,
      // ⚠️ IMPORTANT : PostGIS = POINT(lng lat), PAS POINT(lat lng)
      last_location_update: new Date().toISOString(),
    })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] GPS - Location update error', {
      driverId,
      error: error.message,
    });
  }
  // Pas de log succès ici (trop fréquent — toutes les 15s)
}
```

### 3.4 Récupérer la Position Actuelle du Client

```javascript
/**
 * Position unique pour la création de mission (Client)
 * Pas besoin de background tracking côté client
 */
export async function getClientCurrentLocation() {
  console.log('[FTM-DEBUG] GPS - Getting client current location');

  const { status } = await Location.requestForegroundPermissionsAsync();
  if (status !== 'granted') {
    console.log('[FTM-DEBUG] GPS - Client location permission denied');
    return { error: 'Activez la localisation pour trouver des chauffeurs proches.' };
  }

  try {
    const location = await Location.getCurrentPositionAsync({
      accuracy: Location.Accuracy.Balanced,
    });

    const { latitude, longitude } = location.coords;

    console.log('[FTM-DEBUG] GPS - Client location obtained', {
      lat: latitude,
      lng: longitude,
    });

    return { success: true, latitude, longitude };

  } catch (err) {
    console.log('[FTM-DEBUG] GPS - Get location error', { err: err.message });
    return { error: 'Impossible d\'obtenir votre position. Réessayez.' };
  }
}

/**
 * Convertir coordonnées GPS en adresse lisible (Reverse Geocoding)
 */
export async function reverseGeocode(latitude, longitude) {
  console.log('[FTM-DEBUG] GPS - Reverse geocoding', { latitude, longitude });

  try {
    const result = await Location.reverseGeocodeAsync({ latitude, longitude });

    if (result && result.length > 0) {
      const place = result[0];
      const address = [
        place.streetNumber,
        place.street,
        place.district,
        place.city,
      ].filter(Boolean).join(', ');

      console.log('[FTM-DEBUG] GPS - Address resolved', { address, city: place.city });
      return { address, city: place.city || '' };
    }

    return { address: `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`, city: '' };

  } catch (err) {
    console.log('[FTM-DEBUG] GPS - Reverse geocode error', { err: err.message });
    return { address: `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`, city: '' };
  }
}
```

---

## 4. SERVICE MISSIONS

```javascript
// /services/missionService.js

import { supabase }    from '../lib/supabaseClient';
import { reverseGeocode } from './locationService';

/**
 * CRÉER UNE NOUVELLE MISSION (côté Client)
 * Les triggers SQL s'occupent automatiquement de :
 *   - mission_number  (trigger_set_mission_number)
 *   - commission_amount (trigger_set_commission)
 *   - estimated_distance_km (trigger_set_distance)
 */
export async function createMission(clientProfileId, missionData) {
  console.log('[FTM-DEBUG] Mission - Creating mission', {
    clientId:        clientProfileId,
    vehicleCategory: missionData.vehicle_category,
    pickupCity:      missionData.pickup_city,
    dropoffCity:     missionData.dropoff_city,
    needsLoading:    missionData.needs_loading_help,
    missionType:     missionData.mission_type,
  });

  const { data, error } = await supabase
    .from('missions')
    .insert({
      client_id:        clientProfileId,
      mission_type:     missionData.mission_type || 'transport',
      vehicle_category: missionData.vehicle_category,

      // Pickup — format PostGIS : POINT(longitude latitude)
      pickup_location:  `POINT(${missionData.pickup_lng} ${missionData.pickup_lat})`,
      pickup_address:   missionData.pickup_address,
      pickup_city:      missionData.pickup_city,

      // Dropoff
      dropoff_location: `POINT(${missionData.dropoff_lng} ${missionData.dropoff_lat})`,
      dropoff_address:  missionData.dropoff_address,
      dropoff_city:     missionData.dropoff_city,

      description:        missionData.description     || null,
      needs_loading_help: missionData.needs_loading_help || false,
      negotiated_price:   missionData.negotiated_price   || null,
      client_notes:       missionData.client_notes       || null,
      payment_method:     'cash', // FTM = Cash uniquement
      status:             'pending',
    })
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Creation error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Mission - Created successfully', {
    missionId:     data.id,
    missionNumber: data.mission_number,       // ex: FTM202602200047
    commission:    data.commission_amount,    // auto-calculé par trigger
    distanceKm:    data.estimated_distance_km, // auto-calculé par trigger
    status:        data.status,
  });

  return { success: true, mission: data };
}

/**
 * RECHERCHER LES CHAUFFEURS DISPONIBLES DANS UN RAYON
 * Utilise la vue available_drivers + PostGIS ST_DWithin
 *
 * @param {number} clientLat       - Latitude du point de départ client
 * @param {number} clientLng       - Longitude du point de départ client
 * @param {string} vehicleCategory - 'vul' | 'n2_medium' | 'n2_large'
 * @param {number} radiusKm        - Rayon de recherche (défaut: 15 km)
 */
export async function findNearbyDrivers(clientLat, clientLng, vehicleCategory, radiusKm = 15) {
  console.log('[FTM-DEBUG] GPS - Searching nearby drivers', {
    clientLat,
    clientLng,
    vehicleCategory,
    radiusKm,
  });

  // PostGIS : ST_DWithin avec distance en mètres
  const radiusMeters = radiusKm * 1000;
  const clientPoint  = `POINT(${clientLng} ${clientLat})`; // lng lat !

  const { data, error } = await supabase
    .rpc('find_nearby_drivers', {
      client_point:      clientPoint,
      radius_meters:     radiusMeters,
      p_vehicle_category: vehicleCategory,
    });

  // Voir Section 4.1 pour la fonction SQL RPC correspondante

  if (error) {
    console.log('[FTM-DEBUG] GPS - Find nearby drivers error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] GPS - Nearby drivers found', {
    count:           data?.length || 0,
    vehicleCategory,
    radiusKm,
    drivers: data?.map(d => ({
      driverId:    d.id,
      name:        d.full_name,
      distanceKm:  d.distance_km,
      rating:      d.rating_average,
    })),
  });

  return { success: true, drivers: data || [] };
}

/**
 * ACCEPTER UNE MISSION (côté Driver)
 */
export async function acceptMission(missionId, driverId) {
  console.log('[FTM-DEBUG] Mission - Driver accepting mission', { missionId, driverId });

  const { data, error } = await supabase
    .from('missions')
    .update({
      driver_id: driverId,
      status:    'accepted',
    })
    .eq('id',     missionId)
    .eq('status', 'pending') // Guard : seulement si encore en attente
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
    missionId:     data.id,
    missionNumber: data.mission_number,
    driverId:      data.driver_id,
    status:        data.status,
  });

  return { success: true, mission: data };
}

/**
 * DÉMARRER UNE MISSION — Driver arrivé au point de chargement
 */
export async function startMission(missionId, driverId) {
  console.log('[FTM-DEBUG] Mission - Starting mission', { missionId, driverId });

  const { data, error } = await supabase
    .from('missions')
    .update({
      status:             'in_progress',
      actual_pickup_time: new Date().toISOString(),
    })
    .eq('id',       missionId)
    .eq('driver_id', driverId)
    .eq('status',   'accepted')
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

  return { success: true, mission: data };
}

/**
 * TERMINER UNE MISSION — Livraison effectuée
 * Déclenche automatiquement trigger_process_commission :
 *   → déduit commission du wallet driver
 *   → crée entrée dans transactions
 *   → incrémente drivers.total_missions
 */
export async function completeMission(missionId, driverId, driverNotes) {
  console.log('[FTM-DEBUG] Mission - Completing mission', { missionId, driverId });

  const { data, error } = await supabase
    .from('missions')
    .update({
      status:              'completed',
      actual_dropoff_time: new Date().toISOString(),
      completed_at:        new Date().toISOString(),
      driver_notes:        driverNotes || null,
    })
    .eq('id',       missionId)
    .eq('driver_id', driverId)
    .eq('status',   'in_progress')
    .select()
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Mission - Complete error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Mission - Completed successfully', {
    missionId:     data.id,
    missionNumber: data.mission_number,
    commission:    data.commission_amount,
    dropoffTime:   data.actual_dropoff_time,
    // La commission a été déduite du wallet par le trigger SQL
  });

  return { success: true, mission: data };
}

/**
 * ANNULER UNE MISSION
 * @param {string} cancelledBy - 'client' | 'driver'
 */
export async function cancelMission(missionId, userId, cancelledBy) {
  const newStatus = cancelledBy === 'client'
    ? 'cancelled_client'
    : 'cancelled_driver';

  console.log('[FTM-DEBUG] Mission - Cancelling mission', {
    missionId,
    cancelledBy,
    newStatus,
  });

  const { data, error } = await supabase
    .from('missions')
    .update({ status: newStatus })
    .eq('id', missionId)
    .in('status', ['pending', 'accepted']) // Ne peut pas annuler une mission en cours
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

  return { success: true, mission: data };
}

/**
 * SOUMETTRE UNE ÉVALUATION (Client → Driver)
 * Déclenche trigger_update_rating → MàJ drivers.rating_average
 */
export async function submitClientRating(missionId, rating, review) {
  console.log('[FTM-DEBUG] Mission - Submitting client rating', {
    missionId,
    rating,
    hasReview: !!review,
  });

  const { data, error } = await supabase
    .from('missions')
    .update({
      client_rating: rating, // 1–5
      client_review: review || null,
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
    // trigger_update_rating a mis à jour drivers.rating_average
  });

  return { success: true, mission: data };
}
```

### 4.1 Fonction SQL RPC — find_nearby_drivers

```sql
-- À ajouter dans une migration Supabase
-- Fichier : supabase/migrations/20260221000000_add_rpc_nearby_drivers.sql

CREATE OR REPLACE FUNCTION find_nearby_drivers(
    client_point       TEXT,             -- Format: 'POINT(lng lat)'
    radius_meters      INTEGER,          -- Rayon en mètres
    p_vehicle_category vehicle_category  -- Filtre catégorie
)
RETURNS TABLE (
    id                  UUID,
    full_name           TEXT,
    phone_number        VARCHAR,
    vehicle_category    vehicle_category,
    vehicle_brand       VARCHAR,
    vehicle_model       VARCHAR,
    license_plate       VARCHAR,
    rating_average      DECIMAL,
    total_missions      INTEGER,
    distance_km         DECIMAL,
    last_location_update TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ad.id,
        ad.full_name::TEXT,
        ad.phone_number,
        ad.vehicle_category,
        ad.vehicle_brand,
        ad.vehicle_model,
        ad.license_plate,
        ad.rating_average,
        ad.total_missions,
        ROUND((ST_Distance(
            ad.current_location,
            ST_GeographyFromText(client_point)
        ) / 1000)::NUMERIC, 2) AS distance_km,
        ad.last_location_update
    FROM available_drivers ad
    WHERE ST_DWithin(
        ad.current_location,
        ST_GeographyFromText(client_point),
        radius_meters
    )
    AND ad.vehicle_category = p_vehicle_category
    -- Exclure les drivers dont la position n'a pas été mise à jour depuis 5 min
    AND ad.last_location_update > NOW() - INTERVAL '5 minutes'
    ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 5. REALTIME — ABONNEMENTS SUPABASE

```javascript
// /services/realtimeService.js

import { supabase } from '../lib/supabaseClient';

/**
 * ABONNEMENT 1 : Client écoute les changements de SA mission
 * (accepted → in_progress → completed)
 */
export function subscribeToMissionUpdates(missionId, onUpdate) {
  console.log('[FTM-DEBUG] Realtime - Subscribing to mission updates', { missionId });

  const channel = supabase
    .channel(`mission-${missionId}`)
    .on(
      'postgres_changes',
      {
        event:  'UPDATE',
        schema: 'public',
        table:  'missions',
        filter: `id=eq.${missionId}`,
      },
      (payload) => {
        console.log('[FTM-DEBUG] Realtime - Mission update received', {
          missionId,
          oldStatus: payload.old.status,
          newStatus: payload.new.status,
          driverId:  payload.new.driver_id,
        });
        onUpdate(payload.new);
      }
    )
    .subscribe((status) => {
      console.log('[FTM-DEBUG] Realtime - Mission subscription status', { missionId, status });
    });

  return channel;
}

/**
 * ABONNEMENT 2 : Driver écoute les nouvelles missions dans sa zone
 * (missions 'pending' avec sa vehicle_category)
 */
export function subscribeToNewMissions(vehicleCategory, driverLocation, onNewMission) {
  console.log('[FTM-DEBUG] Realtime - Subscribing to new missions', { vehicleCategory });

  const channel = supabase
    .channel(`new-missions-${vehicleCategory}`)
    .on(
      'postgres_changes',
      {
        event:  'INSERT',
        schema: 'public',
        table:  'missions',
        filter: `vehicle_category=eq.${vehicleCategory}`,
      },
      (payload) => {
        const mission = payload.new;
        console.log('[FTM-DEBUG] Realtime - New mission received', {
          missionId:     mission.id,
          missionNumber: mission.mission_number,
          pickupCity:    mission.pickup_city,
          dropoffCity:   mission.dropoff_city,
          commission:    mission.commission_amount,
        });
        onNewMission(mission);
      }
    )
    .subscribe();

  return channel;
}

/**
 * ABONNEMENT 3 : Client suit la position du driver EN TEMPS RÉEL
 * Écoute les changements de drivers.current_location
 */
export function subscribeToDriverLocation(driverId, onLocationUpdate) {
  console.log('[FTM-DEBUG] Realtime - Subscribing to driver location', { driverId });

  const channel = supabase
    .channel(`driver-location-${driverId}`)
    .on(
      'postgres_changes',
      {
        event:  'UPDATE',
        schema: 'public',
        table:  'drivers',
        filter: `id=eq.${driverId}`,
      },
      (payload) => {
        console.log('[FTM-DEBUG] Realtime - Driver location update', {
          driverId,
          lastUpdate: payload.new.last_location_update,
        });
        onLocationUpdate(payload.new);
      }
    )
    .subscribe();

  return channel;
}

/**
 * NETTOYAGE : Désabonner un channel (appeler sur unmount)
 */
export async function unsubscribeChannel(channel) {
  if (channel) {
    await supabase.removeChannel(channel);
    console.log('[FTM-DEBUG] Realtime - Channel unsubscribed');
  }
}
```

---

## 6. ÉCRANS CLIENT

### 6.1 Écran Création de Mission

```javascript
// /screens/client/CreateMissionScreen.js

/**
 * ÉTAT LOCAL
 * - pickupCoords   : { lat, lng } | null
 * - pickupAddress  : string
 * - pickupCity     : string
 * - dropoffCoords  : { lat, lng } | null
 * - dropoffAddress : string
 * - dropoffCity    : string
 * - vehicleCategory: 'vul' | 'n2_medium' | 'n2_large' | null
 * - needsLoading   : boolean
 * - description    : string
 * - negotiatedPrice: string
 * - isLoading      : boolean
 */

/**
 * FLOW :
 * 1. App géolocalise le client → remplit pickup automatiquement
 * 2. Client saisit/confirme l'adresse de départ
 * 3. Client saisit l'adresse d'arrivée (dropoff) avec autocomplete
 * 4. Sélectionne la catégorie véhicule (affiche commission correspondante)
 * 5. Options : manutention (needs_loading_help) + description + prix négocié
 * 6. Bouton "Trouver un chauffeur" → createMission() → MissionTrackingScreen
 */

/**
 * UI — CreateMissionScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────────┐
 * │  "Nouvelle mission"                  │
 * │                                      │
 * │  📍 DÉPART                           │
 * │  [🎯 Ma position actuelle]           │
 * │  [Input] ou modifier l'adresse      │
 * │                                      │
 * │  🏁 ARRIVÉE                          │
 * │  [Input] Adresse de livraison       │
 * │  (Autocomplete villes marocaines)   │
 * │                                      │
 * │  VÉHICULE                           │
 * │  [🚐 VUL 25DH] [🚛 N2 40DH] [🚚 50DH]│
 * │                                      │
 * │  OPTIONS                            │
 * │  [Toggle] 💪 Manutention (+info)    │
 * │  [Input] Description du chargement  │
 * │  [Input] Prix proposé (DH) optionnel│
 * │                                      │
 * │  [Carte miniature pickup→dropoff]   │
 * │  Distance estimée : ~XX km          │
 * │                                      │
 * │  [Bouton "Trouver un chauffeur"]    │
 * │  Commission : XX DH (auto-calculée) │
 * └──────────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - Auto-fill pickup depuis GPS (getClientCurrentLocation)
 * - Calcul distance préliminaire en temps réel (affichage indicatif)
 * - Commission affichée dynamiquement selon vehicle_category choisie
 * - Bouton désactivé si pickup, dropoff ou vehicleCategory manquants
 */
```

### 6.2 Écran Tracking de Mission (Client)

```javascript
// /screens/client/MissionTrackingScreen.js

/**
 * PROPS : mission (objet complet depuis createMission)
 *
 * ÉTAT LOCAL
 * - mission       : object (mis à jour par Realtime)
 * - driverInfo    : object | null
 * - driverLocation: { lat, lng } | null
 * - missionChannel : channel Supabase
 * - locationChannel: channel Supabase
 */

/**
 * CYCLE DE VIE DES ABONNEMENTS :
 * - componentDidMount  → subscribeToMissionUpdates() + subscribeToDriverLocation()
 * - componentWillUnmount → unsubscribeChannel() sur les 2 channels
 */

/**
 * AFFICHAGE SELON LE STATUT :
 *
 * 'pending' :
 *   🔍 "Recherche d'un chauffeur..."
 *   Spinner animé
 *   Infos mission : N°, adresses, catégorie, distance
 *   [Bouton "Annuler"] (COLORS.alert)
 *
 * 'accepted' :
 *   ✅ "Chauffeur trouvé !"
 *   Card driver : Photo placeholder / Nom / Note ⭐ / Véhicule / Plaque
 *   [Bouton 📞 Appeler] → tel:{phone_number}
 *   Carte : position driver → point pickup (flèche bleue)
 *   ETA estimé (basé sur distance driver→pickup)
 *   [Bouton "Annuler"] toujours disponible
 *
 * 'in_progress' :
 *   🚚 "Mission en cours"
 *   Carte : position driver en temps réel (icône camion animé)
 *   Itinéraire : pickup → dropoff
 *   Chronomètre départ depuis actual_pickup_time
 *   [PAS de bouton Annuler en cours de route]
 *
 * 'completed' :
 *   ✅ "Mission terminée !"
 *   Résumé : durée, distance, montant payé
 *   → Navigation automatique vers RatingScreen
 *   (après 2 secondes)
 *
 * 'cancelled_driver' :
 *   ❌ "Mission annulée par le chauffeur"
 *   [Bouton "Créer une nouvelle mission"]
 */
```

### 6.3 Écran Évaluation (Client)

```javascript
// /screens/client/RatingScreen.js

/**
 * UI — RatingScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────┐
 * │  "Comment s'est passée          │
 * │   votre mission ?"              │
 * │                                  │
 * │  [Nom du chauffeur]             │
 * │  [Véhicule — Plaque]            │
 * │                                  │
 * │  ☆ ☆ ☆ ☆ ☆  (étoiles cliquables)│
 * │                                  │
 * │  [TextArea] Laissez un avis...  │
 * │  (optionnel)                    │
 * │                                  │
 * │  [Bouton "Envoyer mon avis"]    │
 * │  (COLORS.primary)               │
 * │  [Lien "Passer"] (texte gris)   │
 * └──────────────────────────────────┘
 *
 * Note 1★ → COLORS.alert (rouge)
 * Note 3★ → COLORS.cta (ambre)
 * Note 5★ → COLORS.success (vert)
 * Après soumission : → ClientHomeScreen
 */
```

---

## 7. ÉCRANS DRIVER

### 7.1 Écran d'Accueil Driver (Toggle Disponibilité)

```javascript
// /screens/driver/DriverHomeScreen.js

/**
 * ÉTAT LOCAL
 * - isAvailable     : boolean (sync avec drivers.is_available)
 * - activeChannel   : channel Supabase | null
 * - currentMission  : object | null
 * - driverProfile   : object (depuis getDriverProfile)
 * - trackingStarted : boolean
 */

/**
 * TOGGLE DISPONIBILITÉ
 * Quand le driver passe en "disponible" :
 * 1. Démarrer le background tracking GPS
 * 2. Mettre à jour drivers.is_available = true
 * 3. S'abonner aux nouvelles missions (subscribeToNewMissions)
 *
 * Quand il passe en "indisponible" :
 * 1. Arrêter le background tracking (stopBackgroundTracking)
 * 2. Mettre à jour drivers.is_available = false
 * 3. Se désabonner des nouvelles missions
 */

async function toggleAvailability(driverId, currentStatus, vehicleCategory) {
  const newStatus = !currentStatus;

  console.log('[FTM-DEBUG] Driver - Toggling availability', {
    driverId,
    from:    currentStatus,
    to:      newStatus,
  });

  if (newStatus === true) {
    // Démarrer le tracking avant de se déclarer disponible
    const trackResult = await startBackgroundTracking(driverId);
    if (trackResult.error) {
      console.log('[FTM-DEBUG] Driver - Cannot go available: GPS error', {
        error: trackResult.error,
      });
      return { error: trackResult.error };
    }
  } else {
    await stopBackgroundTracking();
  }

  const { error } = await supabase
    .from('drivers')
    .update({ is_available: newStatus })
    .eq('id', driverId);

  if (error) {
    console.log('[FTM-DEBUG] Driver - Toggle availability error', { error: error.message });
    return { error: error.message };
  }

  console.log('[FTM-DEBUG] Driver - Availability updated', { driverId, isAvailable: newStatus });
  return { success: true, isAvailable: newStatus };
}

/**
 * UI — DriverHomeScreen
 *
 * LAYOUT :
 * ┌──────────────────────────────────┐
 * │  Bonjour, [Prénom]  ⭐ 4.8      │
 * │  [Véhicule] — [Plaque]          │
 * │                                  │
 * │  💰 Wallet : 340 DH             │
 * │  (COLORS.success si > 100 DH)   │
 * │  (COLORS.alert si < 100 DH)     │
 * │                                  │
 * │  ┌────────────────────────────┐  │
 * │  │  JE SUIS                   │  │
 * │  │  ● DISPONIBLE  / ○ HORS   │  │
 * │  │    SERVICE                 │  │
 * │  │  (Grand toggle centré)     │  │
 * │  │  Vert si ON / Gris si OFF  │  │
 * │  └────────────────────────────┘  │
 * │                                  │
 * │  [Carte — Ma position actuelle] │
 * │  (affichée quand disponible)    │
 * │                                  │
 * │  MISSIONS DU JOUR              │
 * │  Complétées: X | En attente: Y  │
 * └──────────────────────────────────┘
 */
```

### 7.2 Modal Nouvelle Mission (Alerte Driver)

```javascript
// /screens/driver/NewMissionModal.js

/**
 * Affiché en overlay quand une nouvelle mission correspond
 * au vehicleCategory du driver ET dans son rayon de 15km
 *
 * TIMING :
 * - Apparaît automatiquement via subscribeToNewMissions()
 * - Timer de 30 secondes pour accepter ou refuser
 * - Si timeout → mission retourne dans le pool (pas d'annulation automatique)
 *
 * UI — NewMissionModal
 *
 * LAYOUT :
 * ┌──────────────────────────────────┐
 * │  🔔 NOUVELLE MISSION             │
 * │  N° FTM202602200047             │
 * │                                  │
 * │  📍 Départ : [pickup_address]   │
 * │  🏁 Arrivée : [dropoff_address] │
 * │                                  │
 * │  📏 Distance : ~XX km           │
 * │  💰 Commission : XX DH          │
 * │  💪 Manutention : Oui / Non     │
 * │                                  │
 * │  [ProgressBar rouge — 30s]      │
 * │                                  │
 * │  [✅ ACCEPTER]  [❌ REFUSER]    │
 * │  (COLORS.success) (COLORS.alert)│
 * └──────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - Son/vibration à l'apparition (NativelyHaptics)
 * - Countdown 30s visible
 * - "Accepter" → acceptMission() → MissionActiveScreen
 * - "Refuser" → modal fermée, mission reste 'pending' pour d'autres drivers
 * - Timeout → modal fermée silencieusement
 */
```

### 7.3 Écran Mission Active (Driver)

```javascript
// /screens/driver/MissionActiveScreen.js

/**
 * PROPS : mission (après acceptMission())
 *
 * ÉTAPES VISUELLES :
 *
 * Phase 1 — En route vers le client (status: 'accepted')
 * ┌──────────────────────────────────┐
 * │  🚗 En route vers le client     │
 * │  📍 [pickup_address]            │
 * │  [Carte : ma position → pickup] │
 * │  [Bouton "Ouvrir dans Maps"]    │
 * │  → intent : geo:{lat},{lng}     │
 * │                                  │
 * │  [Bouton "J'arrive — Démarrer"] │
 * │  (COLORS.primary, 52px)         │
 * └──────────────────────────────────┘
 *
 * Phase 2 — Mission en cours (status: 'in_progress')
 * ┌──────────────────────────────────┐
 * │  🚚 Mission en cours            │
 * │  N° FTM202602200047            │
 * │  🏁 [dropoff_address]           │
 * │  [Carte : ma position → dropoff]│
 * │  [Bouton "Ouvrir dans Maps"]    │
 * │  ⏱ Durée : 00:47:23            │
 * │                                  │
 * │  [Bouton "Mission terminée ✓"]  │
 * │  (COLORS.success)               │
 * └──────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - "Ouvrir dans Maps" : deep link Google Maps ou Apple Maps natif
 *   Android : `https://maps.google.com/?daddr={lat},{lng}`
 *   iOS     : `maps://?daddr={lat},{lng}`
 * - "J'arrive" → startMission()
 * - "Mission terminée" → completeMission() → EcranRésuméDriver
 */
```

---

## 8. HISTOGRAMME DES STATUTS — RÉCAPITULATIF

```
STATUS FLOW COMPLET :

'pending'          → Mission créée par client, en attente d'un driver
      │
      ├─ Driver accepte ─────────────────→ 'accepted'
      │                                         │
      ├─ Client annule ──────────────────→ 'cancelled_client'
      │                                         │
      │                                    Driver arrive
      │                                         │
      │                                    'in_progress'
      │                                         │
      │                                    Livraison faite
      │                                         │
      │                                    'completed'
      │                                    ↓ trigger auto :
      │                                    • commission déduite wallet
      │                                    • transaction créée
      │                                    • total_missions + 1
      │
      ├─ Driver refuse ──────────────────→ reste 'pending' (pour autres drivers)
      │
      └─ Driver annule (si accepted) ───→ 'cancelled_driver'

RÈGLE : Annulation impossible si status = 'in_progress' ou 'completed'
```

---

## 9. ARBORESCENCE DES FICHIERS — PÉRIMÈTRE P3

```
src/
├── services/
│   ├── missionService.js      ← CRUD missions, accepter, démarrer, terminer, évaluer
│   ├── locationService.js     ← GPS foreground/background, updateDriverLocation, reverseGeocode
│   └── realtimeService.js     ← subscribeToMission, subscribeToNewMissions, subscribeToDriverLocation
├── screens/
│   ├── client/
│   │   ├── CreateMissionScreen.js   ← Formulaire mission + sélection véhicule
│   │   ├── MissionTrackingScreen.js ← Suivi temps réel (tous statuts)
│   │   └── RatingScreen.js          ← Évaluation post-mission
│   └── driver/
│       ├── DriverHomeScreen.js      ← Toggle disponibilité + wallet solde
│       ├── NewMissionModal.js       ← Alerte nouvelle mission (30s countdown)
│       └── MissionActiveScreen.js   ← Navigation + démarrer + terminer
supabase/
└── migrations/
    └── 20260221000000_add_rpc_nearby_drivers.sql  ← Fonction find_nearby_drivers()
```

---

## 10. RÉCAPITULATIF DES LOGS DE DEBUG (P3)

| Action | Log FTM-DEBUG |
|--------|---------------|
| Demande permission foreground | `[FTM-DEBUG] GPS - Requesting location permissions` |
| Permission foreground OK | `[FTM-DEBUG] GPS - Foreground permission granted` |
| Permission background refusée | `[FTM-DEBUG] GPS - Background permission denied` |
| Permission background OK | `[FTM-DEBUG] GPS - Background permission granted (full tracking active)` |
| Démarrage tracking | `[FTM-DEBUG] GPS - Starting background tracking` |
| Position reçue | `[FTM-DEBUG] GPS - Position update` |
| Erreur update position | `[FTM-DEBUG] GPS - Location update error` |
| Arrêt tracking | `[FTM-DEBUG] GPS - Background tracking stopped` |
| Position client obtenue | `[FTM-DEBUG] GPS - Client location obtained` |
| Reverse geocoding | `[FTM-DEBUG] GPS - Reverse geocoding` |
| Adresse résolue | `[FTM-DEBUG] GPS - Address resolved` |
| Recherche drivers | `[FTM-DEBUG] GPS - Searching nearby drivers` |
| Drivers trouvés | `[FTM-DEBUG] GPS - Nearby drivers found` |
| Création mission | `[FTM-DEBUG] Mission - Creating mission` |
| Mission créée | `[FTM-DEBUG] Mission - Created successfully` |
| Acceptation mission | `[FTM-DEBUG] Mission - Driver accepting mission` |
| Mission acceptée | `[FTM-DEBUG] Mission - Accepted successfully` |
| Mission déjà prise | `[FTM-DEBUG] Mission - Accept failed: mission already taken` |
| Démarrage mission | `[FTM-DEBUG] Mission - Starting mission` |
| Mission démarrée | `[FTM-DEBUG] Mission - Started` |
| Fin mission | `[FTM-DEBUG] Mission - Completing mission` |
| Mission terminée | `[FTM-DEBUG] Mission - Completed successfully` |
| Annulation mission | `[FTM-DEBUG] Mission - Cancelling mission` |
| Évaluation soumise | `[FTM-DEBUG] Mission - Rating submitted` |
| Toggle disponibilité | `[FTM-DEBUG] Driver - Toggling availability` |
| Disponibilité MàJ | `[FTM-DEBUG] Driver - Availability updated` |
| Sub. mission | `[FTM-DEBUG] Realtime - Subscribing to mission updates` |
| Update mission reçu | `[FTM-DEBUG] Realtime - Mission update received` |
| Sub. nouvelles missions | `[FTM-DEBUG] Realtime - Subscribing to new missions` |
| Nouvelle mission reçue | `[FTM-DEBUG] Realtime - New mission received` |
| Sub. position driver | `[FTM-DEBUG] Realtime - Subscribing to driver location` |
| Position driver reçue | `[FTM-DEBUG] Realtime - Driver location update` |
| Désabonnement channel | `[FTM-DEBUG] Realtime - Channel unsubscribed` |

---

## 11. CHECKLIST DE VALIDATION P3

- [ ] Permissions `ACCESS_BACKGROUND_LOCATION` déclarées dans Natively config (Android)
- [ ] `UIBackgroundModes: location` déclaré dans Natively config (iOS)
- [ ] `startBackgroundTracking()` : position envoyée toutes les 15s même app fermée
- [ ] `updateDriverLocation()` : colonne `drivers.current_location` mise à jour en format `POINT(lng lat)`
- [ ] Fonction SQL `find_nearby_drivers()` migrée et testée dans Supabase SQL Editor
- [ ] `createMission()` : triggers automatiques vérifiés (mission_number, commission, distance)
- [ ] Realtime `subscribeToMissionUpdates()` : changement de statut reçu < 1 seconde
- [ ] `acceptMission()` : guard `.eq('status', 'pending')` empêche double-acceptation
- [ ] `completeMission()` : trigger `process_commission_payment` vérifié → wallet débité
- [ ] Driver `NewMissionModal` : apparaît en < 2s après création mission client
- [ ] `unsubscribeChannel()` appelé sur chaque unmount pour éviter les fuites mémoire
- [ ] Tous les `console.log('[FTM-DEBUG]...')` visibles dans Debug Console Codespaces

---

## 12. LIAISON AVEC LES PARTIES SUIVANTES

| Partie | Dépendance de P3 |
|--------|-----------------|
| **P4** | `missions.id` + `mission_type = 'ecommerce_parcel'` → table `ecommerce_parcels` |
| **P5** | `completeMission()` déclenche trigger → `wallet` + `transactions` |
| **P6** | Nouvelles missions + changements statut → Push notifications `notifications` |
| **P7** | Admin consulte toutes les missions, statistiques globales |

---

*FTM Spec P3 — Fin du fichier*
*Prochaine étape : SPEC_NATIVELY_P4.md — Module E-commerce & Colisage*
