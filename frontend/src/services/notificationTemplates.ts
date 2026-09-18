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
  offer_update:       '💰',
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

// ─── MISSION OFFERS ────────────────────────────────────────────────────────────

export async function notifyClientOfferUpdate(
  clientProfileId: string,
  mission: { id: string; mission_number: string },
  driverName: string,
  offeredPrice: number,
  roundNumber: 1 | 2
) {
  console.log('[FTM-DEBUG] Push - Notify client offer update', {
    clientProfileId, missionId: mission.id, driverName, offeredPrice, roundNumber,
  });
  const title = roundNumber === 1 ? '💰 Nouvelle offre de prix' : '💰 Réponse du chauffeur';
  return insertNotification(
    clientProfileId,
    'offer_update',
    title,
    `${driverName} propose ${offeredPrice} DH pour la mission ${mission.mission_number}.`,
    { mission_id: mission.id, offered_price: offeredPrice, screen: 'MissionOfferScreen' }
  );
}

export async function notifyDriverCounterOffer(
  driverProfileId: string,
  mission: { id: string; mission_number: string },
  newPrice: number
) {
  console.log('[FTM-DEBUG] Push - Notify driver counter offer', {
    driverProfileId, missionId: mission.id, newPrice,
  });
  return insertNotification(
    driverProfileId,
    'offer_update',
    '💰 Contre-offre du client',
    `Le client propose ${newPrice} DH pour la mission ${mission.mission_number}.`,
    { mission_id: mission.id, offered_price: newPrice, screen: 'MissionOfferScreen' }
  );
}

export async function notifyOfferAcceptancePending(
  recipientProfileId: string,
  mission: { id: string; mission_number: string },
  offeredPrice: number
) {
  console.log('[FTM-DEBUG] Push - Notify offer acceptance pending', {
    recipientProfileId, missionId: mission.id, offeredPrice,
  });
  return insertNotification(
    recipientProfileId,
    'offer_update',
    '✅ Confirmation attendue',
    `L'autre partie a accepté ${offeredPrice} DH pour la mission ${mission.mission_number}. Confirmez pour conclure.`,
    { mission_id: mission.id, offered_price: offeredPrice, screen: 'MissionOfferScreen' }
  );
}

export async function notifyDriverOfferNotSelected(
  driverProfileId: string,
  mission: { id: string; mission_number: string }
) {
  console.log('[FTM-DEBUG] Push - Notify driver offer not selected', {
    driverProfileId, missionId: mission.id,
  });
  return insertNotification(
    driverProfileId,
    'offer_update',
    'ℹ️ Offre non retenue',
    `Un autre chauffeur a été retenu pour la mission ${mission.mission_number}.`,
    { mission_id: mission.id, screen: 'DriverHomeScreen' }
  );
}

// ─── CANAL VOCAL ───────────────────────────────────────────────────────────────

export async function notifyVoiceChannelOpened(
  recipientProfileId: string,
  mission: { id: string; mission_number: string; scheduled_pickup_time: string }
) {
  console.log('[FTM-DEBUG] Push - Notify voice channel opened', {
    recipientProfileId, missionId: mission.id,
  });
  return insertNotification(
    recipientProfileId,
    'voice_channel_opened',
    '🎤 Messagerie vocale disponible',
    `Votre mission ${mission.mission_number} approche. Vous pouvez désormais échanger des messages vocaux.`,
    { mission_id: mission.id, screen: 'VoiceChat' }
  );
}

export async function notifyDriverLowBalance(driverProfileId: string, balance: number, minimum: number) {
  const deficit = (minimum - balance).toFixed(2);
  console.log('[FTM-DEBUG] Push - Notify driver low balance', { driverProfileId, balance, minimum });
  return insertNotification(
    driverProfileId,
    'wallet_low_balance',
    '\u26a0\ufe0f Wallet insuffisant',
    `Votre solde (${balance.toFixed(2)} DH) est insuffisant. Rechargez au moins ${minimum.toFixed(2)} DH (deficit: ${deficit} DH) pour continuer a recevoir des missions.`,
    { balance, minimum, screen: 'WalletDashboard' }
  );
}

export async function notifyTransactionValidated(
  driverProfileId: string,
  transactionType: string,
  amount: number
) {
  const label = transactionType === 'refund' ? 'Remboursement' : 'Recharge';
  console.log('[FTM-DEBUG] Push - Notify transaction validated', { driverProfileId, transactionType, amount });
  return insertNotification(
    driverProfileId,
    'transaction_validated',
    '\u2705 Demande validee',
    `${label} de ${amount.toFixed(2)} DH validee. Votre solde a ete mis a jour.`,
    { amount, transactionType, screen: 'WalletDashboard' }
  );
}

export async function notifyTransactionRejected(
  driverProfileId: string,
  transactionType: string,
  amount: number,
  reason: string
) {
  const label = transactionType === 'refund' ? 'Remboursement' : 'Recharge';
  console.log('[FTM-DEBUG] Push - Notify transaction rejected', { driverProfileId, transactionType, amount, reason });
  return insertNotification(
    driverProfileId,
    'transaction_rejected',
    '\u274c Demande rejetee',
    `${label} de ${amount.toFixed(2)} DH rejetee. Motif : ${reason}`,
    { amount, transactionType, screen: 'WalletDashboard' }
  );
}

export async function notifyTransactionBankConfirmed(
  driverProfileId: string,
  transactionType: string,
  amount: number
) {
  const label = transactionType === 'refund' ? 'Remboursement' : 'Recharge';
  console.log('[FTM-DEBUG] Push - Notify transaction bank confirmed', { driverProfileId, transactionType, amount });
  return insertNotification(
    driverProfileId,
    'transaction_bank_confirmed',
    '\u2705 Paiement confirme',
    `${label} de ${amount.toFixed(2)} DH definitivement confirmee apres verification bancaire.`,
    { amount, transactionType, screen: 'WalletDashboard' }
  );
}
