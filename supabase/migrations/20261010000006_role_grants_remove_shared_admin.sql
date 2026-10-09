-- Account governance (user request 2026-10-09):
--   1. Joseph Alan B. Vergara  -> admin (webapp developer)
--   2. Kent Alexis T. Alia     -> admin (webapp developer)
--   3. Dr. Alan L. Vergara     -> admin (Admin & Teacher; teacher routes accept role 'admin',
--                                   RLS current_profile_role() includes admin, his courses stay his)
--   4. Remove the shared admin@g.msuiit.edu.ph login account.
-- Idempotent: grants skip rows already 'admin'; the DELETE is a no-op when absent.

-- ── 1. Role grants ──────────────────────────────────────────────────────────
update public.profiles
   set role = 'admin'
 where role <> 'admin'
   and (
        lower(coalesce(email, '')) = 'josephalan.vergara@g.msuiit.edu.ph'
     or lower(coalesce(email, '')) = 'alan.vergara@g.msuiit.edu.ph'
     or lower(coalesce(email, '')) like 'kent.%'
     or lower(coalesce(email, '')) like '%.kent.%'
     or (
          lower(coalesce(full_name, '')) like '%kent%'
      and lower(coalesce(full_name, '')) like '%alia%'
     )
     or (
          lower(coalesce(full_name, '')) like '%vergara%'
      and (
            lower(coalesce(full_name, '')) like '%joseph alan%'
         or lower(coalesce(full_name, '')) like '%alan l.%'
          )
       )
   );

-- ── 2. Reassign retake-grant audit refs off the account being removed ───────
-- quiz_retake_grants.granted_by is FK → profiles with ON DELETE NO ACTION,
-- so re-point any rows at a surviving admin first (granted_by is nullable, and
-- step 1 has already promoted at least one admin in this same migration).
update public.quiz_retake_grants
   set granted_by = (
         select p.id
           from public.profiles p
          where p.role = 'admin'
            and lower(coalesce(p.email, '')) <> 'admin@g.msuiit.edu.ph'
          order by p.created_at
          limit 1
       )
 where granted_by in (
         select id from public.profiles where lower(coalesce(email, '')) = 'admin@g.msuiit.edu.ph'
       );

-- ── 3. Remove the shared admin account ──────────────────────────────────────
-- FK behaviour covers the rest: announcements.author_id → SET NULL,
-- sessions.profile_id → CASCADE (logs the shared session out everywhere),
-- quiz_retake_grants/quiz_score_overrides/grades audit refs → handled above/SET NULL.
delete from public.profiles
 where lower(coalesce(email, '')) = 'admin@g.msuiit.edu.ph';

-- ── 4. Visibility for `supabase db push` output ─────────────────────────────
do $$
declare
  admins int;
  shared_left int;
begin
  select count(*) into admins from public.profiles where role = 'admin';
  select count(*) into shared_left
    from public.profiles where lower(coalesce(email, '')) = 'admin@g.msuiit.edu.ph';
  raise notice 'role grants: admin count = %, admin@g rows remaining = %', admins, shared_left;
end $$;
