import { Audio } from 'expo-av';
import { supabase } from '../lib/supabaseClient';

let recordingInstance: Audio.Recording | null = null;
let soundInstance: Audio.Sound | null = null;

// ─── PERMISSION MICROPHONE ─────────────────────────────────────────────────────

export async function requestMicrophonePermission(): Promise<{
  granted: boolean;
  error?: string;
}> {
  console.log('[FTM-DEBUG] Audio - Requesting microphone permission');

  const { status } = await Audio.requestPermissionsAsync();

  console.log('[FTM-DEBUG] Audio - Microphone permission result', { status });

  if (status !== 'granted') {
    return {
      granted: false,
      error:   'Permission microphone refusée. Activez-la dans les réglages.',
    };
  }
  return { granted: true };
}

// ─── ENREGISTREMENT ────────────────────────────────────────────────────────────

export async function startRecording(): Promise<{ success?: boolean; error?: string }> {
  console.log('[FTM-DEBUG] Audio - Starting recording');

  const perms = await requestMicrophonePermission();
  if (!perms.granted) return { error: perms.error };

  try {
    await Audio.setAudioModeAsync({
      allowsRecordingIOS:   true,
      playsInSilentModeIOS: true,
    });

    const { recording } = await Audio.Recording.createAsync(
      Audio.RecordingOptionsPresets.HIGH_QUALITY
    );

    recordingInstance = recording;

    console.log('[FTM-DEBUG] Audio - Recording started', {
      format: 'aac/m4a', sampleRate: '44100 Hz', maxDuration: '120s',
    });
    return { success: true };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Audio - Start recording error', { err: msg });
    return { error: "Impossible de démarrer l'enregistrement." };
  }
}

export async function stopRecording(): Promise<{
  success?: boolean;
  uri?: string;
  duration?: number;
  size?: number;
  mimeType?: string;
  error?: string;
}> {
  console.log('[FTM-DEBUG] Audio - Stopping recording');

  if (!recordingInstance) {
    return { error: 'Aucun enregistrement en cours.' };
  }

  try {
    await recordingInstance.stopAndUnloadAsync();
    const uri    = recordingInstance.getURI();
    const status = await recordingInstance.getStatusAsync();
    recordingInstance = null;

    await Audio.setAudioModeAsync({ allowsRecordingIOS: false });

    const duration = Math.round(
      ('durationMillis' in status ? (status as { durationMillis: number }).durationMillis : 0) / 1000
    );

    console.log('[FTM-DEBUG] Audio - Recording stopped', {
      duration: duration + 's',
      uri:      uri?.substring(0, 60),
    });

    if (duration < 1) {
      console.log('[FTM-DEBUG] Audio - Recording too short', { duration });
      return { error: 'Message trop court. Maintenez appuyé pour enregistrer.' };
    }

    return {
      success:  true,
      uri:      uri || '',
      duration,
      size:     0,
      mimeType: 'audio/m4a',
    };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Audio - Stop recording error', { err: msg });
    return { error: "Erreur lors de l'arrêt de l'enregistrement." };
  }
}

// ─── UPLOAD STORAGE ────────────────────────────────────────────────────────────

export async function uploadVoiceMessage(
  missionId: string,
  senderProfileId: string,
  localUri: string,
  mimeType: string,
  duration: number
): Promise<{ success?: boolean; url?: string; filePath?: string; duration?: number; error?: string }> {
  const timestamp = Date.now();
  const extension = mimeType.includes('m4a') || mimeType.includes('aac') ? 'm4a' : 'wav';
  const filePath  = `missions/${missionId}/${senderProfileId}_${timestamp}.${extension}`;

  console.log('[FTM-DEBUG] Audio - Uploading voice message', {
    missionId, senderProfileId, filePath, mimeType, duration: duration + 's',
  });

  try {
    const response = await fetch(localUri);
    const blob     = await response.blob();

    const { error: uploadError } = await supabase.storage
      .from('voice-messages')
      .upload(filePath, blob, { contentType: mimeType, upsert: false });

    if (uploadError) {
      console.log('[FTM-DEBUG] Audio - Upload error', {
        error: uploadError.message, filePath,
      });
      return { error: uploadError.message };
    }

    const { data: signedData, error: signError } = await supabase.storage
      .from('voice-messages')
      .createSignedUrl(filePath, 7 * 24 * 3600);

    if (signError) {
      console.log('[FTM-DEBUG] Audio - Signed URL error', { error: signError.message });
      return { error: 'Message uploadé mais URL non générée.' };
    }

    console.log('[FTM-DEBUG] Audio - Voice message uploaded successfully', {
      missionId, filePath, duration: duration + 's',
    });

    return { success: true, url: signedData.signedUrl, filePath, duration };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Audio - Upload exception', { err: msg });
    return { error: 'Erreur réseau lors de l\'envoi du message.' };
  }
}

// ─── LECTURE ───────────────────────────────────────────────────────────────────

export async function playVoiceMessage(
  url: string,
  onProgress?: (progress: number) => void,
  onComplete?: () => void
): Promise<{ success?: boolean; error?: string }> {
  console.log('[FTM-DEBUG] Audio - Playing voice message', {
    url: url.substring(0, 60) + '...',
  });

  try {
    if (soundInstance) {
      await soundInstance.unloadAsync();
      soundInstance = null;
    }

    const { sound } = await Audio.Sound.createAsync(
      { uri: url },
      { shouldPlay: true },
      (status) => {
        if ('isLoaded' in status && status.isLoaded) {
          if (onProgress && status.durationMillis) {
            onProgress(status.positionMillis / status.durationMillis);
          }
          if (status.didJustFinish) {
            console.log('[FTM-DEBUG] Audio - Playback completed');
            if (onComplete) onComplete();
          }
        }
      }
    );

    soundInstance = sound;

    console.log('[FTM-DEBUG] Audio - Playback started');
    return { success: true };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log('[FTM-DEBUG] Audio - Play exception', { err: msg });
    return { error: 'Impossible de lire le message.' };
  }
}

export async function stopPlayback(): Promise<void> {
  console.log('[FTM-DEBUG] Audio - Stopping playback');
  if (soundInstance) {
    await soundInstance.stopAsync();
    await soundInstance.unloadAsync();
    soundInstance = null;
  }
}

// ─── CHARGER LES MESSAGES D'UNE MISSION ───────────────────────────────────────

export async function loadVoiceMessages(missionId: string): Promise<{
  success?: boolean;
  messages?: {
    id: string;
    fileName: string;
    url: string | null;
    sender: string;
    timestamp: Date | null;
    size: number;
  }[];
  error?: unknown;
}> {
  console.log('[FTM-DEBUG] Audio - Loading voice messages', { missionId });

  const { data, error } = await supabase.storage
    .from('voice-messages')
    .list(`missions/${missionId}`, {
      sortBy: { column: 'created_at', order: 'asc' },
    });

  if (error) {
    console.log('[FTM-DEBUG] Audio - Load messages error', { error: error.message });
    return { error };
  }

  const messagesWithUrls = await Promise.all(
    (data || []).map(async (file) => {
      const { data: signed } = await supabase.storage
        .from('voice-messages')
        .createSignedUrl(`missions/${missionId}/${file.name}`, 3600);

      const parts    = file.name.split('_');
      const senderPart = parts[0];
      const tsPart   = parts[1]?.split('.')[0];

      return {
        id:        file.id,
        fileName:  file.name,
        url:       signed?.signedUrl ?? null,
        sender:    senderPart,
        timestamp: tsPart ? new Date(parseInt(tsPart)) : null,
        size:      (file.metadata as { size?: number })?.size || 0,
      };
    })
  );

  console.log('[FTM-DEBUG] Audio - Voice messages loaded', {
    missionId, count: messagesWithUrls.length,
  });

  return { success: true, messages: messagesWithUrls };
}
