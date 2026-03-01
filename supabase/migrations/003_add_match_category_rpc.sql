-- Migration: Add match_category RPC for embedding-based category matching.
-- Called by the process-entry edge function to find the most semantically
-- similar existing category using cosine similarity against category centroids.

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
    -- Cosine similarity: dot(A,B) / (|A| * |B|)
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
