-- Migration: Add embedding and intent columns for process-entry / search-entries
-- Run this if you already have the schema and process-entry fails with
-- "Could not find the 'embedding_centroid' column".

ALTER TABLE categories
    ADD COLUMN IF NOT EXISTS embedding_centroid DOUBLE PRECISION[];

ALTER TABLE entries
    ADD COLUMN IF NOT EXISTS embedding_vector DOUBLE PRECISION[],
    ADD COLUMN IF NOT EXISTS intent_labels TEXT[];
