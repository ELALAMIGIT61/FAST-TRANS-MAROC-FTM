import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { showMessage, confirmAction } from '../../utils/dialogs';
import { useNavigation, useFocusEffect } from '@react-navigation/native';
import { COLORS } from '../../constants/theme';
import { getAdminStats } from '../../services/adminService';
import { getReviewsToModerate } from '../../services/reputationService';
import NotificationBell from '../../components/NotificationBell';
import { signOutAndUnregisterDevice as handleSignOut } from '../../services/pushSetup';

interface AdminStats {
  totalMissions: number | null;
  completedMissions: number | null;
  completionRate: string;
  totalDrivers: number | null;
  verifiedDrivers: number | null;
  pendingDrivers: number;
  totalClients: number | null;
  totalCommissionsDH: string;
  pendingTransactions: number;
  unreconciledTransactions: number;
}

export default function AdminDashboardScreen() {
  const navigation = useNavigation<any>();
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  // A1 F5 : nombre de commentaires en attente, relu a chaque retour sur l'ecran
  const [reviewsToModerate, setReviewsToModerate] = useState(0);
  // Tableau de bord en 2 onglets (fiche de travail du 25/11/2026) :
  // « Traitement » (ouvert par defaut) et « Gestion »
  const [tab, setTab] = useState<'traitement' | 'gestion'>('traitement');

  const loadStats = useCallback(async () => {
    const result = await getAdminStats();
    if (result.success && result.stats) {
      setStats(result.stats as AdminStats);
    }
    setLoading(false);
    setRefreshing(false);
  }, []);

  // Fiche du 25/11/2026 : tous les nombres sont relus a chaque retour sur
  // le tableau de bord (et plus seulement a l'ouverture), pour que les
  // compteurs baissent aussitot apres un traitement.
  useFocusEffect(
    useCallback(() => {
      loadStats();
      getReviewsToModerate().then((r) => setReviewsToModerate(r.reviews?.length ?? 0));
    }, [loadStats])
  );

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadStats();
  }, [loadStats]);
  const handleLogout = async () => {
    const ok = await confirmAction('Déconnexion', 'Voulez-vous vraiment vous déconnecter ?', {
      confirmLabel: 'Se déconnecter',
      destructive: true,
    });
    if (!ok) return;
    const result = await handleSignOut();
    if (result.error) showMessage('Erreur', result.error);
  };


  // Onglet « Traitement » : les 4 sujets a traiter, avec leur compteur
  const pendingDrivers = stats?.pendingDrivers ?? 0;
  const todoItems = [
    { route: 'DocumentReview', icon: '📋', label: 'Documents en attente', count: pendingDrivers },
    { route: 'PendingTransactions', icon: '💰', label: 'Demandes financières', count: stats?.pendingTransactions ?? 0 },
    { route: 'BankReconciliation', icon: '🏦', label: 'Rapprochement bancaire', count: stats?.unreconciledTransactions ?? 0 },
    { route: 'AdminReviews', icon: '⭐', label: 'Avis à modérer', count: reviewsToModerate },
  ];
  const toTreat = todoItems.reduce((sum, item) => sum + item.count, 0);
  // Onglet « Gestion » : les ecrans de gestion, en grille de 2 colonnes
  const manageItems = [
    { route: 'AdminMissions', icon: '🚚', label: 'Toutes les missions' },
    { route: 'AdminUsers', icon: '👥', label: 'Gestion utilisateurs' },
    { route: 'WalletManagement', icon: '👛', label: 'Portefeuilles des chauffeurs' },
    { route: 'AdminSettings', icon: '⚙️', label: 'Réglages' },
  ];

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color={COLORS.primary} />
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      // A1 : marge sous la derniere ligne (« Reglages ») pour qu'elle ne colle
      // pas au bas de l'ecran (remarque du porteur du 30/10/2026)
      contentContainerStyle={styles.scrollContent}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
    >
      <View style={styles.headerRow}>
        <Text style={styles.title}>🛡️ Admin FTM</Text>
        <NotificationBell />
        <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
          <Text style={styles.logoutButtonText}>🚪 Se déconnecter</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.tabRow}>
        <TouchableOpacity
          style={[styles.tab, tab === 'traitement' && styles.tabActive]}
          onPress={() => setTab('traitement')}
        >
          <Text style={[styles.tabText, tab === 'traitement' && styles.tabTextActive]}>📌 Traitement</Text>
          {toTreat > 0 && (
            <View style={styles.tabBadge}>
              <Text style={styles.tabBadgeText}>{toTreat}</Text>
            </View>
          )}
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, tab === 'gestion' && styles.tabActive]}
          onPress={() => setTab('gestion')}
        >
          <Text style={[styles.tabText, tab === 'gestion' && styles.tabTextActive]}>📊 Gestion</Text>
        </TouchableOpacity>
      </View>

      {tab === 'traitement' ? (
        <>
          <Text style={styles.sectionTitle}>Chiffres clés</Text>
          <View style={styles.tileGrid}>
            <View style={styles.statTile}>
              <Text style={styles.statIcon}>🚚</Text>
              <Text style={styles.statValue}>{stats?.totalMissions ?? 0}</Text>
              <Text style={styles.statLabel}>Missions</Text>
              <Text style={styles.statSub}>Taux : {stats?.completionRate}</Text>
            </View>
            <View style={styles.statTile}>
              <Text style={styles.statIcon}>💵</Text>
              <Text style={styles.statValue} numberOfLines={1} adjustsFontSizeToFit>
                {stats?.totalCommissionsDH} DH
              </Text>
              <Text style={styles.statLabel}>Commissions collectées</Text>
            </View>
            <View style={styles.statTile}>
              <Text style={styles.statIcon}>🚛</Text>
              <Text style={styles.statValue}>{stats?.totalDrivers ?? 0}</Text>
              <Text style={styles.statLabel}>Chauffeurs</Text>
              <Text style={styles.statSub}>Vérifiés : {stats?.verifiedDrivers ?? 0}</Text>
            </View>
            <View style={styles.statTile}>
              <Text style={styles.statIcon}>⏳</Text>
              <Text style={[styles.statValue, pendingDrivers > 0 && styles.valueWarning]}>{pendingDrivers}</Text>
              <Text style={styles.statLabel}>En attente</Text>
            </View>
            <View style={styles.statTile}>
              <Text style={styles.statIcon}>👤</Text>
              <Text style={styles.statValue}>{stats?.totalClients ?? 0}</Text>
              <Text style={styles.statLabel}>Clients</Text>
            </View>
          </View>

          <Text style={styles.sectionTitle}>À traiter</Text>
          {todoItems.map((item) => (
            <TouchableOpacity
              key={item.route}
              style={[styles.todoCard, item.count > 0 ? styles.todoCardWarning : styles.todoCardDone]}
              onPress={() => navigation.navigate(item.route)}
            >
              <Text style={styles.todoIcon}>{item.icon}</Text>
              <Text style={styles.todoLabel}>{item.label}</Text>
              {item.count > 0 ? (
                <Text style={styles.todoCount}>{item.count}</Text>
              ) : (
                <Text style={styles.todoDone}>Rien à traiter ✅</Text>
              )}
              <Text style={styles.navArrow}>→</Text>
            </TouchableOpacity>
          ))}
        </>
      ) : (
        <>
          <Text style={styles.sectionTitle}>Gestion</Text>
          <View style={styles.tileGrid}>
            {manageItems.map((item) => (
              <TouchableOpacity
                key={item.route}
                style={styles.manageTile}
                onPress={() => navigation.navigate(item.route)}
              >
                <Text style={styles.manageIcon}>{item.icon}</Text>
                <Text style={styles.manageLabel}>{item.label}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F7FA',
    padding: 16,
  },
  scrollContent: { paddingBottom: 64 },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: COLORS.primary,
    marginTop: 8,
    // Session 3.4 : le titre se replie sur deux lignes si l'ecran est etroit,
    // pour laisser la place a la cloche et au bouton de deconnexion.
    flex: 1,
    flexShrink: 1,
    marginRight: 8,
  },
  // Sous-titres mis en valeur (maquette validee le 25/11/2026)
  sectionTitle: {
    fontSize: 17,
    fontWeight: '800',
    color: COLORS.primary,
    borderBottomWidth: 2,
    borderBottomColor: '#D6E4F5',
    paddingBottom: 4,
    marginTop: 8,
    marginBottom: 10,
  },
  tabRow: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: '#DEE2E6',
    marginBottom: 14,
  },
  tab: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 3,
    borderBottomColor: 'transparent',
  },
  tabActive: { borderBottomColor: COLORS.primary },
  tabText: { fontSize: 16, fontWeight: '600', color: '#6C757D' },
  tabTextActive: { fontWeight: '700', color: COLORS.primary },
  tabBadge: {
    backgroundColor: '#F59E0B',
    borderRadius: 11,
    minWidth: 22,
    height: 22,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 6,
    marginLeft: 6,
  },
  tabBadgeText: { color: '#FFF', fontSize: 12, fontWeight: '700' },
  tileGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginBottom: 6,
  },
  statTile: {
    width: '48.5%',
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    paddingVertical: 8,
    paddingHorizontal: 6,
    marginBottom: 8,
    alignItems: 'center',
    elevation: 2,
  },
  statIcon: { fontSize: 18 },
  statValue: { fontSize: 19, fontWeight: '800', color: '#1A1A2E' },
  statLabel: { fontSize: 14, fontWeight: '600', color: '#1A1A2E', textAlign: 'center' },
  statSub: { fontSize: 12, color: '#888' },
  valueWarning: { color: '#F59E0B' },
  todoCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 14,
    borderLeftWidth: 4,
    paddingVertical: 11,
    paddingHorizontal: 14,
    marginBottom: 10,
    elevation: 2,
  },
  todoCardWarning: { borderLeftColor: '#F59E0B' },
  todoCardDone: { borderLeftColor: '#28A745' },
  todoIcon: { fontSize: 22, marginRight: 12 },
  todoLabel: { flex: 1, fontSize: 16, fontWeight: '600', color: '#1A1A2E' },
  todoCount: { fontSize: 26, fontWeight: '800', color: '#F59E0B', marginLeft: 8 },
  todoDone: { fontSize: 14, fontWeight: '600', color: '#28A745', marginLeft: 8 },
  navArrow: {
    fontSize: 16,
    color: '#CCC',
    marginLeft: 8,
  },
  manageTile: {
    width: '48.5%',
    minHeight: 120,
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    paddingVertical: 20,
    paddingHorizontal: 10,
    marginBottom: 12,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 2,
  },
  manageIcon: { fontSize: 34, marginBottom: 10 },
  manageLabel: { fontSize: 15, fontWeight: '600', color: '#1A1A2E', textAlign: 'center' },
  logoutButton: {
    paddingVertical: 4,
    paddingHorizontal: 8,
  },
  logoutButtonText: {
    fontSize: 12,
    color: '#DC3545',
  },
});
