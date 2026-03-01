// Supabase Edge Function: cleanup-audio
// Called hourly by pg_cron. Finds entries with audio_url older than 24 hours,
// deletes the corresponding files from Supabase Storage, then nullifies the
// audio_url column.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async (req: Request) => {
  // Only allow POST (from cron) or OPTIONS (CORS preflight)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { status: 200 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Find entries with audio older than 24 hours
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { data: staleEntries, error: fetchError } = await supabase
    .from('entries')
    .select('id, audio_url')
    .not('audio_url', 'is', null)
    .lt('created_at', cutoff);

  if (fetchError) {
    console.error('Failed to fetch stale entries:', fetchError.message);
    return new Response(JSON.stringify({ error: fetchError.message }), { status: 500 });
  }

  if (!staleEntries || staleEntries.length === 0) {
    return new Response(JSON.stringify({ deleted: 0 }), { status: 200 });
  }

  // Delete storage objects
  const paths = staleEntries.map((e: { audio_url: string }) => e.audio_url);
  const { error: storageError } = await supabase.storage
    .from('audio')
    .remove(paths);

  if (storageError) {
    console.error('Failed to delete audio files:', storageError.message);
    // Continue to nullify URLs even if storage deletion partially failed
  }

  // Nullify audio_url on those entries
  const ids = staleEntries.map((e: { id: string }) => e.id);
  const { error: updateError } = await supabase
    .from('entries')
    .update({ audio_url: null })
    .in('id', ids);

  if (updateError) {
    console.error('Failed to nullify audio_url:', updateError.message);
    return new Response(JSON.stringify({ error: updateError.message }), { status: 500 });
  }

  console.log(`Cleaned up ${paths.length} audio files`);
  return new Response(JSON.stringify({ deleted: paths.length }), { status: 200 });
});
