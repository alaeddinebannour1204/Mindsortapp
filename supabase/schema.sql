-- Mindsortapp Supabase Schema (unified)
-- Run this in the Supabase SQL Editor to recreate the full schema.
-- WARNING: This drops existing tables. Backup data first if needed.

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing objects (reverse dependency order)
DROP TABLE IF EXISTS entries CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- =============================================================================
-- CATEGORIES
-- =============================================================================

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    is_user_created BOOLEAN NOT NULL DEFAULT true,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    entry_count INTEGER NOT NULL DEFAULT 0,
    color TEXT,
    embedding_centroid DOUBLE PRECISION[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_updated TIMESTAMPTZ NOT NULL DEFAULT now(),
    latest_entry_title TEXT,
    note_body TEXT NOT NULL DEFAULT '',
    rich_note_body JSONB
);

CREATE INDEX idx_categories_user_id ON categories(user_id);
CREATE INDEX idx_categories_last_updated ON categories(last_updated DESC);

-- RLS
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own categories"
    ON categories FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own categories"
    ON categories FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own categories"
    ON categories FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own categories"
    ON categories FOR DELETE
    USING (auth.uid() = user_id);

-- Trigger: set user_id from JWT when not provided
CREATE OR REPLACE FUNCTION set_category_user_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_id IS NULL THEN
        NEW.user_id := auth.uid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_set_category_user_id
    BEFORE INSERT ON categories
    FOR EACH ROW
    EXECUTE FUNCTION set_category_user_id();

-- =============================================================================
-- ENTRIES
-- =============================================================================

CREATE TABLE entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transcript TEXT NOT NULL,
    title TEXT,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    color TEXT,
    embedding_vector DOUBLE PRECISION[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_updated TIMESTAMPTZ NOT NULL DEFAULT now(),
    locale TEXT,
    category_name TEXT,
    audio_url TEXT,
    is_pending BOOLEAN NOT NULL DEFAULT true,
    seen_at TIMESTAMPTZ
);

CREATE INDEX idx_entries_user_id ON entries(user_id);
CREATE INDEX idx_entries_category_id ON entries(category_id);
CREATE INDEX idx_entries_created_at ON entries(created_at DESC);
CREATE INDEX idx_entries_last_updated ON entries(last_updated DESC);

-- RLS
ALTER TABLE entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own entries"
    ON entries FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own entries"
    ON entries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own entries"
    ON entries FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own entries"
    ON entries FOR DELETE
    USING (auth.uid() = user_id);

-- Trigger: set user_id from JWT when not provided
CREATE OR REPLACE FUNCTION set_entry_user_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_id IS NULL THEN
        NEW.user_id := auth.uid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_set_entry_user_id
    BEFORE INSERT ON entries
    FOR EACH ROW
    EXECUTE FUNCTION set_entry_user_id();

-- =============================================================================
-- TRIGGERS: Keep category_name in sync when category_id changes
-- =============================================================================

CREATE OR REPLACE FUNCTION sync_entry_category_name()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.category_id IS NOT NULL THEN
        SELECT name INTO NEW.category_name
        FROM categories
        WHERE id = NEW.category_id;
    ELSE
        NEW.category_name := NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_entry_category_name
    BEFORE INSERT OR UPDATE OF category_id
    ON entries
    FOR EACH ROW
    EXECUTE FUNCTION sync_entry_category_name();

-- =============================================================================
-- TRIGGER: Update last_updated on category change
-- =============================================================================

CREATE OR REPLACE FUNCTION update_category_last_updated()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_category_last_updated
    BEFORE UPDATE ON categories
    FOR EACH ROW
    EXECUTE FUNCTION update_category_last_updated();

-- =============================================================================
-- TRIGGER: Update last_updated on entry change
-- =============================================================================

CREATE OR REPLACE FUNCTION update_entry_last_updated()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_entry_last_updated
    BEFORE UPDATE ON entries
    FOR EACH ROW
    EXECUTE FUNCTION update_entry_last_updated();

-- =============================================================================
-- TRIGGER: Recalculate category centroid when an entry is deleted
-- =============================================================================

CREATE OR REPLACE FUNCTION recalculate_category_centroid_on_delete()
RETURNS TRIGGER AS $$
DECLARE
  dim        INTEGER;
  avg_vector DOUBLE PRECISION[];
  remaining  INTEGER;
BEGIN
  IF OLD.category_id IS NULL THEN
    RETURN OLD;
  END IF;

  SELECT COUNT(*) INTO remaining
  FROM entries
  WHERE category_id = OLD.category_id
    AND id != OLD.id
    AND embedding_vector IS NOT NULL;

  IF remaining = 0 THEN
    UPDATE categories
    SET embedding_centroid = NULL
    WHERE id = OLD.category_id;
  ELSE
    SELECT array_length(embedding_vector, 1) INTO dim
    FROM entries
    WHERE category_id = OLD.category_id
      AND id != OLD.id
      AND embedding_vector IS NOT NULL
    LIMIT 1;

    SELECT ARRAY(
      SELECT AVG(embedding_vector[idx])
      FROM entries,
           generate_series(1, dim) AS idx
      WHERE category_id = OLD.category_id
        AND id != OLD.id
        AND embedding_vector IS NOT NULL
      GROUP BY idx
      ORDER BY idx
    ) INTO avg_vector;

    UPDATE categories
    SET embedding_centroid = avg_vector
    WHERE id = OLD.category_id;
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recalc_centroid_on_entry_delete
  BEFORE DELETE ON entries
  FOR EACH ROW
  EXECUTE FUNCTION recalculate_category_centroid_on_delete();

-- =============================================================================
-- RPC: match_category (embedding-based category matching)
-- =============================================================================

CREATE OR REPLACE FUNCTION match_category(
  query_embedding DOUBLE PRECISION[],
  match_user_id UUID,
  match_threshold DOUBLE PRECISION DEFAULT 0.60
)
RETURNS TABLE (id UUID, name TEXT, similarity DOUBLE PRECISION)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.name,
    (
      (SELECT SUM(a * b) FROM unnest(c.embedding_centroid, query_embedding) AS t(a, b))
      /
      NULLIF(
        SQRT((SELECT SUM(a * a) FROM unnest(c.embedding_centroid) AS t(a)))
        *
        SQRT((SELECT SUM(b * b) FROM unnest(query_embedding) AS t(b))),
        0
      )
    ) AS similarity
  FROM categories c
  WHERE c.user_id = match_user_id
    AND c.is_archived = false
    AND c.embedding_centroid IS NOT NULL
    AND array_length(c.embedding_centroid, 1) = array_length(query_embedding, 1)
    AND (
      (SELECT SUM(a * b) FROM unnest(c.embedding_centroid, query_embedding) AS t(a, b))
      /
      NULLIF(
        SQRT((SELECT SUM(a * a) FROM unnest(c.embedding_centroid) AS t(a)))
        *
        SQRT((SELECT SUM(b * b) FROM unnest(query_embedding) AS t(b))),
        0
      )
    ) >= match_threshold
  ORDER BY similarity DESC
  LIMIT 1;
END;
$$;

-- =============================================================================
-- AUDIO STORAGE
-- =============================================================================

-- Create the "audio" storage bucket (private per user)
INSERT INTO storage.buckets (id, name, public)
VALUES ('audio', 'audio', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can upload their own audio"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'audio'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can read their own audio"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'audio'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Service role can read all audio"
  ON storage.objects FOR SELECT
  TO service_role
  USING (bucket_id = 'audio');

CREATE POLICY "Users can delete their own audio"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'audio'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Service role can delete all audio"
  ON storage.objects FOR DELETE
  TO service_role
  USING (bucket_id = 'audio');

-- Scheduled cleanup: invoke cleanup-audio edge function every hour
-- Requires pg_cron and pg_net extensions (enabled by default on Supabase Pro)
SELECT cron.schedule(
  'cleanup-audio',
  '0 * * * *',
  $$SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/cleanup-audio',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  )$$
);
