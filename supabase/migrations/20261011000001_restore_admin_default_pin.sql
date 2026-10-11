-- Restore documented default sign-in for the web-developer admin account.
--
-- Background: josephalan.vergara@g.msuiit.edu.ph drifted away from the
-- documented default PIN (README "Default PIN" table: admin web developer =
-- '1234'): the stored pin_hash matched no known credential, so sign-in
-- returned "Invalid credentials" and the admin could not re-authenticate.
-- With no usable session, every gated page kept failing behind its loading
-- state ("Loading courses…" / "Loading questions…").
--
-- Fix: reset this one account's PIN to the documented default '1234' via the
-- legacy plaintext column and clear any lockout counters. The app's own
-- sign-in path re-hashes the plaintext PIN to bcryptjs on first successful
-- login (pin = NULL, pin_hash = <bcrypt('1234')>), which keeps the hash
-- format consistent with every other credential the app writes.
--
-- Idempotent: touches only this single row; no other account, table or grant
-- is modified. Signing in with a changed PIN afterwards is unaffected.

UPDATE public.profiles
   SET pin = '1234',
       pin_hash = NULL,
       failed_login_attempts = 0,
       locked_until = NULL
 WHERE lower(coalesce(email, '')) = 'josephalan.vergara@g.msuiit.edu.ph'
   AND deleted_at IS NULL;

DO $$
DECLARE
  reset_count int;
BEGIN
  GET DIAGNOSTICS reset_count = ROW_COUNT;
  RAISE NOTICE 'admin default PIN restore: % row(s) reset', reset_count;
END $$;
