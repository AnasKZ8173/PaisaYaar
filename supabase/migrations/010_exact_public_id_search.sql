-- ============================================================================
-- PocketYaar — Exact Match Only for Public User ID Search
-- ============================================================================

CREATE OR REPLACE FUNCTION public.search_public_profiles(search_query TEXT)
RETURNS TABLE (
  id UUID,
  public_id TEXT,
  full_name TEXT,
  avatar_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cleaned TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  cleaned := lower(trim(COALESCE(search_query, '')));
  IF length(cleaned) < 4 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.public_id,
    p.full_name,
    p.avatar_url
  FROM public.profiles p
  WHERE p.profile_completed = true
    AND p.id <> auth.uid()
    AND p.public_id = cleaned
  LIMIT 1;
END;
$$;
