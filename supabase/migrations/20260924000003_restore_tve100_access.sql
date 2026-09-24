-- MIOW-LMS: Restore TVE100 (Section B8) student access.
--
-- Symptom
-- -------
-- The 48 students imported by `20260923000001_seed_tve100_roster.sql` could not
-- sign in. Their rows arrived with `email = NULL`, no PIN and no `pin_hash`, so
-- every sign-in attempt failed. After 5 failures the account was additionally
-- locked for 15 minutes (`failed_login_attempts` + `locked_until`), which is the
-- "invalid because they exceeded the 5 limit attempts" report.
--
-- Fix
-- ---
--   1. Clear the transient login lockout for every B8 student.
--   2. Re-assert the standardized institutional credentials (same rules as
--      `20260924000000_standardize_student_credentials.sql`):
--         email    -> firstname.lastname@g.msuiit.edu.ph
--         PIN      -> the student's own student_id (bcrypt-hashed)
--      Existing working credentials are never overwritten (coalesce), so this
--      stays idempotent and safe to re-run.
--   3. Re-assert the enrollment in TVE100 (the seed's CROSS JOIN can miss a
--      student if the course row was created in a later statement ordering).
--
-- Scope: only `role = 'student' AND section = 'B8'` and non-deleted rows.

create extension if not exists pgcrypto with schema extensions;

-- Lowercase + strip diacritics + keep only [a-z0-9]. Mirrors the helper created
-- in 20260924000000; redefined here so this migration is self-contained.
create or replace function private.miow_slug(input text)
returns text
language sql
immutable
as $$
  select regexp_replace(
    translate(
      lower(coalesce(input, '')),
      'áàâäãåéèêëíìîïóòôöõúùûüñçýÿÁÀÂÄÃÅÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇÝ',
      'aaaaaaeeeeiiiiooooouuuuncyyAAAAAAEEEEIIIIOOOOOUUUUNCY'
    ),
    '[^a-z0-9]',
    '',
    'g'
  );
$$;

-- ── 1 + 2. Credentials + lockout reset ──────────────────────────────
with derived as (
  select
    p.id,
    p.student_id,
    private.miow_slug(
      regexp_replace(
        trim(substring(p.full_name from position(',' in p.full_name) + 1)),
        '\s+[A-Za-z]\.?\s*$',
        ''
      )
    ) as first_slug,
    private.miow_slug(trim(split_part(p.full_name, ',', 1))) as last_slug
  from public.profiles p
  where p.role = 'student'
    and p.deleted_at is null
    and p.section = 'B8'
    and p.student_id is not null
    and btrim(p.student_id) <> ''
    and position(',' in p.full_name) > 0
),
ranked as (
  select
    d.*,
    row_number() over (
      partition by d.first_slug, d.last_slug
      order by d.student_id
    ) as rn
  from derived d
  where d.first_slug <> '' and d.last_slug <> ''
),
resolved as (
  select
    r.id,
    r.student_id,
    r.first_slug
      || '.'
      || r.last_slug
      || case when r.rn > 1 then r.rn::text else '' end
      || '@g.msuiit.edu.ph' as email
  from ranked r
)
update public.profiles p
set
  email = coalesce(nullif(btrim(p.email), ''), res.email),
  pin = coalesce(nullif(btrim(p.pin), ''), res.student_id),
  pin_hash = coalesce(
    nullif(btrim(p.pin_hash), ''),
    extensions.crypt(res.student_id, extensions.gen_salt('bf', 10))
  ),
  failed_login_attempts = 0,
  locked_until = null
from resolved res
where p.id = res.id;

-- Unlock any B8 student not covered above (e.g. an incomplete name that still
-- needs its lockout cleared).
update public.profiles
set failed_login_attempts = 0,
    locked_until = null
where role = 'student'
  and section = 'B8'
  and deleted_at is null;

-- ── 3. Re-enroll every B8 student into TVE100 ───────────────────────
insert into public.enrollments (student_id, course_id)
select p.id, c.id
from public.profiles p
cross join public.courses c
where c.code = 'TVE100'
  and p.section = 'B8'
  and p.role = 'student'
  and p.deleted_at is null
on conflict (student_id, course_id) do nothing;
