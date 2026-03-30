import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { COLORS } from '../../constants/theme';
import { getAdminStats } from '../../services/adminService';

interface AdminStats {
  totalMissions: number | null;
  completedMissions: number | null;
  completionRate: string;
  totalDrivers: number | null;
  verifiedDrivers: number | null;
  pendingDrivers: number;
  totalClients: number | null;
  totalCommissionsDH: string;
}

export default function AdminDashboardScreen() {
  const navigation = useNavigation<any>();
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const loadStats = useCallback(async () => {
    const result = await getAdminStats();
    if (result.success && result.stats) {
      setStats(result.stats as AdminStats);
    }
    setLoading(false);
    setRefreshing(false);
  }, []);

  useEffect(() => {
    loadStats();
  }, [loadStats]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadStats();
  }, [loadStats]);

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
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
    >
      <Text style={styles.title}>🛡️ Admin FTM — Dashboard</Text>

      <Text style={styles.sectionTitle}>── KPIs ──</Text>
      <View style={styles.kpiGrid}>
        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Missions Total</Text>
          <Text style={styles.kpiValue}>{stats?.totalMissions ?? 0}</Text>
          <Text style={styles.kpiSub}>Taux : {stats?.completionRate}</Text>
        </View>
        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Commissions Collectées</Text>
          <Text style={styles.kpiValue}>{stats?.totalCommissionsDH} DH</Text>
        </View>
        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Chauffeurs Total</Text>
          <Text style={styles.kpiValue}>{stats?.totalDrivers ?? 0}</Text>
          <Text style={styles.kpiSub}>Vérifiés : {stats?.verifiedDrivers ?? 0}</Text>
        </View>
        <View style={[styles.kpiCard, (stats?.pendingDrivers ?? 0) > 0 && styles.kpiCardWarning]}>
          <Text style={styles.kpiLabel}>En attente</Text>
          <Text style={[styles.kpiValue, (stats?.pendingDrivers ?? 0) > 0 && styles.kpiValueWarning]}>
            {(stats?.pendingDrivers ?? 0) > 0 ? '⚠️ ' : ''}{stats?.pendingDrivers ?? 0}
          </Text>
        </View>
        <View style={styles.kpiCard}>
          <Text style={styles.kpiLabel}>Clients Total</Text>
          <Text style={styles.kpiValue}>{stats?.totalClients ?? 0}</Text>
        </View>
      </View>

      <Text style={styles.sectionTitle}>── NAVIGATION ──</Text>

      <TouchableOpacity
        style={styles.navItem}
        onPress={() => navigation.navigate('DocumentReview')}
      >
        <Text style={styles.navText}>📋 Documents en attente</Text>
        {(stats?.pendingDrivers ?? 0) > 0 && (
          <View style={styles.badge}>
            <Text style={styles.badgeText}>{stats?.pendingDrivers}</Text>
          </View>
        )}
        <Text style={styles.navArrow}>→</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.navItem}
        onPress={() => navigation.navigate('AdminMissions')}
      >
        <Text style={styles.navText}>🚚 Toutes les missions</Text>
        <Text style={styles.navArrow}>→</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.navItem}
        onPress={() => navigation.navigate('AdminUsers')}
      >
        <Text style={styles.navText}>👥 Gestion utilisateurs</Text>
        <Text style={styles.navArrow}>→</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.navItem}
        onPress={() => navigation.navigate('WalletManagement')}
      >
        <Text style={styles.navText}>💰 Wallets & Transactions</Text>
        <Text style={styles.navArrow}>→</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F7FA',
    padding: 16,
  },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: COLORS.primary,
    marginBottom: 20,
    marginTop: 8,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#888',
    marginBottom: 12,
    marginTop: 8,
  },
  kpiGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
    marginBottom: 24,
  },
  kpiCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    width: '47%',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 4,
    elevation: 2,
  },
  kpiCardWarning: {
    borderLeftWidth: 3,
    borderLeftColor: '#F59E0B',
  },
  kpiLabel: {
    fontSize: 12,
    color: '#888',
    marginBottom: 4,
  },
  kpiValue: {
    fontSize: 24,
    fontWeight: '700',
    color: '#1A1A2E',
  },
  kpiValueWarning: {
    color: '#F59E0B',
  },
  kpiSub: {
    fontSize: 11,
    color: '#AAA',
    marginTop: 2,
  },
  navItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    elevation: 1,
  },
  navText: {
    flex: 1,
    fontSize: 15,
    fontWeight: '500',
    color: '#1A1A2E',
  },
  navArrow: {
    fontSize: 16,
    color: '#CCC',
  },
  badge: {
    backgroundColor: '#EF4444',
    borderRadius: 10,
    minWidth: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 6,
    marginRight: 8,
  },
  badgeText: {
    color: '#FFF',
    fontSize: 11,
    fontWeight: '700',
  },
});
