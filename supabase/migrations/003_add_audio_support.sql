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

-- RLS: service role can delete all audio (for cleanup edge function)
CREATE POLICY "Service role can delete all audio"
  ON storage.objects FOR DELETE
  TO service_role
  USING (bucket_id = 'audio');

-- Scheduled cleanup: invoke the cleanup-audio edge function every hour.
-- The function deletes storage objects AND nullifies audio_url in one pass.
-- Requires pg_cron and pg_net extensions (enabled by default on Supabase Pro).
SELECT cron.schedule(
  'cleanup-audio',
  '0 * * * *',  -- every hour
  $$SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/cleanup-audio',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  )$$
);
