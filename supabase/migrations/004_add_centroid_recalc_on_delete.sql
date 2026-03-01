-- Migration: Recalculate category centroid when an entry is deleted.
-- Without this, the centroid drifts because it was built with a running
-- average that included the deleted entry's embedding.

CREATE OR REPLACE FUNCTION recalculate_category_centroid_on_delete()
RETURNS TRIGGER AS $$
DECLARE
  dim        INTEGER;
  avg_vector DOUBLE PRECISION[];
  remaining  INTEGER;
BEGIN
  -- Only act if the deleted entry had a category
  IF OLD.category_id IS NULL THEN
    RETURN OLD;
  END IF;

  -- Count remaining entries with embeddings in this category
  SELECT COUNT(*) INTO remaining
  FROM entries
  WHERE category_id = OLD.category_id
    AND id != OLD.id
    AND embedding_vector IS NOT NULL;

  IF remaining = 0 THEN
    -- No entries left: clear the centroid
    UPDATE categories
    SET embedding_centroid = NULL
    WHERE id = OLD.category_id;
  ELSE
    -- Determine embedding dimension from any remaining entry
    SELECT array_length(embedding_vector, 1) INTO dim
    FROM entries
    WHERE category_id = OLD.category_id
      AND id != OLD.id
      AND embedding_vector IS NOT NULL
    LIMIT 1;

    -- Compute element-wise average across all remaining entries
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
