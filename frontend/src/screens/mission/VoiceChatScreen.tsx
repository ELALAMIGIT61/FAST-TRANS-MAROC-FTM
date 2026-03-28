import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import { COLORS } from '../../constants/theme';
import {
  loadVoiceMessages,
  playVoiceMessage,
  stopPlayback,
} from '../../services/audioService';
import VoiceMicButton from '../../components/VoiceMicButton';

interface VoiceMsg {
  id: string;
  fileName: string;
  url: string | null;
  sender: string;
  timestamp: Date | null;
  size: number;
  isPlaying?: boolean;
  progress?: number;
}

interface Props {
  missionId: string;
  currentProfileId: string;
  missionNumber: string;
}

function timeAgo(date: Date | null): string {
  if (!date) return '';
  const diff = Date.now() - date.getTime();
  const min  = Math.floor(diff / 60000);
  if (min < 1)  return 'À l\'instant';
  if (min < 60) return `Il y a ${min} min`;
  return `Il y a ${Math.floor(min / 60)}h`;
}

export default function VoiceChatScreen({
  missionId,
  currentProfileId,
  missionNumber,
}: Props) {
  const [messages, setMessages] = useState<VoiceMsg[]>([]);
  const [loading, setLoading]   = useState(true);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const flatRef = useRef<FlatList>(null);

  const fetchMessages = useCallback(async () => {
    setLoading(true);
    const result = await loadVoiceMessages(missionId);
    if (result.success && result.messages) {
      setMessages(result.messages as VoiceMsg[]);
    }
    setLoading(false);
  }, [missionId]);

  useEffect(() => { fetchMessages(); }, [fetchMessages]);

  const handlePlay = async (msg: VoiceMsg) => {
    if (!msg.url) return;

    if (playingId === msg.id) {
      await stopPlayback();
      setPlayingId(null);
      return;
    }

    await stopPlayback();
    setPlayingId(msg.id);

    await playVoiceMessage(
      msg.url,
      (progress) => {
        setMessages(prev =>
          prev.map(m => m.id === msg.id ? { ...m, progress } : m)
        );
      },
      () => setPlayingId(null)
    );
  };

  const onMessageSent = (newMsg: {
    url: string;
    duration: number;
    filePath: string;
    sender: string;
    timestamp: string;
  }) => {
    const item: VoiceMsg = {
      id:        `local_${Date.now()}`,
      fileName:  newMsg.filePath.split('/').pop() || '',
      url:       newMsg.url,
      sender:    newMsg.sender,
      timestamp: new Date(newMsg.timestamp),
      size:      0,
    };
    setMessages(prev => [...prev, item]);
    setTimeout(() => flatRef.current?.scrollToEnd({ animated: true }), 100);
  };

  const renderItem = ({ item }: { item: VoiceMsg }) => {
    const isOwn    = item.sender === currentProfileId;
    const isPlay   = playingId === item.id;
    const progress = item.progress ?? 0;

    return (
      <View style={[styles.msgRow, isOwn ? styles.msgRowRight : styles.msgRowLeft]}>
        <TouchableOpacity
          style={[styles.msgBubble, isOwn ? styles.msgBubbleOwn : styles.msgBubbleOther]}
          onPress={() => handlePlay(item)}
        >
          <Text style={styles.playIcon}>{isPlay ? '⏸' : '▶'}</Text>
          <View style={styles.progressBar}>
            <View style={[styles.progressFill, { width: `${progress * 100}%` }]} />
          </View>
          <Text style={styles.time}>{timeAgo(item.timestamp)}</Text>
        </TouchableOpacity>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>💬 Chat vocal — Mission FTM...{missionNumber.slice(-3)}</Text>
        <Text style={styles.headerSub}>Messages vocaux en Darija</Text>
      </View>

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator color={COLORS.primary ?? '#1A73E8'} />
        </View>
      ) : (
        <FlatList
          ref={flatRef}
          data={messages}
          keyExtractor={item => item.id}
          renderItem={renderItem}
          contentContainerStyle={styles.listContent}
          ListEmptyComponent={
            <View style={styles.empty}>
              <Text style={styles.emptyIcon}>🎤</Text>
              <Text style={styles.emptyTitle}>Pas encore de messages</Text>
              <Text style={styles.emptyBody}>
                Maintenez le bouton pour parler{'\n'}en Darija avec votre chauffeur
              </Text>
            </View>
          }
          onContentSizeChange={() => flatRef.current?.scrollToEnd({ animated: false })}
        />
      )}

      {/* Séparateur + VoiceMicButton */}
      <View style={styles.footer}>
        <View style={styles.divider} />
        <VoiceMicButton
          missionId={missionId}
          senderProfileId={currentProfileId}
          onMessageSent={onMessageSent}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container:  { flex: 1, backgroundColor: '#FAFAFA' },
  center:     { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header: {
    padding:         14,
    backgroundColor: '#FFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  headerTitle: { fontSize: 15, fontWeight: '700', color: '#222' },
  headerSub:   { fontSize: 12, color: '#888', marginTop: 2 },
  listContent: { padding: 12, flexGrow: 1 },
  msgRow:      { marginVertical: 4 },
  msgRowLeft:  { alignItems: 'flex-start' },
  msgRowRight: { alignItems: 'flex-end' },
  msgBubble: {
    flexDirection:  'row',
    alignItems:     'center',
    gap:            8,
    padding:        10,
    borderRadius:   12,
    maxWidth:       '80%',
  },
  msgBubbleOther: { backgroundColor: '#F0F0F0' },
  msgBubbleOwn:   { backgroundColor: (COLORS.primary ?? '#1A73E8') + '20' },
  playIcon:    { fontSize: 18 },
  progressBar: {
    flex:            1,
    height:          4,
    backgroundColor: '#DDD',
    borderRadius:    2,
    overflow:        'hidden',
  },
  progressFill: { height: '100%', backgroundColor: COLORS.primary ?? '#1A73E8' },
  time:        { fontSize: 10, color: '#999', minWidth: 50 },
  empty:       { flex: 1, alignItems: 'center', justifyContent: 'center', marginTop: 80, gap: 10 },
  emptyIcon:   { fontSize: 48 },
  emptyTitle:  { fontSize: 16, fontWeight: '700', color: '#444' },
  emptyBody:   { fontSize: 13, color: '#888', textAlign: 'center', lineHeight: 20 },
  footer:      { backgroundColor: '#FFF' },
  divider:     { height: 1, backgroundColor: '#E0E0E0' },
});
