// /screens/driver/DocumentStatusScreen.tsx
// Fast Trans Maroc — P2 — Suivi vérifications post-onboarding
// Volet 4b-5 : saisie de la nouvelle date à chaque remplacement, remplacement
// possible quel que soit le statut (renouvellement anticipé), affichage de la
// carte grise (expiration + 1re mise en circulation), erreurs visibles.
// C.1.2 : bloc « Mon véhicule » + changement de véhicule (même saisie qu'à
// l'inscription, étape 1) ; tout changement est revalidé par l'administrateur.

import React, { useEffect, useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, ScrollView,
  StyleSheet, Linking, ActivityIndicator, Alert, Platform,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { supabase } from '../../lib/supabaseClient';
import {
  DOCUMENT_LABELS, DOCUMENT_TYPES, DocumentType,
  uploadDocument, saveDocumentReplacement,
  pickDocument, pickImageFromCamera,
  saveVehicleChange, VehicleChangeInput, VehicleCategoryCode,
} from '../../services/documentService';
import DateOnlyField, { todayIsoDate, formatIsoDateFr } from '../../components/DateOnlyField';
import { COLORS } from '../../constants/theme';

type VerificationStatus = 'pending' | 'verified' | 'rejected' | 'expired';

interface DocInfo {
  docType:           DocumentType;
  number?:           string;
  expiry?:           string;
  firstServiceDate?: string;
  status:            VerificationStatus;
  url?:              string;
}

type Props = {
  navigation: NativeStackNavigationProp<any>;
};

interface VehicleInfo {
  vehicle_category:    VehicleCategoryCode;
  vehicle_brand:       string | null;
  vehicle_model:       string | null;
  license_plate:       string;
  vehicle_capacity_kg: number | null;
}

// Mêmes catégories et même contrôle de plaque qu'à l'inscription (étape 1)
const VEHICLE_CATEGORIES: { value: VehicleCategoryCode; label: string; description: string; icon: string }[] = [
  { value: 'vul',       label: 'VUL',      description: '≤ 3,5 tonnes',     icon: '🚐' },
  { value: 'n2_medium', label: 'N2 Moyen', description: '3,5 – 7,5 tonnes', icon: '🚛' },
  { value: 'n2_large',  label: 'N2 Grand', description: '7,5 – 12 tonnes',  icon: '🚚' },
];

const LICENSE_PLATE_REGEX = /^[0-9]{1,6}-[A-Z]-[0-9]+$/;

const VEHICLE_CHANGE_WARNING =
  "Votre carte grise repassera en attente et vous serez indisponible jusqu'à " +
  "la validation de l'administrateur. Pensez à remplacer aussi la carte grise, " +
  "l'assurance et la visite technique du nouveau véhicule. Continuer ?";

function categoryLabel(code: string | null | undefined): string {
  const cat = VEHICLE_CATEGORIES.find(c => c.value === code);
  return cat ? `${cat.icon} ${cat.label} (${cat.description})` : (code ?? '');
}

const TECHNICAL_INSPECTION_HINT =
  "NB : véhicule de moins de 5 ans — indiquez la date à laquelle la visite " +
  "technique deviendra obligatoire (date de 1re mise en circulation + 5 ans) " +
  "et joignez une copie de la carte grise.";

const REPLACE_VALID_WARNING =
  "Ce document sera revérifié par l'administrateur. Vous serez indisponible " +
  "jusqu'à sa validation. Continuer ?";

function statusConfig(s: VerificationStatus) {
  switch (s) {
    case 'verified': return { label: 'Vérifié',    color: '#28A745', icon: '✅' };
    case 'rejected': return { label: 'Refusé',     color: '#DC3545', icon: '❌' };
    case 'expired':  return { label: 'Expiré',     color: '#DC3545', icon: '⚠️' };
    default:         return { label: 'En attente', color: '#F39C12', icon: '🟡' };
  }
}

function showMessage(title: string, message: string) {
  if (Platform.OS === 'web') {
    window.alert(`${title}\n\n${message}`);
  } else {
    Alert.alert(title, message);
  }
}

function askConfirmation(message: string): Promise<boolean> {
  if (Platform.OS === 'web') {
    return Promise.resolve(window.confirm(message));
  }
  return new Promise(resolve => {
    Alert.alert('Confirmation', message, [
      { text: 'Annuler',   style: 'cancel', onPress: () => resolve(false) },
      { text: 'Continuer', onPress: () => resolve(true) },
    ]);
  });
}

export default function DocumentStatusScreen({ navigation }: Props) {
  const [docs,      setDocs]      = useState<DocInfo[]>([]);
  const [driverId,  setDriverId]  = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [uploading, setUploading] = useState<DocumentType | null>(null);

  // Formulaire de remplacement (un seul document à la fois)
  const [editing,           setEditing]           = useState<DocumentType | null>(null);
  const [draftExpiry,       setDraftExpiry]       = useState<string | null>(null);
  const [draftFirstService, setDraftFirstService] = useState<string | null>(null);
  const [formError,         setFormError]         = useState<string | null>(null);

  // Véhicule (C.1.2)
  const [vehicle,        setVehicle]        = useState<VehicleInfo | null>(null);
  const [editingVehicle, setEditingVehicle] = useState(false);
  const [savingVehicle,  setSavingVehicle]  = useState(false);
  const [vCategory,      setVCategory]      = useState<VehicleCategoryCode | null>(null);
  const [vBrand,         setVBrand]         = useState('');
  const [vModel,         setVModel]         = useState('');
  const [vPlate,         setVPlate]         = useState('');
  const [vCapacity,      setVCapacity]      = useState('');
  const [vehicleError,   setVehicleError]   = useState<string | null>(null);

  useEffect(() => {
    loadDriver();
  }, []);

  async function loadDriver() {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    const { data: driver } = await supabase
      .from('drivers')
      .select(`
        id,
        vehicle_category, vehicle_brand, vehicle_model, license_plate, vehicle_capacity_kg,
        driver_license_number, driver_license_expiry, driver_license_verified, driver_license_url,
        vehicle_registration_number, vehicle_registration_expiry, vehicle_first_service_date,
        vehicle_registration_verified, vehicle_registration_url,
        insurance_number, insurance_expiry, insurance_verified, insurance_url,
        technical_inspection_expiry, technical_inspection_verified, technical_inspection_url
      `)
      .eq('profile_id', (
        await supabase.from('profiles').select('id').eq('user_id', user.id).single()
      ).data?.id)
      .single();

    if (!driver) { setIsLoading(false); return; }

    setDriverId(driver.id as string);
    setVehicle({
      vehicle_category:    driver.vehicle_category as VehicleCategoryCode,
      vehicle_brand:       (driver.vehicle_brand as string) ?? null,
      vehicle_model:       (driver.vehicle_model as string) ?? null,
      license_plate:       driver.license_plate as string,
      vehicle_capacity_kg: (driver.vehicle_capacity_kg as number) ?? null,
    });
    setDocs([
      {
        docType: DOCUMENT_TYPES.DRIVER_LICENSE,
        number:  driver.driver_license_number as string,
        expiry:  driver.driver_license_expiry as string,
        status:  driver.driver_license_verified as VerificationStatus,
        url:     driver.driver_license_url as string,
      },
      {
        docType:          DOCUMENT_TYPES.VEHICLE_REGISTRATION,
        number:           driver.vehicle_registration_number as string,
        expiry:           driver.vehicle_registration_expiry as string,
        firstServiceDate: driver.vehicle_first_service_date as string,
        status:           driver.vehicle_registration_verified as VerificationStatus,
        url:              driver.vehicle_registration_url as string,
      },
      {
        docType: DOCUMENT_TYPES.INSURANCE,
        number:  driver.insurance_number as string,
        expiry:  driver.insurance_expiry as string,
        status:  driver.insurance_verified as VerificationStatus,
        url:     driver.insurance_url as string,
      },
      {
        docType: DOCUMENT_TYPES.TECHNICAL_INSPECTION,
        expiry:  driver.technical_inspection_expiry as string,
        status:  driver.technical_inspection_verified as VerificationStatus,
        url:     driver.technical_inspection_url as string,
      },
    ]);
    setIsLoading(false);
  }

  function openReplaceForm(doc: DocInfo) {
    setEditing(doc.docType);
    setDraftExpiry(doc.expiry ? doc.expiry.slice(0, 10) : null);
    setDraftFirstService(doc.firstServiceDate ? doc.firstServiceDate.slice(0, 10) : null);
    setFormError(null);
  }

  function closeReplaceForm() {
    setEditing(null);
    setDraftExpiry(null);
    setDraftFirstService(null);
    setFormError(null);
  }

  function validateForm(doc: DocInfo): string | null {
    const today = todayIsoDate();
    if (!draftExpiry) {
      return "Indiquez la nouvelle date d'expiration du document.";
    }
    if (draftExpiry < today) {
      return "La date d'expiration ne peut pas être déjà passée.";
    }
    if (doc.docType === DOCUMENT_TYPES.VEHICLE_REGISTRATION) {
      if (!draftFirstService) {
        return 'Indiquez la date de 1re mise en circulation du véhicule.';
      }
      if (draftFirstService > today) {
        return 'La date de 1re mise en circulation ne peut pas être dans le futur.';
      }
    }
    return null;
  }

  async function handleReplace(doc: DocInfo, fromCamera: boolean) {
    if (!driverId) return;

    const validationError = validateForm(doc);
    if (validationError) {
      setFormError(validationError);
      return;
    }
    setFormError(null);

    console.log('[FTM-DEBUG] Document - Replacement initiated', { driverId, docType: doc.docType });

    // Le selecteur de fichier doit s'ouvrir directement apres le clic :
    // sur le web, une boite de confirmation prealable bloque son ouverture
    // ("File chooser dialog can only be shown with a user activation").
    const picked = fromCamera ? await pickImageFromCamera() : await pickDocument();
    if (!picked) return;

    // Renouvellement anticipe d'un document encore valide : avertissement (C.2),
    // demande apres le choix du fichier et AVANT tout envoi.
    if (doc.status === 'verified') {
      const confirmed = await askConfirmation(REPLACE_VALID_WARNING);
      if (!confirmed) return;
    }

    setUploading(doc.docType);

    // 1. Envoi du fichier d'abord : en cas d'échec, rien n'est enregistré
    const result = await uploadDocument(driverId, doc.docType, picked.uri, picked.mimeType);
    if (result.error || !result.url) {
      setUploading(null);
      showMessage('Envoi impossible', result.error ?? "Le fichier n'a pas pu être envoyé.");
      return;
    }

    // 2. Puis lien + date(s) + statut 'pending', en une seule écriture
    const saved = await saveDocumentReplacement(
      driverId,
      doc.docType,
      result.url,
      draftExpiry as string,
      doc.docType === DOCUMENT_TYPES.VEHICLE_REGISTRATION ? draftFirstService : null,
    );

    setUploading(null);

    if (saved.error) {
      showMessage('Enregistrement impossible', saved.error);
      return;
    }

    closeReplaceForm();
    showMessage(
      'Document envoyé',
      "Votre document est en attente de validation par l'administrateur.",
    );
    loadDriver();
  }

  function openVehicleForm() {
    if (!vehicle) return;
    setVCategory(vehicle.vehicle_category);
    setVBrand(vehicle.vehicle_brand ?? '');
    setVModel(vehicle.vehicle_model ?? '');
    setVPlate(vehicle.license_plate ?? '');
    setVCapacity(vehicle.vehicle_capacity_kg ? String(vehicle.vehicle_capacity_kg) : '');
    setVehicleError(null);
    setEditingVehicle(true);
  }

  function closeVehicleForm() {
    setEditingVehicle(false);
    setVehicleError(null);
  }

  async function handleVehicleSave() {
    if (!driverId || !vehicle) return;

    const plate = vPlate.trim().toUpperCase();
    if (!vCategory) {
      setVehicleError('Choisissez la catégorie du véhicule.');
      return;
    }
    if (!LICENSE_PLATE_REGEX.test(plate)) {
      setVehicleError('Plaque invalide (format attendu : 12345-A-1).');
      return;
    }
    const capacityText = vCapacity.trim();
    const capacity = capacityText ? parseInt(capacityText, 10) : null;
    if (capacityText && (!/^[0-9]+$/.test(capacityText) || !capacity || capacity <= 0)) {
      setVehicleError('Capacité invalide (nombre de kg supérieur à 0).');
      return;
    }

    // Seuls les champs réellement modifiés sont envoyés
    const brand = vBrand.trim() || null;
    const model = vModel.trim() || null;
    const changes: Partial<VehicleChangeInput> = {};
    if (vCategory !== vehicle.vehicle_category)               changes.vehicle_category    = vCategory;
    if (brand !== (vehicle.vehicle_brand?.trim() || null))    changes.vehicle_brand       = brand;
    if (model !== (vehicle.vehicle_model?.trim() || null))    changes.vehicle_model       = model;
    if (plate !== vehicle.license_plate)                      changes.license_plate       = plate;
    if (capacity !== (vehicle.vehicle_capacity_kg || null))   changes.vehicle_capacity_kg = capacity;

    if (Object.keys(changes).length === 0) {
      setVehicleError('Aucune modification à enregistrer.');
      return;
    }
    setVehicleError(null);

    const confirmed = await askConfirmation(VEHICLE_CHANGE_WARNING);
    if (!confirmed) return;

    setSavingVehicle(true);
    const saved = await saveVehicleChange(driverId, changes);
    setSavingVehicle(false);

    if (saved.error) {
      setVehicleError(saved.error);
      return;
    }

    closeVehicleForm();
    showMessage(
      'Véhicule enregistré',
      "Votre carte grise est en attente de validation par l'administrateur. " +
      "Remplacez maintenant la carte grise, l'assurance et la visite technique du nouveau véhicule.",
    );
    loadDriver();
  }

  if (isLoading) {
    return (
      <View style={styles.loader}>
        <ActivityIndicator size="large" color={COLORS.primary} />
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      {navigation.canGoBack() ? (
        <TouchableOpacity style={styles.backBtn} onPress={() => navigation.goBack()}>
          <Text style={styles.backBtnText}>← Retour</Text>
        </TouchableOpacity>
      ) : null}
      <Text style={styles.title}>Mes documents</Text>

      {vehicle ? (
        <View style={styles.card}>
          <View style={styles.cardHeader}>
            <Text style={styles.cardTitle}>🚐 Mon véhicule</Text>
          </View>
          <Text style={styles.detail}>Catégorie : {categoryLabel(vehicle.vehicle_category)}</Text>
          {vehicle.vehicle_brand || vehicle.vehicle_model ? (
            <Text style={styles.detail}>
              Véhicule : {[vehicle.vehicle_brand, vehicle.vehicle_model].filter(Boolean).join(' ')}
            </Text>
          ) : null}
          <Text style={styles.detail}>Plaque : {vehicle.license_plate}</Text>
          {vehicle.vehicle_capacity_kg ? (
            <Text style={styles.detail}>Capacité : {vehicle.vehicle_capacity_kg} kg</Text>
          ) : null}

          {!editingVehicle ? (
            <View style={styles.actionRow}>
              <TouchableOpacity style={styles.reuploadBtn} onPress={openVehicleForm}>
                <Text style={styles.reuploadBtnText}>🚐 Changer de véhicule</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <View style={styles.form}>
              <View style={styles.categoryRow}>
                {VEHICLE_CATEGORIES.map(cat => (
                  <TouchableOpacity
                    key={cat.value}
                    style={[styles.categoryCard, vCategory === cat.value && styles.categoryCardSelected]}
                    onPress={() => setVCategory(cat.value)}
                  >
                    <Text style={styles.categoryIcon}>{cat.icon}</Text>
                    <Text style={styles.categoryLabel}>{cat.label}</Text>
                    <Text style={styles.categoryDesc}>{cat.description}</Text>
                  </TouchableOpacity>
                ))}
              </View>
              <TextInput
                style={styles.input}
                placeholder="Marque (ex: Mercedes)"
                value={vBrand}
                onChangeText={setVBrand}
              />
              <TextInput
                style={styles.input}
                placeholder="Modèle (ex: Sprinter)"
                value={vModel}
                onChangeText={setVModel}
              />
              <TextInput
                style={styles.input}
                placeholder="Plaque (ex: 12345-A-1)"
                value={vPlate}
                onChangeText={t => setVPlate(t.toUpperCase())}
                autoCapitalize="characters"
              />
              <TextInput
                style={styles.input}
                placeholder="Capacité max (kg)"
                value={vCapacity}
                onChangeText={setVCapacity}
                keyboardType="numeric"
              />

              {vehicleError ? <Text style={styles.formError}>{vehicleError}</Text> : null}

              {savingVehicle ? (
                <ActivityIndicator color={COLORS.primary} />
              ) : (
                <View style={styles.actionRow}>
                  <TouchableOpacity style={styles.reuploadBtn} onPress={handleVehicleSave}>
                    <Text style={styles.reuploadBtnText}>💾 Enregistrer</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={styles.cancelBtn} onPress={closeVehicleForm}>
                    <Text style={styles.cancelBtnText}>Annuler</Text>
                  </TouchableOpacity>
                </View>
              )}
            </View>
          )}
        </View>
      ) : null}

      {docs.map(doc => {
        const label     = DOCUMENT_LABELS[doc.docType];
        const config    = statusConfig(doc.status);
        const isEditing = editing === doc.docType;
        const isCarteGrise = doc.docType === DOCUMENT_TYPES.VEHICLE_REGISTRATION;
        const isVisiteTechnique = doc.docType === DOCUMENT_TYPES.TECHNICAL_INSPECTION;

        return (
          <View key={doc.docType} style={styles.card}>
            <View style={styles.cardHeader}>
              <Text style={styles.cardTitle}>{label.icon} {label.fr}</Text>
              <Text style={[styles.statusBadge, { color: config.color }]}>
                {config.icon} {config.label}
              </Text>
            </View>

            {doc.number ? (
              <Text style={styles.detail}>N° : {doc.number}</Text>
            ) : null}
            {doc.expiry ? (
              <Text style={styles.detail}>
                Expire : {formatIsoDateFr(doc.expiry)}
              </Text>
            ) : null}
            {isCarteGrise && doc.firstServiceDate ? (
              <Text style={styles.detail}>
                1re mise en circulation : {formatIsoDateFr(doc.firstServiceDate)}
              </Text>
            ) : null}

            {doc.status === 'expired' ? (
              <Text style={styles.expiredNote}>
                ⚠️ Renouvelez ce document pour rester actif.
              </Text>
            ) : null}

            <View style={styles.actionRow}>
              {doc.url ? (
                <TouchableOpacity
                  style={styles.viewBtn}
                  onPress={() => Linking.openURL(doc.url!)}
                >
                  <Text style={styles.viewBtnText}>Voir document</Text>
                </TouchableOpacity>
              ) : null}

              {!isEditing && uploading === null ? (
                <TouchableOpacity
                  style={styles.reuploadBtn}
                  onPress={() => openReplaceForm(doc)}
                >
                  <Text style={styles.reuploadBtnText}>🔄 Remplacer</Text>
                </TouchableOpacity>
              ) : null}
            </View>

            {isEditing ? (
              <View style={styles.form}>
                <DateOnlyField
                  label="Nouvelle date d'expiration"
                  value={draftExpiry}
                  onChange={setDraftExpiry}
                  minDate={todayIsoDate()}
                  hint={isVisiteTechnique ? TECHNICAL_INSPECTION_HINT : null}
                />
                {isCarteGrise ? (
                  <DateOnlyField
                    label="Date de 1re mise en circulation"
                    value={draftFirstService}
                    onChange={setDraftFirstService}
                    maxDate={todayIsoDate()}
                  />
                ) : null}

                {formError ? <Text style={styles.formError}>{formError}</Text> : null}

                {uploading === doc.docType ? (
                  <ActivityIndicator color={COLORS.primary} />
                ) : (
                  <View style={styles.actionRow}>
                    <TouchableOpacity
                      style={styles.reuploadBtn}
                      onPress={() => handleReplace(doc, true)}
                    >
                      <Text style={styles.reuploadBtnText}>📷 Photo</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={styles.reuploadBtn}
                      onPress={() => handleReplace(doc, false)}
                    >
                      <Text style={styles.reuploadBtnText}>📁 Fichier</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={styles.cancelBtn}
                      onPress={closeReplaceForm}
                    >
                      <Text style={styles.cancelBtnText}>Annuler</Text>
                    </TouchableOpacity>
                  </View>
                )}
              </View>
            ) : null}
          </View>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  loader:       { flex: 1, justifyContent: 'center', alignItems: 'center' },
  container:    { padding: 20, paddingBottom: 40 },
  backBtn:      { alignSelf: 'flex-start', paddingVertical: 6, marginBottom: 8 },
  backBtnText:  { color: COLORS.primary, fontWeight: '600', fontSize: 15 },
  title:        { fontSize: 22, fontWeight: '700', marginBottom: 20, color: '#1A1A2E' },
  card:         {
    borderWidth: 1, borderColor: '#E0E0E0', borderRadius: 12,
    padding: 16, marginBottom: 14, backgroundColor: '#FAFAFA',
  },
  cardHeader:   { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8 },
  cardTitle:    { fontSize: 15, fontWeight: '700', color: '#1A1A2E' },
  statusBadge:  { fontSize: 13, fontWeight: '600' },
  detail:       { fontSize: 13, color: '#555', marginBottom: 4 },
  expiredNote:  { fontSize: 13, color: '#DC3545', marginTop: 6, marginBottom: 6 },
  actionRow:    { flexDirection: 'row', gap: 8, marginTop: 10 },
  viewBtn:      {
    borderWidth: 1, borderColor: COLORS.primary, borderRadius: 8,
    paddingVertical: 8, paddingHorizontal: 14,
  },
  viewBtnText:    { color: COLORS.primary, fontWeight: '600', fontSize: 13 },
  reuploadBtn:    {
    borderWidth: 1, borderColor: '#DC3545', borderRadius: 8,
    paddingVertical: 8, paddingHorizontal: 14,
  },
  reuploadBtnText: { color: '#DC3545', fontWeight: '600', fontSize: 13 },
  form:           {
    marginTop: 12, paddingTop: 12,
    borderTopWidth: 1, borderTopColor: '#E0E0E0',
  },
  formError:      { color: '#DC3545', fontSize: 13, marginBottom: 6 },
  cancelBtn:      {
    borderWidth: 1, borderColor: '#999', borderRadius: 8,
    paddingVertical: 8, paddingHorizontal: 14,
  },
  cancelBtnText:  { color: '#555', fontWeight: '600', fontSize: 13 },
  categoryRow:    { flexDirection: 'row', gap: 8, marginBottom: 12 },
  categoryCard:   {
    flex: 1, borderWidth: 1.5, borderColor: '#DDD', borderRadius: 10,
    padding: 8, alignItems: 'center', backgroundColor: '#FFFFFF',
  },
  categoryCardSelected: { borderColor: COLORS.primary, backgroundColor: '#F0F4FF' },
  categoryIcon:   { fontSize: 22 },
  categoryLabel:  { fontWeight: '700', fontSize: 13, marginTop: 4, color: '#1A1A2E' },
  categoryDesc:   { fontSize: 10, color: '#666', textAlign: 'center' },
  input:          {
    borderWidth: 1, borderColor: '#DDD', borderRadius: 10,
    padding: 12, marginBottom: 10, fontSize: 15, backgroundColor: '#FFFFFF',
  },
});
