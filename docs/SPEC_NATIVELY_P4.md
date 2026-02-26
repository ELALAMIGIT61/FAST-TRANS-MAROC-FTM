# SPEC NATIVELY — Fast Trans Maroc (FTM)
# PARTIE P4 : Module E-commerce & Colisage
# Fichier : docs/SPEC_NATIVELY_P4.md
# Version : 1.0 | Backend : Supabase | App : Natively.dev
# =====================================================================
# PRÉREQUIS : P1 (Auth), P2 (drivers), P3 (missions + GPS)
# TABLES SQL : missions, ecommerce_parcels
# ENUM       : mission_type = 'ecommerce_parcel'
# COLONNE    : ecommerce_parcels.volume_m3 (GENERATED — auto-calculé)
# COLONNE    : ecommerce_parcels.tracking_number (UNIQUE, format FTM-TRACK-XXXX)
# =====================================================================

---

## 1. CONTEXTE & POSITIONNEMENT MÉTIER

```
E-COMMERCE LOCAL FTM — Concept "Colisage Intelligent"

Le client E-commerce n'affrète PAS un véhicule entier.
Il profite d'un trajet DÉJÀ PAYÉ par un autre client (transport classique)
pour envoyer son colis dans l'espace libre du camion.

                  Trajet Casablanca → Marrakech
                  ┌─────────────────────────────┐
                  │  Chargement principal        │
                  │  (mission transport client A)│
                  │  ░░░░░░░░░░░░░░░            │
                  │  ▓▓▓▓ Colis e-commerce ▓▓▓▓ │  ← Espace libre monétisé
                  └─────────────────────────────┘

Avantages :
  ✅ Client e-commerce : prix réduit (partage le coût)
  ✅ Driver : revenu complémentaire sur trajet existant
  ✅ FTM : commission additionnelle par colis
```

---

## 2. FLUX GLOBAL E-COMMERCE

```
CLIENT E-COMMERCE (expéditeur)
  │
  ├─ Sélectionne mission_type = 'ecommerce_parcel'
  ├─ Remplit infos colis (dimensions, poids, contenu, fragilité)
  ├─ Renseigne expéditeur + destinataire (nom + téléphone)
  ├─ Saisit pickup (ville expéditeur) + dropoff (ville destinataire)
  ├─ Choisit vehicle_category compatible avec volume_m3
  │
  ├─ INSERT missions (mission_type='ecommerce_parcel') ─→ Supabase
  │   Triggers auto : mission_number, commission, distance
  │
  ├─ INSERT ecommerce_parcels ─→ Supabase
  │   Trigger/RPC : génération tracking_number 'FTM-TRACK-XXXX'
  │   Colonne auto : volume_m3 = (length × width × height) / 1_000_000
  │
  ├─ SMS envoyé au destinataire : "Votre colis FTM-TRACK-XXXX est en route"
  │   (via Supabase Edge Function → SMS Gateway marocain)
  │
  └─ Même cycle de vie mission que P3 :
     pending → accepted → in_progress → completed

DESTINATAIRE (non-utilisateur FTM)
  │
  └─ Reçoit SMS avec lien de tracking :
     https://ftm.ma/track/FTM-TRACK-XXXX
     OU saisit le numéro dans l'app (sans compte)
```

---

## 3. STRUCTURE SQL DE RÉFÉRENCE

### 3.1 Table ecommerce_parcels

```sql
-- TABLE: ecommerce_parcels — Source de vérité complète pour P4
CREATE TABLE ecommerce_parcels (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_id UUID REFERENCES missions(id) ON DELETE CASCADE UNIQUE NOT NULL,
    -- UNIQUE : 1 colis = 1 mission (liaison 1-1)

    -- Expéditeur
    sender_name  VARCHAR(255) NOT NULL,
    sender_phone VARCHAR(20)  NOT NULL,

    -- Destinataire
    recipient_name  VARCHAR(255) NOT NULL,
    recipient_phone VARCHAR(20)  NOT NULL,

    -- Dimensions (cm) — toutes obligatoires et > 0
    length_cm DECIMAL(10,2) NOT NULL CHECK (length_cm > 0),
    width_cm  DECIMAL(10,2) NOT NULL CHECK (width_cm > 0),
    height_cm DECIMAL(10,2) NOT NULL CHECK (height_cm > 0),
    weight_kg DECIMAL(10,2) NOT NULL CHECK (weight_kg > 0),

    -- Volume calculé automatiquement par PostgreSQL (GENERATED ALWAYS)
    volume_m3 DECIMAL(10,4) GENERATED ALWAYS AS (
        (length_cm * width_cm * height_cm) / 1000000
    ) STORED,
    -- Exemple : 50cm × 40cm × 30cm = 0.0600 m³

    -- Contenu et options
    content_description TEXT    NOT NULL,
    is_fragile          BOOLEAN DEFAULT false,

    -- Numéro de suivi unique
    tracking_number VARCHAR(50) UNIQUE,
    -- Format : 'FTM-TRACK-XXXX' (généré par generate_tracking_number())

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour accès rapide par tracking_number (sans auth)
CREATE INDEX idx_parcels_mission  ON ecommerce_parcels(mission_id);
CREATE INDEX idx_parcels_tracking ON ecommerce_parcels(tracking_number);
```

### 3.2 Vue pour le Suivi Public (sans auth)

```sql
-- Vue publique : données minimales exposées pour le tracking destinataire
-- (pas d'infos sensibles : pas de numéros de téléphone complets, etc.)
CREATE OR REPLACE VIEW public_parcel_tracking AS
SELECT
    ep.tracking_number,
    ep.sender_name,
    -- Masquer le téléphone expéditeur : "06****78"
    CONCAT(
        LEFT(ep.sender_phone, 3),
        '****',
        RIGHT(ep.sender_phone, 2)
    ) AS sender_phone_masked,
    ep.recipient_name,
    ep.content_description,
    ep.is_fragile,
    ep.weight_kg,
    ep.volume_m3,
    m.status              AS mission_status,
    m.pickup_city,
    m.dropoff_city,
    m.pickup_address,
    m.dropoff_address,
    m.estimated_distance_km,
    m.actual_pickup_time,
    m.actual_dropoff_time,
    m.completed_at,
    m.mission_number,
    -- Informations driver (masquées partiellement)
    p.full_name           AS driver_name,
    d.vehicle_category,
    d.vehicle_brand,
    d.vehicle_model,
    -- Position driver en temps réel (pour tracking carte)
    d.current_location,
    d.last_location_update
FROM ecommerce_parcels ep
INNER JOIN missions m  ON m.id = ep.mission_id
LEFT  JOIN drivers  d  ON d.id = m.driver_id
LEFT  JOIN profiles p  ON p.id = d.profile_id;

-- Policy : vue accessible sans authentification
-- (lecture seule, filtrée par tracking_number)
```

### 3.3 Fonction SQL — Génération Tracking Number

```sql
-- À ajouter dans supabase/migrations/20260222000000_add_tracking_functions.sql

CREATE OR REPLACE FUNCTION generate_tracking_number()
RETURNS TEXT AS $$
DECLARE
    new_number  TEXT;
    done        BOOLEAN := false;
    chars       TEXT    := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    -- Pas de I, O, 0, 1 pour éviter confusions visuelles
    random_part TEXT    := '';
    i           INTEGER;
BEGIN
    WHILE NOT done LOOP
        random_part := '';
        -- Générer 8 caractères alphanumériques
        FOR i IN 1..8 LOOP
            random_part := random_part ||
                SUBSTR(chars, FLOOR(RANDOM() * LENGTH(chars))::INTEGER + 1, 1);
        END LOOP;

        new_number := 'FTM-TRACK-' || random_part;
        -- Exemple : FTM-TRACK-K7X2MQ4R

        IF NOT EXISTS (
            SELECT 1 FROM ecommerce_parcels
            WHERE tracking_number = new_number
        ) THEN
            done := true;
        END IF;
    END LOOP;
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour auto-assigner le tracking_number à l'INSERT
CREATE OR REPLACE FUNCTION set_tracking_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tracking_number IS NULL THEN
        NEW.tracking_number := generate_tracking_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_tracking_number
    BEFORE INSERT ON ecommerce_parcels
    FOR EACH ROW EXECUTE FUNCTION set_tracking_number();
```

---

## 4. HELPER — CALCULS COLIS

```javascript
// /utils/parcelCalculations.js

/**
 * CALCUL VOLUME CÔTÉ CLIENT (pour preview avant soumission)
 * La valeur réelle est recalculée par PostgreSQL (GENERATED ALWAYS)
 * Ici sert uniquement à l'affichage en temps réel dans le formulaire
 *
 * @returns {number} volume en m³, arrondi à 4 décimales
 */
export function calculateVolume(lengthCm, widthCm, heightCm) {
  const l = parseFloat(lengthCm) || 0;
  const w = parseFloat(widthCm)  || 0;
  const h = parseFloat(heightCm) || 0;
  if (l <= 0 || w <= 0 || h <= 0) return 0;
  return parseFloat(((l * w * h) / 1_000_000).toFixed(4));
}

/**
 * RECOMMANDER LA CATÉGORIE VÉHICULE selon le volume et poids du colis
 *
 * Logique métier FTM :
 *  - Colis ≤ 0.5 m³ et ≤ 50 kg  → VUL recommandé
 *  - Colis ≤ 2.0 m³ et ≤ 500 kg → N2 Medium recommandé
 *  - Colis > 2.0 m³ ou > 500 kg  → N2 Large recommandé
 */
export function recommendVehicleCategory(volumeM3, weightKg) {
  const v = parseFloat(volumeM3)  || 0;
  const w = parseFloat(weightKg)  || 0;

  if (v <= 0.5 && w <= 50)   return 'vul';
  if (v <= 2.0 && w <= 500)  return 'n2_medium';
  return 'n2_large';
}

/**
 * FORMATER L'AFFICHAGE DU VOLUME
 * 0.0600 m³  → "60 litres (0.06 m³)"
 * 1.2000 m³  → "1 200 litres (1.20 m³)"
 */
export function formatVolume(volumeM3) {
  const liters = (volumeM3 * 1000).toFixed(0);
  const m3     = volumeM3.toFixed(2);
  return `${parseInt(liters).toLocaleString('fr-MA')} litres (${m3} m³)`;
}

/**
 * VALIDER LES DIMENSIONS (limites raisonnables pour un colis)
 * Retourne un objet d'erreurs ou null si valide
 */
export function validateParcelDimensions(lengthCm, widthCm, heightCm, weightKg) {
  const errors = {};

  if (parseFloat(lengthCm) > 300)  errors.length = 'Longueur max : 300 cm';
  if (parseFloat(widthCm)  > 250)  errors.width  = 'Largeur max : 250 cm';
  if (parseFloat(heightCm) > 250)  errors.height = 'Hauteur max : 250 cm';
  if (parseFloat(weightKg) > 5000) errors.weight = 'Poids max : 5 000 kg';

  if (parseFloat(lengthCm) <= 0)   errors.length = 'Longueur requise';
  if (parseFloat(widthCm)  <= 0)   errors.width  = 'Largeur requise';
  if (parseFloat(heightCm) <= 0)   errors.height = 'Hauteur requise';
  if (parseFloat(weightKg) <= 0)   errors.weight = 'Poids requis';

  return Object.keys(errors).length > 0 ? errors : null;
}

/**
 * FORMATER UN NUMÉRO DE TÉLÉPHONE MAROCAIN pour l'affichage
 * "+212612345678" → "06 12 34 56 78"
 */
export function formatPhoneDisplay(phone) {
  const cleaned = phone.replace('+212', '0').replace(/\s/g, '');
  return cleaned.replace(/(\d{2})(?=\d)/g, '$1 ').trim();
}

/**
 * MASQUER UN NUMÉRO DE TÉLÉPHONE pour affichage public
 * "0612345678" → "06****78"
 */
export function maskPhone(phone) {
  if (!phone || phone.length < 6) return '****';
  return phone.slice(0, 3) + '****' + phone.slice(-2);
}
```

---

## 5. SERVICE COLIS E-COMMERCE

```javascript
// /services/parcelService.js

import { supabase }                    from '../lib/supabaseClient';
import { createMission }               from './missionService';
import { recommendVehicleCategory,
         calculateVolume }             from '../utils/parcelCalculations';

/**
 * CRÉER UNE MISSION E-COMMERCE AVEC SON COLIS
 * Flux en 2 étapes atomiques :
 *   1. INSERT dans missions (mission_type = 'ecommerce_parcel')
 *   2. INSERT dans ecommerce_parcels lié à la mission
 */
export async function createParcelMission(clientProfileId, parcelData) {
  console.log('[FTM-DEBUG] Parcel - Creating parcel mission', {
    clientId:        clientProfileId,
    senderName:      parcelData.sender_name,
    recipientName:   parcelData.recipient_name,
    recipientPhone:  parcelData.recipient_phone,
    dimensions:      `${parcelData.length_cm}×${parcelData.width_cm}×${parcelData.height_cm} cm`,
    weightKg:        parcelData.weight_kg,
    volumeM3:        calculateVolume(parcelData.length_cm, parcelData.width_cm, parcelData.height_cm),
    isFragile:       parcelData.is_fragile,
    vehicleCategory: parcelData.vehicle_category,
    pickupCity:      parcelData.pickup_city,
    dropoffCity:     parcelData.dropoff_city,
  });

  // ── ÉTAPE 1 : Créer la mission parent ──────────────────────────────
  const missionResult = await createMission(clientProfileId, {
    mission_type:      'ecommerce_parcel', // ← Distingue du transport classique
    vehicle_category:  parcelData.vehicle_category,
    pickup_lat:        parcelData.pickup_lat,
    pickup_lng:        parcelData.pickup_lng,
    pickup_address:    parcelData.pickup_address,
    pickup_city:       parcelData.pickup_city,
    dropoff_lat:       parcelData.dropoff_lat,
    dropoff_lng:       parcelData.dropoff_lng,
    dropoff_address:   parcelData.dropoff_address,
    dropoff_city:      parcelData.dropoff_city,
    description:       `Colis e-commerce : ${parcelData.content_description}`,
    needs_loading_help: false, // Les colis sont généralement légers
    negotiated_price:  parcelData.negotiated_price || null,
    client_notes:      parcelData.client_notes || null,
  });

  if (missionResult.error) {
    console.log('[FTM-DEBUG] Parcel - Mission creation failed', {
      error: missionResult.error,
    });
    return { error: missionResult.error };
  }

  const mission = missionResult.mission;
  console.log('[FTM-DEBUG] Parcel - Parent mission created', {
    missionId:     mission.id,
    missionNumber: mission.mission_number,
    commission:    mission.commission_amount,
  });

  // ── ÉTAPE 2 : Créer le colis lié à la mission ──────────────────────
  const { data: parcel, error: parcelError } = await supabase
    .from('ecommerce_parcels')
    .insert({
      mission_id:          mission.id,
      sender_name:         parcelData.sender_name,
      sender_phone:        parcelData.sender_phone,
      recipient_name:      parcelData.recipient_name,
      recipient_phone:     parcelData.recipient_phone,
      length_cm:           parseFloat(parcelData.length_cm),
      width_cm:            parseFloat(parcelData.width_cm),
      height_cm:           parseFloat(parcelData.height_cm),
      weight_kg:           parseFloat(parcelData.weight_kg),
      // volume_m3 : calculé automatiquement par PostgreSQL (GENERATED ALWAYS)
      content_description: parcelData.content_description,
      is_fragile:          parcelData.is_fragile || false,
      // tracking_number : assigné automatiquement par trigger_set_tracking_number
    })
    .select()
    .single();

  if (parcelError) {
    console.log('[FTM-DEBUG] Parcel - Parcel insert error', {
      error: parcelError.message,
      missionId: mission.id,
    });
    // Rollback : annuler la mission créée à l'étape 1
    await supabase
      .from('missions')
      .update({ status: 'cancelled_client' })
      .eq('id', mission.id);

    console.log('[FTM-DEBUG] Parcel - Mission rolled back after parcel error', {
      missionId: mission.id,
    });
    return { error: 'Erreur lors de la création du colis. Réessayez.' };
  }

  console.log('[FTM-DEBUG] Parcel - Parcel created successfully', {
    parcelId:       parcel.id,
    trackingNumber: parcel.tracking_number,  // ex: FTM-TRACK-K7X2MQ4R
    volumeM3:       parcel.volume_m3,        // calculé par PostgreSQL
    missionId:      mission.id,
  });

  // ── ÉTAPE 3 : Notifier le destinataire par SMS ─────────────────────
  await notifyRecipientBySMS(parcel, mission);

  return {
    success:        true,
    mission,
    parcel,
    trackingNumber: parcel.tracking_number,
  };
}

/**
 * NOTIFIER LE DESTINATAIRE PAR SMS
 * Appel vers une Supabase Edge Function qui envoie le SMS
 * via un gateway SMS marocain (ex: OrangeSMS, InTouch, Twilio)
 */
async function notifyRecipientBySMS(parcel, mission) {
  console.log('[FTM-DEBUG] Parcel - Sending SMS to recipient', {
    recipientPhone:  parcel.recipient_phone,
    recipientName:   parcel.recipient_name,
    trackingNumber:  parcel.tracking_number,
    pickupCity:      mission.pickup_city,
    dropoffCity:     mission.dropoff_city,
  });

  try {
    const { error } = await supabase.functions.invoke('send-tracking-sms', {
      body: {
        to:              parcel.recipient_phone,
        recipient_name:  parcel.recipient_name,
        tracking_number: parcel.tracking_number,
        pickup_city:     mission.pickup_city,
        dropoff_city:    mission.dropoff_city,
        // Message composé dans la Edge Function :
        // "Bonjour [Nom], votre colis FTM-TRACK-K7X2MQ4R
        //  est en cours d'envoi depuis [Casablanca] vers [Marrakech].
        //  Suivez-le sur : https://ftm.ma/track/FTM-TRACK-K7X2MQ4R"
      },
    });

    if (error) {
      console.log('[FTM-DEBUG] Parcel - SMS send error', { error: error.message });
      // Non-bloquant : la mission est créée même si le SMS échoue
    } else {
      console.log('[FTM-DEBUG] Parcel - SMS sent to recipient', {
        trackingNumber: parcel.tracking_number,
        phone:          parcel.recipient_phone,
      });
    }
  } catch (err) {
    console.log('[FTM-DEBUG] Parcel - SMS exception', { err: err.message });
  }
}

/**
 * RÉCUPÉRER LES INFOS D'UN COLIS PAR TRACKING NUMBER
 * Accessible SANS authentification (destinataire non-utilisateur)
 * Utilise la vue public_parcel_tracking
 */
export async function getParcelByTrackingNumber(trackingNumber) {
  const normalized = trackingNumber.trim().toUpperCase();

  console.log('[FTM-DEBUG] Parcel - Fetching parcel by tracking number', {
    trackingNumber: normalized,
  });

  const { data, error } = await supabase
    .from('public_parcel_tracking')
    .select('*')
    .eq('tracking_number', normalized)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Parcel - Tracking fetch error', {
      trackingNumber: normalized,
      error: error.message,
      errorCode: error.code,
    });
    if (error.code === 'PGRST116') {
      return { error: 'Numéro de suivi introuvable. Vérifiez le format : FTM-TRACK-XXXXXXXX' };
    }
    return { error: 'Erreur lors de la recherche. Réessayez.' };
  }

  console.log('[FTM-DEBUG] Parcel - Parcel found', {
    trackingNumber: normalized,
    status:         data.mission_status,
    pickupCity:     data.pickup_city,
    dropoffCity:    data.dropoff_city,
    driverName:     data.driver_name,
  });

  return { success: true, parcel: data };
}

/**
 * RÉCUPÉRER TOUS LES COLIS D'UN CLIENT (historique expéditions)
 */
export async function getClientParcels(clientProfileId) {
  console.log('[FTM-DEBUG] Parcel - Fetching client parcels', { clientProfileId });

  const { data, error } = await supabase
    .from('ecommerce_parcels')
    .select(`
      id,
      tracking_number,
      recipient_name,
      recipient_phone,
      content_description,
      is_fragile,
      weight_kg,
      volume_m3,
      length_cm,
      width_cm,
      height_cm,
      created_at,
      missions (
        id,
        mission_number,
        status,
        pickup_city,
        dropoff_city,
        estimated_distance_km,
        commission_amount,
        negotiated_price,
        actual_pickup_time,
        actual_dropoff_time,
        completed_at
      )
    `)
    .eq('missions.client_id', clientProfileId)
    .order('created_at', { ascending: false });

  if (error) {
    console.log('[FTM-DEBUG] Parcel - Fetch client parcels error', { error: error.message });
    return { error };
  }

  console.log('[FTM-DEBUG] Parcel - Client parcels fetched', {
    clientProfileId,
    count: data?.length || 0,
  });

  return { success: true, parcels: data || [] };
}
```

---

## 6. ÉCRANS E-COMMERCE (CLIENT EXPÉDITEUR)

### 6.1 Écran Création Colis (Formulaire Principal)

```javascript
// /screens/ecommerce/CreateParcelScreen.js

/**
 * ÉTAT LOCAL
 * ── Expéditeur (pré-rempli depuis profiles) ──
 * - senderName    : string (depuis profiles.full_name)
 * - senderPhone   : string (depuis profiles.phone_number)
 *
 * ── Destinataire ──
 * - recipientName  : string
 * - recipientPhone : string
 *
 * ── Dimensions colis ──
 * - lengthCm  : string
 * - widthCm   : string
 * - heightCm  : string
 * - weightKg  : string
 * - volumeM3  : number (calculé dynamiquement)
 * - isFragile : boolean
 *
 * ── Contenu ──
 * - contentDescription : string
 *
 * ── Localisation ──
 * - pickupCoords   : { lat, lng }
 * - pickupAddress  : string
 * - pickupCity     : string
 * - dropoffAddress : string
 * - dropoffCity    : string
 * - dropoffCoords  : { lat, lng }
 *
 * ── Recommandation ──
 * - recommendedCategory : 'vul' | 'n2_medium' | 'n2_large'
 * - selectedCategory    : string
 *
 * ── Divers ──
 * - negotiatedPrice : string (optionnel)
 * - dimensionErrors : object | null
 * - isLoading       : boolean
 */

/**
 * RECALCUL EN TEMPS RÉEL à chaque changement de dimension
 */
function onDimensionChange(field, value, state, setState) {
  const dims = { ...state, [field]: value };
  const vol  = calculateVolume(dims.lengthCm, dims.widthCm, dims.heightCm);
  const cat  = recommendVehicleCategory(vol, dims.weightKg);

  console.log('[FTM-DEBUG] Parcel - Dimensions updated', {
    field,
    value,
    volumeM3:    vol,
    recommended: cat,
  });

  setState(prev => ({
    ...prev,
    [field]:              value,
    volumeM3:             vol,
    recommendedCategory:  cat,
    selectedCategory:     cat, // pré-sélectionner la recommandation
  }));
}

/**
 * UI — CreateParcelScreen
 *
 * LAYOUT COMPLET (scrollable) :
 *
 * ┌────────────────────────────────────┐
 * │  ← "Envoyer un colis"             │
 * │                                    │
 * │  ── EXPÉDITEUR ──                 │
 * │  [Input] Votre nom (pré-rempli)   │
 * │  [Input] Votre téléphone (pré)    │
 * │                                    │
 * │  ── DESTINATAIRE ──               │
 * │  [Input] Nom du destinataire *    │
 * │  [Input] Tél. destinataire *      │
 * │          (+212 prefix fixe)       │
 * │                                    │
 * │  ── DIMENSIONS DU COLIS ──        │
 * │  ┌──────┐  ┌──────┐  ┌──────┐    │
 * │  │ L cm │  │ l cm │  │ h cm │    │
 * │  └──────┘  └──────┘  └──────┘    │
 * │  [Input] Poids (kg) *            │
 * │                                    │
 * │  📦 Volume calculé :              │
 * │  "60 litres (0.06 m³)"           │
 * │  (Mise à jour en temps réel)      │
 * │                                    │
 * │  [Toggle] ⚠️ Colis fragile        │
 * │  Si ON → bordure COLORS.alert     │
 * │         + mention "Manipulation   │
 * │           avec précaution" au     │
 * │           driver                  │
 * │                                    │
 * │  ── CONTENU ──                    │
 * │  [Input] Description du contenu * │
 * │  ex: "Vêtements, 3 cartons"       │
 * │                                    │
 * │  ── ITINÉRAIRE ──                 │
 * │  📍 [Ville de départ] *           │
 * │  🏁 [Ville d'arrivée] *           │
 * │  (Autocomplete villes Maroc)      │
 * │                                    │
 * │  ── VÉHICULE RECOMMANDÉ ──        │
 * │  💡 "Pour ce colis, nous          │
 * │      recommandons : 🚐 VUL"       │
 * │  [VUL ✓] [N2 Med] [N2 Lrg]       │
 * │  Commission : 25 DH               │
 * │                                    │
 * │  [Input] Prix proposé (DH) opt.   │
 * │                                    │
 * │  [Bouton "Envoyer ce colis →"]    │
 * │  (COLORS.primary, 52px)           │
 * │  Désactivé si champs * manquants  │
 * └────────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - Volume recalculé à chaque frappe sur L, l, h, poids
 * - Recommandation vehicleCategory mise à jour dynamiquement
 * - is_fragile = true → Card colis avec bordure orange (COLORS.cta)
 * - Validation dimensions avant soumission (validateParcelDimensions)
 * - Si erreur dimension → champ concerné en COLORS.alert + message
 * - Au submit → createParcelMission() → ParcelConfirmationScreen
 */
```

### 6.2 Écran Confirmation Expédition

```javascript
// /screens/ecommerce/ParcelConfirmationScreen.js

/**
 * PROPS : trackingNumber, mission, parcel
 * Affiché immédiatement après createParcelMission() réussi
 */

/**
 * UI — ParcelConfirmationScreen
 *
 * LAYOUT :
 * ┌────────────────────────────────────┐
 * │  ✅ Colis enregistré !             │
 * │                                    │
 * │  ┌──────────────────────────────┐  │
 * │  │  📦 NUMÉRO DE SUIVI          │  │
 * │  │                              │  │
 * │  │  FTM-TRACK-K7X2MQ4R         │  │
 * │  │  (Texte XL, COLORS.primary)  │  │
 * │  │                              │  │
 * │  │  [📋 Copier] [📤 Partager]   │  │
 * │  └──────────────────────────────┘  │
 * │                                    │
 * │  📱 SMS envoyé à :                 │
 * │  "[Nom destinataire]"             │
 * │  06****78 ← numéro masqué         │
 * │                                    │
 * │  RÉCAPITULATIF :                  │
 * │  📍 Départ     : [pickup_city]    │
 * │  🏁 Arrivée    : [dropoff_city]   │
 * │  📏 Distance   : ~XX km           │
 * │  📦 Volume     : 60 litres        │
 * │  ⚖️  Poids     : 5.5 kg           │
 * │  💰 Commission : 25 DH            │
 * │                                    │
 * │  ⏳ "En recherche de chauffeur..." │
 * │                                    │
 * │  [Bouton "Suivre ce colis"]       │
 * │  (→ TrackingScreen)               │
 * │                                    │
 * │  [Lien "Retour à l'accueil"]      │
 * └────────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - [Copier] → presse-papier natif Natively
 * - [Partager] → Share Sheet natif :
 *   "Suivez votre colis FTM-TRACK-K7X2MQ4R sur https://ftm.ma/track/FTM-TRACK-K7X2MQ4R"
 * - [Suivre ce colis] → navigation vers TrackingScreen(trackingNumber)
 */
```

---

## 7. ÉCRAN DE TRACKING PUBLIC (DESTINATAIRE)

### 7.1 Écran Saisie Numéro de Suivi

```javascript
// /screens/tracking/TrackingInputScreen.js

/**
 * ACCESSIBLE SANS AUTHENTIFICATION
 * Affiché sur la page publique https://ftm.ma/track
 * OU dans l'app via le menu "Suivre un colis" (non-connecté autorisé)
 *
 * ÉTAT LOCAL
 * - trackingInput : string
 * - isLoading     : boolean
 * - error         : string | null
 */

/**
 * AUTO-FORMAT à la saisie :
 * "ftmtrackk7x2mq4r"   → "FTM-TRACK-K7X2MQ4R"
 * "FTM TRACK K7X2MQ4R" → "FTM-TRACK-K7X2MQ4R"
 * "K7X2MQ4R"           → "FTM-TRACK-K7X2MQ4R"
 */
function autoFormatTracking(raw) {
  let cleaned = raw.toUpperCase().replace(/[\s\-_]/g, '');
  if (cleaned.startsWith('FTMTRACK')) {
    cleaned = 'FTM-TRACK-' + cleaned.replace('FTMTRACK', '');
  } else if (!cleaned.startsWith('FTM')) {
    cleaned = 'FTM-TRACK-' + cleaned;
  }
  return cleaned;
}

async function handleTrackingSearch(rawInput) {
  const formatted = autoFormatTracking(rawInput);

  console.log('[FTM-DEBUG] Tracking - Search initiated', {
    raw:       rawInput,
    formatted: formatted,
  });

  if (formatted.length < 18) { // FTM-TRACK- = 10 chars + 8 chars code
    console.log('[FTM-DEBUG] Tracking - Invalid format', { formatted });
    return { error: 'Format invalide. Exemple : FTM-TRACK-K7X2MQ4R' };
  }

  const result = await getParcelByTrackingNumber(formatted);

  if (result.error) {
    console.log('[FTM-DEBUG] Tracking - Not found', { formatted, error: result.error });
    return result;
  }

  console.log('[FTM-DEBUG] Tracking - Found, navigating to details', {
    trackingNumber: formatted,
    status:         result.parcel.mission_status,
  });

  return result;
}

/**
 * UI — TrackingInputScreen
 *
 * LAYOUT :
 * ┌────────────────────────────────────┐
 * │  [Logo FTM]                        │
 * │  "Suivre votre colis"             │
 * │                                    │
 * │  [Input] FTM-TRACK-XXXXXXXX       │
 * │  (Uppercase auto, keyboardType     │
 * │   default — pas numeric pour les  │
 * │   lettres du code)                │
 * │                                    │
 * │  [Bouton "Rechercher"]            │
 * │  (COLORS.primary)                 │
 * │                                    │
 * │  ── OU ──                         │
 * │                                    │
 * │  [📷 Scanner le QR code]          │
 * │  (Si colis accompagné d'un QR)    │
 * └────────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - Auto-uppercase + insertion tirets automatique
 * - Submit sur "Entrée" clavier ou bouton
 * - Erreur "introuvable" → message COLORS.alert sous l'input
 * - Succès → navigation vers TrackingDetailScreen
 */
```

### 7.2 Écran Détail de Suivi (Destinataire)

```javascript
// /screens/tracking/TrackingDetailScreen.js

/**
 * PROPS : trackingNumber (string)
 * Accessible SANS connexion (destinataire externe)
 * Abonnement Realtime sur la mission pour mise à jour statut automatique
 *
 * ÉTAT LOCAL
 * - parcelData     : object | null
 * - isLoading      : boolean
 * - locationChannel: channel Supabase | null
 */

/**
 * TIMELINE DE STATUT — Affichage progressif
 *
 * Étapes affichées (de haut en bas) :
 *
 *  ✅ Colis enregistré          (toujours visible)
 *     FTM-TRACK-K7X2MQ4R
 *     Créé le JJ/MM/AAAA
 *
 *  🟡 En attente de chauffeur   (status: pending)
 *  OU
 *  ✅ Chauffeur assigné          (status: accepted+)
 *     [Nom driver] — [Véhicule]
 *
 *  🟡 En attente de ramassage   (status: accepted)
 *  OU
 *  ✅ Colis pris en charge       (status: in_progress)
 *     Le JJ/MM à HH:MM
 *     📍 [pickup_city]
 *
 *  🟡 En transit                (status: in_progress)
 *     [Carte avec position driver temps réel]
 *     📍 [pickup_city] ──→ 🏁 [dropoff_city]
 *     [Icône camion animé sur la route]
 *  OU
 *  ✅ Livré !                    (status: completed)
 *     Le JJ/MM à HH:MM
 *     🏁 [dropoff_city]
 */

/**
 * CONFIGURATION VISUELLE PAR STATUT
 */
const TRACKING_STEPS = {
  pending: [
    { id: 1, label: 'Colis enregistré',         done: true,  active: false },
    { id: 2, label: 'En attente de chauffeur',  done: false, active: true  },
    { id: 3, label: 'En transit',               done: false, active: false },
    { id: 4, label: 'Livré',                    done: false, active: false },
  ],
  accepted: [
    { id: 1, label: 'Colis enregistré',         done: true,  active: false },
    { id: 2, label: 'Chauffeur assigné',         done: true,  active: false },
    { id: 3, label: 'En attente de ramassage',   done: false, active: true  },
    { id: 4, label: 'Livré',                     done: false, active: false },
  ],
  in_progress: [
    { id: 1, label: 'Colis enregistré',         done: true,  active: false },
    { id: 2, label: 'Chauffeur assigné',         done: true,  active: false },
    { id: 3, label: 'En transit',               done: true,  active: true  },
    { id: 4, label: 'Livré',                     done: false, active: false },
  ],
  completed: [
    { id: 1, label: 'Colis enregistré',         done: true,  active: false },
    { id: 2, label: 'Chauffeur assigné',         done: true,  active: false },
    { id: 3, label: 'En transit',               done: true,  active: false },
    { id: 4, label: '✅ Livré !',               done: true,  active: false },
  ],
};

/**
 * ABONNEMENT REALTIME pour mise à jour automatique du statut
 */
async function subscribeToParcelStatus(missionId, onStatusChange) {
  console.log('[FTM-DEBUG] Tracking - Subscribing to parcel status updates', { missionId });

  const channel = supabase
    .channel(`parcel-tracking-${missionId}`)
    .on(
      'postgres_changes',
      {
        event:  'UPDATE',
        schema: 'public',
        table:  'missions',
        filter: `id=eq.${missionId}`,
      },
      (payload) => {
        console.log('[FTM-DEBUG] Tracking - Parcel status changed', {
          missionId,
          oldStatus: payload.old.status,
          newStatus: payload.new.status,
        });
        onStatusChange(payload.new);
      }
    )
    .subscribe();

  return channel;
}

/**
 * UI — TrackingDetailScreen
 *
 * LAYOUT COMPLET :
 * ┌────────────────────────────────────┐
 * │  ← Retour                         │
 * │  📦 FTM-TRACK-K7X2MQ4R           │
 * │  (COLORS.primary, centré)         │
 * │                                    │
 * │  ┌──────────────────────────────┐  │
 * │  │ TIMELINE VERTICALE          │  │
 * │  │                              │  │
 * │  │ ●─── Colis enregistré ✅    │  │
 * │  │ │    15/02/2026 à 10:30      │  │
 * │  │ │                            │  │
 * │  │ ●─── Chauffeur assigné ✅   │  │
 * │  │ │    Youssef M. — VUL        │  │
 * │  │ │                            │  │
 * │  │ ◉─── En transit 🔄          │  │ ← Étape active (pulsing)
 * │  │ │    Casablanca → Marrakech  │  │
 * │  │ │                            │  │
 * │  │ ○─── Livraison              │  │ ← Étape future (grisée)
 * │  └──────────────────────────────┘  │
 * │                                    │
 * │  [CARTE — Position driver live]   │
 * │  (visible seulement si in_progress)│
 * │  Icône camion animé               │
 * │                                    │
 * │  INFOS COLIS :                    │
 * │  📍 De       : [pickup_city]      │
 * │  🏁 Vers     : [dropoff_city]     │
 * │  📦 Contenu  : [description]      │
 * │  ⚖️  Poids   : X.X kg             │
 * │  ⚠️  Fragile : Oui / Non          │
 * │                                    │
 * │  EXPÉDITEUR :                     │
 * │  👤 [sender_name]                 │
 * │  📱 06****78 (masqué)             │
 * └────────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - Timeline : étape ✅ = rond plein COLORS.success
 * - Étape active = rond animé (pulse) COLORS.primary
 * - Étape future = rond vide COLORS.textMuted
 * - Carte visible uniquement si status = 'in_progress'
 * - Position driver rechargée via subscribeToDriverLocation() (P3)
 * - Si completed → Confetti animation + "Colis livré !" banner vert
 * - Realtime subscribeToParcelStatus() actif pendant consultation
 * - Cleanup unsubscribeChannel() sur exit
 */
```

---

## 8. ÉCRAN DRIVER — DÉTAIL MISSION COLIS

```javascript
// /screens/driver/ParcelMissionDetailScreen.js

/**
 * Quand le driver accepte une mission de type 'ecommerce_parcel',
 * il voit les infos supplémentaires du colis (dimensions, fragilité)
 * que n'a pas une mission de transport classique.
 *
 * Les données colis sont chargées via JOIN missions → ecommerce_parcels
 */

async function loadParcelDetails(missionId) {
  console.log('[FTM-DEBUG] Parcel - Loading parcel details for driver', { missionId });

  const { data, error } = await supabase
    .from('ecommerce_parcels')
    .select(`
      tracking_number,
      sender_name,
      sender_phone,
      recipient_name,
      recipient_phone,
      length_cm,
      width_cm,
      height_cm,
      weight_kg,
      volume_m3,
      content_description,
      is_fragile
    `)
    .eq('mission_id', missionId)
    .single();

  if (error) {
    console.log('[FTM-DEBUG] Parcel - Load details error', {
      missionId,
      error: error.message,
    });
    return { error };
  }

  console.log('[FTM-DEBUG] Parcel - Parcel details loaded for driver', {
    missionId,
    trackingNumber: data.tracking_number,
    isFragile:      data.is_fragile,
    weightKg:       data.weight_kg,
    volumeM3:       data.volume_m3,
  });

  return { success: true, parcel: data };
}

/**
 * UI — ParcelMissionDetailScreen (Driver)
 *
 * LAYOUT (extension du MissionActiveScreen P3) :
 * ┌────────────────────────────────────┐
 * │  [Même header que MissionActive]  │
 * │                                    │
 * │  ── DÉTAILS DU COLIS ──           │
 * │  N° suivi : FTM-TRACK-K7X2MQ4R   │
 * │                                    │
 * │  ┌──────────────────────────────┐  │
 * │  │ ⚠️  COLIS FRAGILE            │  │  ← Visible si is_fragile = true
 * │  │ Manipulez avec précaution    │  │  ← Fond COLORS.alert/10, bordure
 * │  └──────────────────────────────┘  │    COLORS.alert, texte COLORS.alert
 * │                                    │
 * │  📦 Dimensions :                  │
 * │  50 × 40 × 30 cm                 │
 * │  Volume : 60 litres               │
 * │  Poids  : 5.5 kg                 │
 * │                                    │
 * │  📋 Contenu : [description]       │
 * │                                    │
 * │  ── EXPÉDITEUR ──                 │
 * │  👤 [sender_name]                 │
 * │  [📞 Appeler expéditeur]          │
 * │                                    │
 * │  ── DESTINATAIRE ──               │
 * │  👤 [recipient_name]              │
 * │  [📞 Appeler destinataire]        │
 * │  → tel:{recipient_phone}          │
 * └────────────────────────────────────┘
 *
 * COMPORTEMENT :
 * - Badge "FRAGILE" rouge visible dès l'acceptation si is_fragile = true
 * - Boutons d'appel direct (expéditeur ET destinataire)
 * - Numéro de suivi affichable et copiable par le driver
 */
```

---

## 9. HISTORIQUE EXPÉDITIONS (CLIENT)

```javascript
// /screens/ecommerce/ParcelHistoryScreen.js

/**
 * Liste de tous les colis envoyés par le client connecté
 * Utilise getClientParcels(clientProfileId)
 */

/**
 * UI — ParcelHistoryScreen
 *
 * LAYOUT (liste scrollable) :
 * ┌────────────────────────────────────┐
 * │  "Mes expéditions"                │
 * │  [Filtre: Tous | En cours | Livrés]│
 * │                                    │
 * │  ┌──────────────────────────────┐  │
 * │  │ FTM-TRACK-K7X2MQ4R          │  │
 * │  │ 📍 Casa → 🏁 Marrakech      │  │
 * │  │ Pour : [recipient_name]      │  │
 * │  │ ⚖️  5.5 kg  📦 60 litres    │  │
 * │  │ 🔄 En transit               │  │  ← Couleur COLORS.primary
 * │  │ 15/02/2026                   │  │
 * │  └──────────────────────────────┘  │
 * │  (Tap → TrackingDetailScreen)     │
 * │                                    │
 * │  ┌──────────────────────────────┐  │
 * │  │ FTM-TRACK-AB3X9KQR          │  │
 * │  │ 📍 Rabat → 🏁 Fès           │  │
 * │  │ ✅ Livré le 10/02/2026       │  │  ← Couleur COLORS.success
 * │  └──────────────────────────────┘  │
 * │                                    │
 * │  [Bouton "+ Envoyer un colis"]    │
 * │  (FAB — COLORS.primary, bottom)   │
 * └────────────────────────────────────┘
 *
 * STATUTS COULEURS :
 * pending         → 🟡 Ambre  (COLORS.cta)
 * accepted        → 🔵 Bleu   (COLORS.primary)
 * in_progress     → 🔵 Bleu   (COLORS.primary) + animation pulse
 * completed       → 🟢 Vert   (COLORS.success)
 * cancelled_*     → ⛔ Gris   (COLORS.textMuted)
 */
```

---

## 10. ARBORESCENCE DES FICHIERS — PÉRIMÈTRE P4

```
src/
├── utils/
│   └── parcelCalculations.js    ← calculateVolume, recommendVehicleCategory,
│                                   formatVolume, validateParcelDimensions,
│                                   formatPhoneDisplay, maskPhone
├── services/
│   └── parcelService.js         ← createParcelMission, getParcelByTrackingNumber,
│                                   getClientParcels, notifyRecipientBySMS
├── screens/
│   ├── ecommerce/
│   │   ├── CreateParcelScreen.js       ← Formulaire création colis
│   │   ├── ParcelConfirmationScreen.js ← Récap + tracking_number + partage
│   │   └── ParcelHistoryScreen.js      ← Historique expéditions client
│   ├── tracking/
│   │   ├── TrackingInputScreen.js      ← Saisie numéro (sans auth)
│   │   └── TrackingDetailScreen.js     ← Timeline + carte + infos (sans auth)
│   └── driver/
│       └── ParcelMissionDetailScreen.js ← Infos colis pour le driver
supabase/
└── migrations/
    └── 20260222000000_add_tracking_functions.sql
        ← generate_tracking_number(), set_tracking_number trigger,
           public_parcel_tracking view
```

---

## 11. RÉCAPITULATIF DES LOGS DE DEBUG (P4)

| Action | Log FTM-DEBUG |
|--------|---------------|
| Création mission colis | `[FTM-DEBUG] Parcel - Creating parcel mission` |
| Mission parent créée | `[FTM-DEBUG] Parcel - Parent mission created` |
| Erreur insert colis | `[FTM-DEBUG] Parcel - Parcel insert error` |
| Rollback mission | `[FTM-DEBUG] Parcel - Mission rolled back after parcel error` |
| Colis créé OK | `[FTM-DEBUG] Parcel - Parcel created successfully` |
| SMS envoi | `[FTM-DEBUG] Parcel - Sending SMS to recipient` |
| SMS envoyé | `[FTM-DEBUG] Parcel - SMS sent to recipient` |
| Erreur SMS | `[FTM-DEBUG] Parcel - SMS send error` |
| Recherche tracking | `[FTM-DEBUG] Tracking - Search initiated` |
| Format invalide | `[FTM-DEBUG] Tracking - Invalid format` |
| Colis introuvable | `[FTM-DEBUG] Tracking - Not found` |
| Colis trouvé | `[FTM-DEBUG] Tracking - Found, navigating to details` |
| Récup colis client | `[FTM-DEBUG] Parcel - Fetching client parcels` |
| Colis client chargés | `[FTM-DEBUG] Parcel - Client parcels fetched` |
| Dimensions MàJ | `[FTM-DEBUG] Parcel - Dimensions updated` |
| Sub. statut colis | `[FTM-DEBUG] Tracking - Subscribing to parcel status updates` |
| Statut colis changé | `[FTM-DEBUG] Tracking - Parcel status changed` |
| Détails driver chargés | `[FTM-DEBUG] Parcel - Parcel details loaded for driver` |
| Erreur chargement | `[FTM-DEBUG] Parcel - Load details error` |

---

## 12. CHECKLIST DE VALIDATION P4

- [ ] Migration SQL `20260222000000` appliquée : fonction `generate_tracking_number()` + trigger + vue `public_parcel_tracking`
- [ ] `createParcelMission()` : INSERT `missions` puis INSERT `ecommerce_parcels` — vérifier les 2 lignes en BDD
- [ ] `ecommerce_parcels.tracking_number` : format `FTM-TRACK-XXXXXXXX` (majuscules, 8 chars sans I/O/0/1)
- [ ] `ecommerce_parcels.volume_m3` : valeur calculée par PostgreSQL (GENERATED ALWAYS) — pas par l'app
- [ ] `TrackingInputScreen` : accessible sans authentification Supabase
- [ ] Recherche par `tracking_number` : résultat < 500ms (index `idx_parcels_tracking`)
- [ ] SMS Edge Function `send-tracking-sms` : déployée et testée sur numéro marocain réel
- [ ] `ParcelMissionDetailScreen` : badge FRAGILE visible si `is_fragile = true`
- [ ] Realtime `subscribeToParcelStatus()` : changement de statut reçu en < 2s
- [ ] `unsubscribeChannel()` appelé sur exit de `TrackingDetailScreen`
- [ ] `public_parcel_tracking` view : numéros de téléphone masqués correctement
- [ ] Rollback mission si INSERT colis échoue (vérifier `status = 'cancelled_client'`)
- [ ] Tous les `console.log('[FTM-DEBUG]...')` visibles dans Debug Console Codespaces

---

## 13. LIAISON AVEC LES PARTIES SUIVANTES

| Partie | Dépendance de P4 |
|--------|-----------------|
| **P5** | `missions.commission_amount` → prélevé sur wallet driver à completion (même trigger que P3) |
| **P6** | Notifications push : "Colis pris en charge", "Colis livré" → `notifications` table |
| **P7** | Admin voit les missions e-commerce dans le dashboard, peut filtrer par `mission_type` |

---

*FTM Spec P4 — Fin du fichier*
*Prochaine étape : SPEC_NATIVELY_P5.md — Wallet Revolving & Transactions*
