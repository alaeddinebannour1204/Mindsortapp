-- Mindsortapp Supabase Schema
-- Run this in the Supabase SQL Editor to recreate the full schema.
-- WARNING: This drops existing tables. Backup data first if needed.
--
-- process-entry 500: Ensure the Edge Function is invoked with the user's JWT
-- (not service role) so auth.uid() works in triggers. Or have the function
-- explicitly set user_id when inserting.

-- Enable UUID extension
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
    latest_entry_title TEXT
);

-- Index for user-scoped queries
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

-- Trigger: set user_id from JWT when not provided (app doesn't send user_id on insert)
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
    intent_labels TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_updated TIMESTAMPTZ NOT NULL DEFAULT now(),
    locale TEXT,
    category_name TEXT
);

-- Indexes
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

-- Trigger: set user_id from JWT when not provided (process-entry may not send user_id)
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
-- TRIGGER: Update last_updated on category rename
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
