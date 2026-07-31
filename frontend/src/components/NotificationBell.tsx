import React, { useEffect, useState, useCallback } from 'react';
import {
  TouchableOpacity,
  View,
  Text,
  StyleSheet,
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { useNavigation } from '@react-navigation/native';
import { COLORS } from '../constants/theme';
import {
  getCurrentProfileId,
  getNotifications,
  subscribeToNotifications,
} from '../services/pushNotificationService';

export default function NotificationBell() {
  const [profileId, setProfileId] = useState<string | null>(null);
  const [unreadCount, setUnreadCount] = useState(0);
  const navigation = useNavigation<{ navigate: (screen: string) => void }>();

  useEffect(() => {
    getCurrentProfileId().then(setProfileId);
  }, []);

  const fetchUnread = useCallback(async () => {
    if (!profileId) return;
    const result = await getNotifications(profileId, 0, true);
    if (result.success) {
      setUnreadCount(result.unreadCount ?? 0);
    }
  }, [profileId]);

  useEffect(() => {
    if (!profileId) return;
    fetchUnread();

    const channel = subscribeToNotifications(profileId, () => {
      setUnreadCount((prev) => prev + 1);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    });

    return () => {
      channel.unsubscribe();
    };
  }, [profileId, fetchUnread]);

  if (!profileId) return null;

  return (
    <TouchableOpacity
      style={styles.container}
      onPress={() => navigation.navigate('NotificationCenter')}
      accessibilityLabel="Centre de notifications"
    >
      <Text style={styles.icon}>🔔</Text>
      {unreadCount > 0 && (
        <View style={styles.badge}>
          <Text style={styles.badgeText}>
            {unreadCount > 99 ? '99+' : String(unreadCount)}
          </Text>
        </View>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    position:  'relative',
    padding:   8,
    marginRight: 4,
  },
  icon: {
    fontSize: 22,
  },
  badge: {
    position:        'absolute',
    top:             2,
    right:           2,
    backgroundColor: COLORS.alert ?? '#DC3545',
    borderRadius:    10,
    minWidth:        18,
    height:          18,
    alignItems:      'center',
    justifyContent:  'center',
    paddingHorizontal: 4,
  },
  badgeText: {
    color:      '#FFFFFF',
    fontSize:   10,
    fontWeight: '700',
  },
});
