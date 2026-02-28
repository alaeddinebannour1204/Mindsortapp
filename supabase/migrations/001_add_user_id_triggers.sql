-- Migration: Add triggers to set user_id from auth.uid() when not provided
-- Run this if you already have the schema and are getting RLS violations on insert.
-- The app doesn't send user_id; these triggers set it from the JWT.

-- Categories
CREATE OR REPLACE FUNCTION set_category_user_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_id IS NULL THEN
        NEW.user_id := auth.uid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_set_category_user_id ON categories;
CREATE TRIGGER trg_set_category_user_id
    BEFORE INSERT ON categories
    FOR EACH ROW
    EXECUTE FUNCTION set_category_user_id();

-- Entries
CREATE OR REPLACE FUNCTION set_entry_user_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_id IS NULL THEN
        NEW.user_id := auth.uid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_set_entry_user_id ON entries;
CREATE TRIGGER trg_set_entry_user_id
    BEFORE INSERT ON entries
    FOR EACH ROW
    EXECUTE FUNCTION set_entry_user_id();
