-- Test account + admin PIN recovery (user request 2026-10-11).
--
-- 1. Create a dedicated staff test account:
--      test@g.msuiit.edu.ph / PIN '0916' (teacher role).
--    The plaintext PIN follows the legacy credential path: the app's sign-in
--    re-hashes it to bcrypt on first successful login, same as seeded staff.
--
-- 2. Re-verify the web-developer admin account's PIN:
--      josephalan.vergara@g.msuiit.edu.ph
--    If the stored bcrypt hash still verifies against '1234' (via pgcrypto
--    crypt()), leave it untouched — the user may have successfully signed in
--    already. Otherwise reset it to the documented default '1234' plaintext
--    (app re-hashes on next login) and clear lockout counters, same as
--    20261011000001.
--
-- Idempotent: ON CONFLICT DO NOTHING on insert; the admin UPDATE only fires
-- when the hash check fails. No other accounts, tables, grants, or RLS are
-- touched.

-- ── 1. Test account ─────────────────────────────────────────────────────────
insert into public.profiles (email, full_name, role, pin)
values ('test@g.msuiit.edu.ph', 'Test Account', 'teacher', '0916')
on conflict (email) do nothing;

-- ── 2. Admin PIN verify / reset ─────────────────────────────────────────────
update public.profiles
   set pin = '1234',
       pin_hash = null,
       failed_login_attempts = 0,
       locked_until = null
 where lower(coalesce(email, '')) = 'josephalan.vergara@g.msuiit.edu.ph'
   and deleted_at is null
   and (
         pin_hash is null
      or extensions.crypt('1234', pin_hash) <> pin_hash
       );

DO $$
DECLARE
  admin_rows int;
  admin_locked int;
  test_rows int;
BEGIN
  select count(*) into admin_rows
    from public.profiles
   where lower(coalesce(email, '')) = 'josephalan.vergara@g.msuiit.edu.ph'
     and deleted_at is null
     and (pin_hash is null or extensions.crypt('1234', pin_hash) = pin_hash);
  select count(*) into test_rows
    from public.profiles
   where lower(coalesce(email, '')) = 'test@g.msuiit.edu.ph'
     and deleted_at is null
     and (pin_hash is null or extensions.crypt('0916', pin_hash) = pin_hash);
  select count(*) into admin_locked
    from public.profiles
   where lower(coalesce(email, '')) = 'josephalan.vergara@g.msuiit.edu.ph'
     and coalesce(failed_login_attempts, 0) > 0;
  raise notice 'test-account/admin-pin: admin default valid = %, test 0916 valid = %, admin stale fail counters = %',
               admin_rows, test_rows, admin_locked;
END $$;
