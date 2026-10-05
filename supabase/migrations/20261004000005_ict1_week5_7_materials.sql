-- MIOW-LMS: ICT1 — add Week 5-7 lecture slides + Prelim Exam coverage (Weeks 1-7)
--
-- Scope: course code 'ICT1' ONLY. TVE100 is never read for writes and never
-- modified. Every statement is keyed by the ICT1 course id resolved from
-- public.courses WHERE code = 'ICT1' (never a hard-coded uuid — the course id
-- is gen_random_uuid() per environment, see 20261003000002_seed_it10_ict1.sql).
--
-- Why this shape (mirrors the app exactly — nothing invented):
--   * The app has NO `materials` table. Course files live as `attachments`
--     jsonb rows on `assignments`/`quizzes` and are surfaced by MaterialManager
--     (src/components/courses/material-manager.tsx:16; used at
--     assignments-section.tsx:74, worksheets-section.tsx:84 and the edit
--     modals). So the 3 lecture files are attached to a real ICT1 assignment.
--   * attachments: jsonb array of {name, url, size, type, path}
--     (src/lib/server/materials.server.ts:44,136-142; src/lib/lms.ts:240-246;
--     attachmentMeta in src/lib/server/schemas.server.ts:22-28).
--   * path: '<course_id>/material_<epoch_ms>_<8hex>.<ext>'
--     (materials.server.ts:129-135). Storage object lives in bucket
--     'course-materials' (materials.server.ts:12): Supabase Storage in
--     production, local filesystem STORAGE_PATH/storage/course-materials/<path>
--     locally (src/integrations/db/storage.ts:1-9,
--     src/integrations/db/client.server.ts:88-91).
--   * url: '/api/public/material?p=' || encodeURIComponent(path) =
--     materialUrlForPath (materials.server.ts:46-48). For these paths the only
--     encoded character is '/' -> '%2F', so the SQL-built url is byte-identical
--     to the app's.
--   * component_type enum: 'written_work' | 'performance_task' |
--     'quarterly_exam' (src/lib/lms.ts:216). No enum value fits "materials";
--     the carrier assignment uses 'written_work'.
--   * Soft delete: deleted_at timestamptz NULL = active; all reads filter
--     deleted_at IS NULL (quizzes.server.ts:11), so soft-deleted rows are left
--     alone (a deliberate teacher deletion is never resurrected).
--
-- What it does (all ICT1-only):
--   (a) Upserts ONE assignment titled 'Week 5-7 Lecture Materials' carrying the
--       3 lecture slides as attachments. Present = same case-insensitive title
--       OR an existing attachment with one of our storage paths, so re-runs can
--       never duplicate. If present, attachments are merged (union by path) and
--       a NULL/empty description is filled in; existing description text is
--       never overwritten.
--   (b) Every active ICT1 row (assignments + quizzes) titled ILIKE '%prelim%'
--       (the Prelim Exam; in production it exists because 20261004000004 clones
--       it from TVE100 first):
--         * description gains the line "Coverage: Weeks 1-7" — appended to any
--           existing text (never destroyed); skipped when the line is already
--           there (idempotent).
--         * the same 3 lecture attachments are merged into the row's
--           attachments (union by path; existing attachments preserved) — that
--           is where the app shows exam materials (MaterialManager above).
--       NOTE on quizzes: public.quizzes has NO description column in any
--       migration of this repo (title/attachments/retake/score-release fields
--       only). If a description column is ever present, the line is merged into
--       it; otherwise the coverage is surfaced in the only free text a quiz
--       has — the title — as an additive suffix " (Coverage: Weeks 1-7)",
--       applied only when the title does not already mention "week". Both
--       branches are idempotent and preserve all pre-existing text.
--   (c) No-op everywhere else: if ICT1 is missing, the block raises a NOTICE
--       and returns; if no Prelim row exists yet (local DB before/without the
--       clone), (b) simply matches zero rows and leaves a correct guarded
--       UPDATE for when the row appears.
--
-- Files (attached by name/size/type; binary objects are placed in the
-- 'course-materials' bucket out-of-band — local copies under ./storage/, prod
-- via /tmp/opencode/upload-ict1-materials.mjs):
--   ICT1_Week5 Online Collaboration Tools.pptx   85918 bytes
--   ICT1_Week6 Learning Management Systems.pptx  79130 bytes
--   ICT1_Week7 Multimedia in Education.pptx      82712 bytes
--   type: application/vnd.openxmlformats-officedocument.presentationml.presentation
--
-- Idempotent: safe to run any number of times (also outside _migrations
-- bookkeeping). Verified locally with fixture rows + re-run no-op check.

DO $ict1_week5_7_materials$
DECLARE
  v_course       uuid;
  v_atts         jsonb := '[]'::jsonb;   -- the 3 lecture attachments for THIS env
  r              record;
  r2             record;
  v_path         text;
  v_existing     jsonb;
  v_merged       jsonb;
  v_desc         text;
  v_title        text;
  v_asg_ins      integer := 0;
  v_asg_upd      integer := 0;
  v_qz_upd       integer := 0;
  v_prelim_hits  integer := 0;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';

  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_week5_7_materials: course ICT1 missing - nothing to do';
    RETURN;
  END IF;

  -- ── Build the 3 attachment objects, paths prefixed with THIS environment's
  --    ICT1 id (matches materials.server.ts:129-135 naming) ─────────────────
  FOR r2 IN
    SELECT * FROM (VALUES
      ('ICT1_Week5 Online Collaboration Tools.pptx',  'material_1759632000000_a1b2c3d4.pptx', 85918),
      ('ICT1_Week6 Learning Management Systems.pptx', 'material_1759632001000_b2c3d4e5.pptx', 79130),
      ('ICT1_Week7 Multimedia in Education.pptx',     'material_1759632002000_c3d4e5f6.pptx', 82712)
    ) AS t(fname, fsuffix, fsize)
  LOOP
    v_path := v_course::text || '/' || r2.fsuffix;
    v_atts := v_atts || jsonb_build_array(jsonb_build_object(
      'name', r2.fname,
      'url',  '/api/public/material?p=' || replace(v_path, '/', '%2F'),
      'size', r2.fsize,
      'type', 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'path', v_path
    ));
  END LOOP;

  -- ── (a) 'Week 5-7 Lecture Materials' assignment on ICT1 ──────────────────
  FOR r IN
    SELECT id, description, attachments
    FROM public.assignments
    WHERE course_id = v_course
      AND deleted_at IS NULL
      AND (
        lower(btrim(title)) = 'week 5-7 lecture materials'
        OR EXISTS (
          SELECT 1 FROM jsonb_array_elements(attachments) e
          WHERE e->>'path' IN (
            v_course::text || '/material_1759632000000_a1b2c3d4.pptx',
            v_course::text || '/material_1759632001000_b2c3d4e5.pptx',
            v_course::text || '/material_1759632002000_c3d4e5f6.pptx'
          )
        )
      )
  LOOP
    v_merged := COALESCE(r.attachments, '[]'::jsonb) || (
      SELECT COALESCE(jsonb_agg(n), '[]'::jsonb)
      FROM jsonb_array_elements(v_atts) n
      WHERE NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(COALESCE(r.attachments, '[]'::jsonb)) e
        WHERE e->>'path' = n->>'path'
      )
    );
    v_desc := r.description;
    IF v_desc IS NULL OR btrim(v_desc) = '' THEN
      v_desc := 'Lecture slides for Weeks 5-7: Week 5 - Online Collaboration Tools, '
             || 'Week 6 - Learning Management Systems, Week 7 - Multimedia in Education.';
    END IF;
    UPDATE public.assignments
    SET attachments = v_merged, description = v_desc
    WHERE id = r.id;
    v_asg_upd := v_asg_upd + 1;
  END LOOP;

  IF v_asg_upd = 0 THEN
    INSERT INTO public.assignments
      (course_id, title, description, total_points, component_type, attachments)
    VALUES (
      v_course,
      'Week 5-7 Lecture Materials',
      'Lecture slides for Weeks 5-7: Week 5 - Online Collaboration Tools, '
        || 'Week 6 - Learning Management Systems, Week 7 - Multimedia in Education.',
      100,
      'written_work',
      v_atts
    );
    v_asg_ins := 1;
  END IF;

  -- ── (b1) Prelim rows on ICT1 ASSIGNMENTS: coverage line + attachments ────
  FOR r IN
    SELECT id, title, description, attachments
    FROM public.assignments
    WHERE course_id = v_course
      AND deleted_at IS NULL
      AND title ILIKE '%prelim%'
  LOOP
    v_prelim_hits := v_prelim_hits + 1;
    v_merged := COALESCE(r.attachments, '[]'::jsonb) || (
      SELECT COALESCE(jsonb_agg(n), '[]'::jsonb)
      FROM jsonb_array_elements(v_atts) n
      WHERE NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(COALESCE(r.attachments, '[]'::jsonb)) e
        WHERE e->>'path' = n->>'path'
      )
    );
    v_desc := r.description;
    IF v_desc IS NULL OR v_desc !~* 'weeks?[[:space:]]*1[[:space:]]*-[[:space:]]*7' THEN
      IF v_desc IS NULL OR btrim(v_desc) = '' THEN
        v_desc := 'Coverage: Weeks 1-7';
      ELSE
        v_desc := btrim(v_desc) || E'\n\nCoverage: Weeks 1-7';
      END IF;
    END IF;
    UPDATE public.assignments
    SET description = v_desc, attachments = v_merged
    WHERE id = r.id;
    v_asg_upd := v_asg_upd + 1;
  END LOOP;

  -- ── (b2) Prelim rows on ICT1 QUIZZES: coverage line + attachments ────────
  FOR r IN
    SELECT id, title, attachments
    FROM public.quizzes
    WHERE course_id = v_course
      AND deleted_at IS NULL
      AND title ILIKE '%prelim%'
  LOOP
    v_prelim_hits := v_prelim_hits + 1;
    v_merged := COALESCE(r.attachments, '[]'::jsonb) || (
      SELECT COALESCE(jsonb_agg(n), '[]'::jsonb)
      FROM jsonb_array_elements(v_atts) n
      WHERE NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(COALESCE(r.attachments, '[]'::jsonb)) e
        WHERE e->>'path' = n->>'path'
      )
    );

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'quizzes' AND column_name = 'description'
    ) THEN
      -- Future-proof: if quizzes ever grows a description column, merge there
      -- (statement is only prepared/executed inside this branch).
      UPDATE public.quizzes q
      SET description =
        CASE
          WHEN q.description IS NULL OR q.description !~* 'weeks?[[:space:]]*1[[:space:]]*-[[:space:]]*7'
            THEN CASE
              WHEN q.description IS NULL OR btrim(q.description) = '' THEN 'Coverage: Weeks 1-7'
              ELSE btrim(q.description) || E'\n\nCoverage: Weeks 1-7'
            END
          ELSE q.description
        END,
        attachments = v_merged
      WHERE q.id = r.id;
    ELSE
      -- No description column in this schema: surface the coverage in the only
      -- free text a quiz row has — an additive title suffix, only when the
      -- title does not already mention "week" (idempotent, text preserved).
      v_title := r.title;
      IF v_title !~* 'week' THEN
        v_title := v_title || ' (Coverage: Weeks 1-7)';
      END IF;
      UPDATE public.quizzes
      SET title = v_title, attachments = v_merged
      WHERE id = r.id;
    END IF;
    v_qz_upd := v_qz_upd + 1;
  END LOOP;

  RAISE NOTICE
    'ict1_week5_7_materials: assignment inserted %, assignment rows updated %, quiz rows updated %, prelim rows matched %',
    v_asg_ins, v_asg_upd, v_qz_upd, v_prelim_hits;
END $ict1_week5_7_materials$;
