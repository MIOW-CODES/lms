-- MIOW-LMS: Standardize student credentials
--
-- College rosters imported from class lists (e.g. TVE100 Section B8) arrive with
-- `email = NULL` and no PIN, so those students cannot sign in. This migration
-- backfills the institutional identity for any student still missing credentials:
--
--   * email      -> firstname.lastname@g.msuiit.edu.ph
--   * PIN        -> the student's own student_id (e.g. 2025-2517)
--   * pin_hash   -> bcrypt(student_id)
--
-- RFID is intentionally left untouched (no credential is minted for RFID yet).
--
-- Scope: only rows where email OR pin is missing/empty. Existing working
-- accounts (e.g. the Grade 10 seed which already has an email and a PIN) are
-- never modified, which keeps this migration idempotent and non-disruptive.
--
-- Name -> email rules (examples from the B8 roster):
--   'Alastra, Gel Lord B.'          -> gellord.alastra@g.msuiit.edu.ph
--   'Cutad, Craciana Lury P.'       -> cracianalury.cutad@g.msuiit.edu.ph
--   'De Guzman, Kris Lawrence A.'   -> krislawrence.deguzman@g.msuiit.edu.ph
--   'Tañola, Jennifer U.'           -> jennifer.tanola@g.msuiit.edu.ph
--   'Yu Tiamco, Zharich B.'         -> zharich.yutiamco@g.msuiit.edu.ph
--   'Salahay, Jay-Boy G.'           -> jayboy.salahay@g.msuiit.edu.ph

-- pgcrypto lives in the `extensions` schema on Supabase; reference it explicitly.
create extension if not exists pgcrypto with schema extensions;

-- Lowercase + strip diacritics + keep only [a-z0-9]. Used for both name parts.
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

with derived as (
  select
    p.id,
    p.student_id,
    -- First + middle names: drop a trailing single-letter middle initial (" B.").
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
    and p.student_id is not null
    and btrim(p.student_id) <> ''
    and position(',' in p.full_name) > 0
    and (
      p.email is null or btrim(p.email) = ''
      or p.pin is null or btrim(p.pin) = ''
      or p.pin_hash is null or btrim(p.pin_hash) = ''
    )
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
    -- Disambiguate same-name students deterministically with a numeric suffix.
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
  )
from resolved res
where p.id = res.id;

-- Self-document the login contract for future maintainers.
comment on column public.profiles.pin is
  'Legacy plaintext PIN. Students: their student_id. Auto-upgraded to pin_hash on first login.';
comment on column public.profiles.pin_hash is
  'bcrypt PIN. Students authenticate with their student_id as the PIN.';
