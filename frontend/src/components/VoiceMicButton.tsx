import React, { useRef, useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  ActivityIndicator,
  StyleSheet,
  Animated,
  Easing,
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { COLORS } from '../constants/theme';
import {
  startRecording,
  stopRecording,
  uploadVoiceMessage,
} from '../services/audioService';

interface VoiceMessage {
  url: string;
  duration: number;
  filePath: string;
  sender: string;
  timestamp: string;
}

interface Props {
  missionId: string;
  senderProfileId: string;
  onMessageSent?: (message: VoiceMessage) => void;
}

type RecordingState = 'idle' | 'recording' | 'uploading' | 'error';

export default function VoiceMicButton({ missionId, senderProfileId, onMessageSent }: Props) {
  const [recordingState, setRecordingState] = useState<RecordingState>('idle');
  const [recordingTime, setRecordingTime]   = useState(0);
  const timerRef  = useRef<ReturnType<typeof setInterval> | null>(null);
  const pulseAnim = useRef(new Animated.Value(1)).current;

  const startPulse = () => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue:         1.3,
          duration:        600,
          easing:          Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue:         1,
          duration:        600,
          easing:          Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
      ])
    ).start();
  };

  const stopPulse = () => {
    pulseAnim.stopAnimation();
    pulseAnim.setValue(1);
  };

  async function onPressIn() {
    console.log('[FTM-DEBUG] Audio - Press in — starting voice recording', {
      missionId, senderProfileId,
    });

    setRecordingState('recording');
    setRecordingTime(0);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    startPulse();

    let seconds = 0;
    timerRef.current = setInterval(() => {
      seconds++;
      setRecordingTime(seconds);
      if (seconds >= 120) {
        if (timerRef.current) clearInterval(timerRef.current);
        onPressOut();
      }
    }, 1000);

    const result = await startRecording();
    if (result.error) {
      if (timerRef.current) clearInterval(timerRef.current);
      stopPulse();
      setRecordingState('error');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      setTimeout(() => setRecordingState('idle'), 2000);
    }
  }

  async function onPressOut() {
    if (timerRef.current) clearInterval(timerRef.current);
    stopPulse();
    setRecordingState('uploading');

    const stopResult = await stopRecording();
    if (stopResult.error) {
      setRecordingState('error');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      setTimeout(() => setRecordingState('idle'), 2000);
      return;
    }

    const uploadResult = await uploadVoiceMessage(
      missionId,
      senderProfileId,
      stopResult.uri!,
      stopResult.mimeType!,
      stopResult.duration!
    );

    if (uploadResult.error) {
      setRecordingState('error');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      setTimeout(() => setRecordingState('idle'), 2000);
      return;
    }

    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setRecordingState('idle');
    setRecordingTime(0);

    if (onMessageSent) {
      onMessageSent({
        url:       uploadResult.url!,
        duration:  uploadResult.duration!,
        filePath:  uploadResult.filePath!,
        sender:    senderProfileId,
        timestamp: new Date().toISOString(),
      });
    }

    console.log('[FTM-DEBUG] Audio - Voice message sent successfully', {
      missionId, duration: stopResult.duration + 's',
    });
  }

  const formatTime = (s: number) => {
    const m = Math.floor(s / 60).toString().padStart(2, '0');
    const sec = (s % 60).toString().padStart(2, '0');
    return `${m}:${sec}`;
  };

  const bgColor =
    recordingState === 'recording' ? (COLORS.alert ?? '#DC3545')
    : recordingState === 'error'   ? '#888'
    : recordingState === 'uploading' ? '#CCC'
    : (COLORS.cta ?? '#F39C12');

  return (
    <View style={styles.wrapper}>
      {recordingState === 'recording' && (
        <Text style={styles.recordingTimer}>{formatTime(recordingTime)}</Text>
      )}

      <Animated.View style={{ transform: [{ scale: pulseAnim }] }}>
        <TouchableOpacity
          style={[styles.button, { backgroundColor: bgColor }]}
          onPressIn={onPressIn}
          onPressOut={onPressOut}
          disabled={recordingState === 'uploading'}
          activeOpacity={0.85}
        >
          {recordingState === 'uploading' ? (
            <ActivityIndicator color="#FFF" size="small" />
          ) : (
            <Text style={styles.micIcon}>🎤</Text>
          )}
        </TouchableOpacity>
      </Animated.View>

      <Text style={styles.label}>
        {recordingState === 'idle'      && 'Maintenir pour parler en Darija'}
        {recordingState === 'recording' && 'Relâchez pour envoyer'}
        {recordingState === 'uploading' && 'Envoi...'}
        {recordingState === 'error'     && 'Erreur — Réessayez'}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    alignItems: 'center',
    padding:    16,
    gap:        8,
  },
  button: {
    width:          64,
    height:         64,
    borderRadius:   32,
    alignItems:     'center',
    justifyContent: 'center',
    elevation:      4,
    shadowColor:    '#000',
    shadowOffset:   { width: 0, height: 2 },
    shadowOpacity:  0.2,
    shadowRadius:   4,
  },
  micIcon: {
    fontSize: 28,
  },
  recordingTimer: {
    fontSize:   16,
    fontWeight: '700',
    color:      '#DC3545',
  },
  label: {
    fontSize:  12,
    color:     '#666',
    textAlign: 'center',
  },
});
