-- Create voice-messages storage bucket
-- Voice messages exchanged between client and driver during a mission
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'voice-messages',
  'voice-messages',
  false,
  5242880,
  ARRAY['audio/m4a', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'audio/x-m4a']
);
