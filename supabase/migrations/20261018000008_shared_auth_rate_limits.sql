CREATE TABLE public.auth_rate_limits (
  bucket_key text PRIMARY KEY,
  failures integer NOT NULL DEFAULT 0 CHECK (failures >= 0),
  window_started_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.auth_rate_limits ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.auth_rate_limits TO service_role;

CREATE OR REPLACE FUNCTION public.check_auth_rate_limit(
  p_bucket_key text,
  p_max_failures integer,
  p_window_seconds integer
)
RETURNS TABLE (allowed boolean, remaining integer)
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT COALESCE(
    state.window_started_at <= now() - make_interval(secs => p_window_seconds)
      OR state.failures < p_max_failures,
    true
  ),
  GREATEST(0, p_max_failures - COALESCE(
    CASE WHEN state.window_started_at <= now() - make_interval(secs => p_window_seconds)
      THEN 0 ELSE state.failures END,
    0
  ))
  FROM (SELECT 1) seed
  LEFT JOIN public.auth_rate_limits state ON state.bucket_key = p_bucket_key;
$$;

CREATE OR REPLACE FUNCTION public.record_auth_rate_failure(
  p_bucket_key text,
  p_window_seconds integer
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  INSERT INTO public.auth_rate_limits (bucket_key, failures, window_started_at)
  VALUES (p_bucket_key, 1, now())
  ON CONFLICT (bucket_key) DO UPDATE SET
    failures = CASE
      WHEN public.auth_rate_limits.window_started_at <= now() - make_interval(secs => p_window_seconds)
      THEN 1 ELSE public.auth_rate_limits.failures + 1 END,
    window_started_at = CASE
      WHEN public.auth_rate_limits.window_started_at <= now() - make_interval(secs => p_window_seconds)
      THEN now() ELSE public.auth_rate_limits.window_started_at END;
$$;

CREATE OR REPLACE FUNCTION public.consume_auth_rate_attempt(
  p_bucket_key text,
  p_max_attempts integer,
  p_window_seconds integer
)
RETURNS TABLE (allowed boolean, remaining integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  next_count integer;
BEGIN
  INSERT INTO public.auth_rate_limits (bucket_key, failures, window_started_at)
  VALUES (p_bucket_key, 1, now())
  ON CONFLICT (bucket_key) DO UPDATE SET
    failures = CASE
      WHEN public.auth_rate_limits.window_started_at <= now() - make_interval(secs => p_window_seconds)
      THEN 1 ELSE public.auth_rate_limits.failures + 1 END,
    window_started_at = CASE
      WHEN public.auth_rate_limits.window_started_at <= now() - make_interval(secs => p_window_seconds)
      THEN now() ELSE public.auth_rate_limits.window_started_at END
  RETURNING failures INTO next_count;
  RETURN QUERY SELECT next_count <= p_max_attempts, GREATEST(0, p_max_attempts - next_count);
END;
$$;

CREATE OR REPLACE FUNCTION public.clear_auth_rate_limit(p_bucket_key text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  DELETE FROM public.auth_rate_limits WHERE bucket_key = p_bucket_key;
$$;

REVOKE ALL ON FUNCTION public.check_auth_rate_limit(text, integer, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_auth_rate_failure(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.consume_auth_rate_attempt(text, integer, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.clear_auth_rate_limit(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_auth_rate_limit(text, integer, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_auth_rate_failure(text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_auth_rate_attempt(text, integer, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.clear_auth_rate_limit(text) TO service_role;
