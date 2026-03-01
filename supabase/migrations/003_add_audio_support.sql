-- Add audio_url column to entries table for storing Supabase Storage path
ALTER TABLE entries ADD COLUMN IF NOT EXISTS audio_url TEXT;

-- Create the "audio" storage bucket (public = false, files are private per user)
INSERT INTO storage.buckets (id, name, public)
VALUES ('audio', 'audio', false)
ON CONFLICT (id) DO NOTHING;

-- RLS: users can only upload to their own folder (userId/filename.m4a)
CREATE POLICY "Users can upload their own audio"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'audio'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- RLS: users can read their own audio files
CREATE POLICY "Users can read their own audio"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'audio'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- RLS: service role can read all audio (for edge functions / Whisper transcription)
CREATE POLICY "Service role can read all audio"
  ON storage.objects FOR SELECT
  TO service_role
  USING (bucket_id = 'audio');

-- RLS: allow deletion of own audio files (for 24h cleanup)
CREATE POLICY "Users can delete their own audio"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'audio'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Scheduled cleanup: clear audio_url on entries older than 24 hours.
-- Requires pg_cron extension (enabled by default on Supabase).
-- The actual storage object deletion is handled by a separate cron edge function
-- or Supabase Storage lifecycle rules.
SELECT cron.schedule(
  'cleanup-audio-urls',
  '0 * * * *',  -- every hour
  $$UPDATE entries SET audio_url = NULL WHERE audio_url IS NOT NULL AND created_at < now() - interval '24 hours'$$
);
