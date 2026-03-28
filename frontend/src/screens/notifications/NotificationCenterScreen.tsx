import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { COLORS } from '../../constants/theme';
import {
  getNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  handleNotificationTap,
} from '../../services/pushNotificationService';
import { NOTIF_ICONS } from '../../services/notificationTemplates';

// ─── Typage minimal notification ──────────────────────────────────────────────

interface NotifItem {
  id: string;
  profile_id: string;
  type: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
  is_read: boolean;
  created_at: string;
}

interface Props {
  profileId: string;
}

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const min  = Math.floor(diff / 60000);
  if (min < 1)  return 'À l\'instant';
  if (min < 60) return `Il y a ${min} min`;
  const h = Math.floor(min / 60);
  if (h < 24)   return `Il y a ${h}h`;
  return `Il y a ${Math.floor(h / 24)}j`;
}

export default function NotificationCenterScreen({ profileId }: Props) {
  const [notifications, setNotifications] = useState<NotifItem[]>([]);
  const [loading, setLoading]     = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [page, setPage]           = useState(0);
  const [hasMore, setHasMore]     = useState(false);
  const navigation = useNavigation<{ navigate: (screen: string, params?: Record<string, unknown>) => void }>();

  const load = useCallback(async (p = 0, refresh = false) => {
    if (refresh) setRefreshing(true);
    const result = await getNotifications(profileId, p);
    if (result.success) {
      const items = result.notifications as NotifItem[];
      setNotifications(prev => p === 0 ? items : [...prev, ...items]);
      setHasMore(result.hasMore ?? false);
      setPage(p);
    }
    setLoading(false);
    setRefreshing(false);
  }, [profileId]);

  useEffect(() => { load(0); }, [load]);

  const onRefresh = () => load(0, true);
  const onLoadMore = () => { if (hasMore && !loading) load(page + 1); };

  const onTap = async (item: NotifItem) => {
    if (!item.is_read) {
      await markNotificationRead(item.id, profileId);
      setNotifications(prev =>
        prev.map(n => n.id === item.id ? { ...n, is_read: true } : n)
      );
    }
    handleNotificationTap(
      { id: item.id, profile_id: item.profile_id, type: item.type, data: item.data },
      (screen, params) => navigation.navigate(screen, params)
    );
  };

  const onMarkAll = async () => {
    await markAllNotificationsRead(profileId);
    setNotifications(prev => prev.map(n => ({ ...n, is_read: true })));
  };

  const renderItem = ({ item }: { item: NotifItem }) => (
    <TouchableOpacity
      style={[styles.card, !item.is_read && styles.cardUnread]}
      onPress={() => onTap(item)}
    >
      {!item.is_read && <View style={styles.dot} />}
      <Text style={styles.icon}>{NOTIF_ICONS[item.type] ?? '🔔'}</Text>
      <View style={styles.content}>
        <Text style={styles.title}>{item.title}</Text>
        <Text style={styles.body} numberOfLines={2}>{item.body}</Text>
        <Text style={styles.time}>{timeAgo(item.created_at)}</Text>
      </View>
    </TouchableOpacity>
  );

  if (loading && notifications.length === 0) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={COLORS.primary ?? '#1A73E8'} size="large" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Notifications</Text>
        <TouchableOpacity onPress={onMarkAll}>
          <Text style={styles.markAll}>Tout lire</Text>
        </TouchableOpacity>
      </View>

      <FlatList
        data={notifications}
        keyExtractor={item => item.id}
        renderItem={renderItem}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        onEndReached={onLoadMore}
        onEndReachedThreshold={0.3}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={styles.emptyIcon}>🔔</Text>
            <Text style={styles.emptyText}>Aucune notification</Text>
          </View>
        }
        ListFooterComponent={
          hasMore ? <ActivityIndicator style={{ margin: 16 }} color={COLORS.primary ?? '#1A73E8'} /> : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container:   { flex: 1, backgroundColor: '#F5F5F5' },
  center:      { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header:      {
    flexDirection:   'row',
    justifyContent:  'space-between',
    alignItems:      'center',
    padding:         16,
    backgroundColor: '#FFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  headerTitle: { fontSize: 18, fontWeight: '700' },
  markAll:     { fontSize: 14, color: COLORS.primary ?? '#1A73E8', fontWeight: '600' },
  card: {
    flexDirection:   'row',
    backgroundColor: '#FFF',
    marginHorizontal: 12,
    marginVertical:  4,
    borderRadius:    10,
    padding:         12,
    alignItems:      'flex-start',
    gap:             10,
  },
  cardUnread:  { backgroundColor: '#EBF3FF' },
  dot: {
    width:           8,
    height:          8,
    borderRadius:    4,
    backgroundColor: COLORS.primary ?? '#1A73E8',
    marginTop:       6,
  },
  icon:        { fontSize: 22 },
  content:     { flex: 1 },
  title:       { fontSize: 14, fontWeight: '700', color: '#222', marginBottom: 2 },
  body:        { fontSize: 13, color: '#555', lineHeight: 18 },
  time:        { fontSize: 11, color: '#999', marginTop: 4 },
  empty:       { alignItems: 'center', marginTop: 80, gap: 12 },
  emptyIcon:   { fontSize: 48 },
  emptyText:   { fontSize: 16, color: '#888' },
});
