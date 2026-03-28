import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Modal,
  Animated,
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { COLORS, SPACING, BORDER_RADIUS } from '../../constants/theme';
import { acceptMission } from '../../services/missionService';
import type { Mission } from '../../services/missionService';

interface Props {
  mission: Mission;
  driverId: string;
  onAccepted: (mission: Mission) => void;
  onDismiss: () => void;
}

const COUNTDOWN_SECONDS = 30;

export default function NewMissionModal({ mission, driverId, onAccepted, onDismiss }: Props) {
  const [timeLeft, setTimeLeft] = useState(COUNTDOWN_SECONDS);
  const [isAccepting, setIsAccepting] = useState(false);
  const progressAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);

    Animated.timing(progressAnim, {
      toValue: 0,
      duration: COUNTDOWN_SECONDS * 1000,
      useNativeDriver: false,
    }).start();

    const interval = setInterval(() => {
      setTimeLeft((prev) => {
        if (prev <= 1) {
          clearInterval(interval);
          onDismiss();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, []);

  const handleAccept = async () => {
    setIsAccepting(true);
    const result = await acceptMission(mission.id, driverId);
    setIsAccepting(false);

    if (result.error) {
      onDismiss();
    } else if (result.mission) {
      onAccepted(result.mission);
    }
  };

  const progressWidth = progressAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ['0%', '100%'],
  });

  return (
    <Modal transparent animationType="slide" visible>
      <View style={styles.overlay}>
        <View style={styles.card}>
          <Text style={styles.badge}>🔔 NOUVELLE MISSION</Text>
          <Text style={styles.missionNumber}>N° {mission.mission_number}</Text>

          <View style={styles.addressSection}>
            <Text style={styles.addressLabel}>📍 Départ</Text>
            <Text style={styles.addressText}>{mission.pickup_address}</Text>
            <Text style={styles.addressLabel}>🏁 Arrivée</Text>
            <Text style={styles.addressText}>{mission.dropoff_address}</Text>
          </View>

          <View style={styles.infoRow}>
            <View style={styles.infoItem}>
              <Text style={styles.infoIcon}>📏</Text>
              <Text style={styles.infoValue}>
                {mission.estimated_distance_km ? `~${mission.estimated_distance_km} km` : 'N/A'}
              </Text>
            </View>
            <View style={styles.infoItem}>
              <Text style={styles.infoIcon}>💰</Text>
              <Text style={styles.infoValue}>
                {mission.commission_amount ? `${mission.commission_amount} DH` : 'N/A'}
              </Text>
            </View>
            <View style={styles.infoItem}>
              <Text style={styles.infoIcon}>💪</Text>
              <Text style={styles.infoValue}>{mission.needs_loading_help ? 'Oui' : 'Non'}</Text>
            </View>
          </View>

          <View style={styles.progressContainer}>
            <Animated.View
              style={[styles.progressBar, { width: progressWidth }]}
            />
          </View>
          <Text style={styles.countdown}>{timeLeft}s</Text>

          <View style={styles.actionRow}>
            <TouchableOpacity
              style={styles.refuseButton}
              onPress={onDismiss}
              disabled={isAccepting}
            >
              <Text style={styles.refuseButtonText}>❌ Refuser</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.acceptButton, isAccepting && styles.buttonDisabled]}
              onPress={handleAccept}
              disabled={isAccepting}
            >
              <Text style={styles.acceptButtonText}>✅ Accepter</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'flex-end',
  },
  card: {
    backgroundColor: COLORS.background,
    borderTopLeftRadius: BORDER_RADIUS.xl ?? 24,
    borderTopRightRadius: BORDER_RADIUS.xl ?? 24,
    padding: SPACING.lg,
    gap: SPACING.md,
  },
  badge: {
    fontSize: 18,
    fontWeight: '800',
    color: COLORS.text,
    textAlign: 'center',
    letterSpacing: 0.5,
  },
  missionNumber: {
    fontSize: 14,
    color: COLORS.textSecondary,
    textAlign: 'center',
  },
  addressSection: {
    backgroundColor: COLORS.surface,
    borderRadius: BORDER_RADIUS.md,
    padding: SPACING.md,
    gap: SPACING.xs,
  },
  addressLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: COLORS.textSecondary,
    letterSpacing: 1,
  },
  addressText: { fontSize: 15, color: COLORS.text, marginBottom: SPACING.xs },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  infoItem: { alignItems: 'center', gap: 4 },
  infoIcon: { fontSize: 20 },
  infoValue: { fontSize: 14, fontWeight: '600', color: COLORS.text },
  progressContainer: {
    height: 6,
    backgroundColor: COLORS.border,
    borderRadius: 3,
    overflow: 'hidden',
  },
  progressBar: {
    height: '100%',
    backgroundColor: COLORS.alert ?? '#E53E3E',
    borderRadius: 3,
  },
  countdown: {
    textAlign: 'center',
    fontSize: 13,
    color: COLORS.textSecondary,
    marginTop: -SPACING.xs,
  },
  actionRow: { flexDirection: 'row', gap: SPACING.sm },
  acceptButton: {
    flex: 1,
    backgroundColor: COLORS.success ?? '#38A169',
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
  },
  acceptButtonText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  refuseButton: {
    flex: 1,
    backgroundColor: (COLORS.alert ?? '#E53E3E') + '15',
    borderRadius: BORDER_RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.alert ?? '#E53E3E',
  },
  refuseButtonText: { color: COLORS.alert ?? '#E53E3E', fontSize: 16, fontWeight: '700' },
  buttonDisabled: { opacity: 0.5 },
});
