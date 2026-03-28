import { insertNotification } from './pushNotificationService';

export const NOTIF_ICONS: Record<string, string> = {
  new_mission:        '🚚',
  mission_accepted:   '✅',
  mission_started:    '🚛',
  mission_completed:  '🏁',
  mission_cancelled:  '❌',
  wallet_low_balance: '💸',
  document_expiry:    '⚠️',
  document_rejected:  '❌',
  document_verified:  '✅',
  parcel_status:      '📦',
};

// ─── MISSIONS ──────────────────────────────────────────────────────────────────

export async function notifyNewMission(
  driverProfileId: string,
  mission: { id: string; mission_number: string; pickup_city: string; dropoff_city: string; commission_amount: number }
) {
  console.log('[FTM-DEBUG] Push - Notify new mission', {
    driverProfileId,
    missionId:     mission.id,
    missionNumber: mission.mission_number,
  });
  return insertNotification(
    driverProfileId,
    'new_mission',
    '🚚 Nouvelle mission disponible !',
    `${mission.pickup_city} → ${mission.dropoff_city} | Commission : ${mission.commission_amount} DH`,
    { mission_id: mission.id, mission_number: mission.mission_number, screen: 'NewMissionModal' }
  );
}

export async function notifyMissionAccepted(
  clientProfileId: string,
  mission: { id: string; mission_number: string },
  driverName: string
) {
  console.log('[FTM-DEBUG] Push - Notify mission accepted', {
    clientProfileId, missionId: mission.id, driverName,
  });
  return insertNotification(
    clientProfileId,
    'mission_accepted',
    '✅ Chauffeur trouvé !',
    `${driverName} a accepté votre mission ${mission.mission_number}. Il arrive bientôt.`,
    { mission_id: mission.id, screen: 'MissionTrackingScreen' }
  );
}

export async function notifyMissionStarted(
  clientProfileId: string,
  mission: { id: string; mission_number: string; dropoff_city: string }
) {
  console.log('[FTM-DEBUG] Push - Notify mission started', {
    clientProfileId, missionId: mission.id,
  });
  return insertNotification(
    clientProfileId,
    'mission_started',
    '🚛 Chargement en cours',
    `Votre mission ${mission.mission_number} a démarré. Trajet en cours vers ${mission.dropoff_city}.`,
    { mission_id: mission.id, screen: 'MissionTrackingScreen' }
  );
}

export async function notifyMissionCompleted(
  clientProfileId: string,
  driverProfileId: string,
  mission: { id: string; mission_number: string; dropoff_city: string; commission_amount: number }
) {
  console.log('[FTM-DEBUG] Push - Notify mission completed', {
    clientProfileId, driverProfileId, missionId: mission.id,
  });
  await insertNotification(
    clientProfileId,
    'mission_completed',
    '🏁 Mission terminée !',
    `Mission ${mission.mission_number} livrée à ${mission.dropoff_city}. Évaluez votre chauffeur.`,
    { mission_id: mission.id, screen: 'RatingScreen' }
  );
  return insertNotification(
    driverProfileId,
    'mission_completed',
    '💰 Commission prélevée',
    `Mission ${mission.mission_number} clôturée. Commission de ${mission.commission_amount} DH déduite.`,
    { mission_id: mission.id, screen: 'WalletDashboardScreen' }
  );
}

export async function notifyMissionCancelled(
  profileId: string,
  mission: { id: string; mission_number: string },
  cancelledBy: 'client' | 'driver'
) {
  const byLabel = cancelledBy === 'client' ? 'le client' : 'le chauffeur';
  console.log('[FTM-DEBUG] Push - Notify mission cancelled', {
    profileId, missionId: mission.id, cancelledBy,
  });
  return insertNotification(
    profileId,
    'mission_cancelled',
    '❌ Mission annulée',
    `La mission ${mission.mission_number} a été annulée par ${byLabel}.`,
    { mission_id: mission.id, screen: 'ClientHomeStack' }
  );
}

// ─── DOCUMENTS ─────────────────────────────────────────────────────────────────

const DOC_LABELS: Record<string, string> = {
  driver_license:       'Permis de conduire',
  vehicle_registration: 'Carte grise',
  insurance:            'Assurance',
  technical_inspection: 'Visite technique',
};

export async function notifyDocumentExpiry(
  driverProfileId: string,
  documentType: string,
  expiryDate: string,
  daysLeft: number
) {
  const docLabel = DOC_LABELS[documentType] || documentType;
  const urgency  = daysLeft <= 7 ? '🔴 URGENT — ' : daysLeft <= 15 ? '🟠 ' : '🟡 ';

  console.log('[FTM-DEBUG] Push - Notify document expiry', {
    driverProfileId, documentType, expiryDate, daysLeft,
  });

  return insertNotification(
    driverProfileId,
    'document_expiry',
    `${urgency}${docLabel} expire dans ${daysLeft} jours`,
    `Votre ${docLabel} expire le ${expiryDate}. Renouvelez-le pour rester actif sur FTM.`,
    { document_type: documentType, expiry_date: expiryDate, days_left: daysLeft, screen: 'DocumentStatusScreen' }
  );
}

export async function notifyDocumentVerified(driverProfileId: string, documentType: string) {
  console.log('[FTM-DEBUG] Push - Notify document verified', { driverProfileId, documentType });
  return insertNotification(
    driverProfileId,
    'document_verified',
    '✅ Document validé',
    `Votre ${DOC_LABELS[documentType] || documentType} a été approuvé. Continuez à accepter des missions.`,
    { document_type: documentType, screen: 'DocumentStatusScreen' }
  );
}

export async function notifyDocumentRejected(
  driverProfileId: string,
  documentType: string,
  reason: string
) {
  console.log('[FTM-DEBUG] Push - Notify document rejected', {
    driverProfileId, documentType, reason,
  });
  return insertNotification(
    driverProfileId,
    'document_rejected',
    '❌ Document refusé — Action requise',
    `Votre ${DOC_LABELS[documentType] || documentType} a été refusé : "${reason}". Re-uploadez un document valide.`,
    { document_type: documentType, reason, screen: 'DocumentStatusScreen' }
  );
}
