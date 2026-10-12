-- ICT1 — attach each week's source material to its quiz (attachments backfill)
--
-- Problem: the ICT1 weekly quizzes (Quiz 1..7) and the FINAL EXAMINATION row have
-- empty `attachments`, so MaterialManager shows "no materials" for students. The
-- source files are ALREADY in Supabase storage: the PRELIM EXAMINATION quiz on
-- ICT1 carries all 7 source files as attachments.
--
-- Shape (src/lib/server/materials.server.ts:48):
--   attachments: jsonb array of {name, url, size, type, path}
--   served via   /api/public/material?p=<path> (materialUrlForPath)
--
-- Strategy: COPY WHOLE ATTACHMENT ELEMENTS from the prelim row, matched by
-- `e->>'name'` exactly. No re-upload, no URL rewriting — the copied elements keep
-- their url/path/size/type verbatim, so the existing storage objects stay valid.
-- Nothing is ever invented: if a source element is not in the prelim row, that
-- file is skipped with a NOTICE (no fabricated URL/path).
--
-- Idempotent / fully re-runnable:
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid); missing →
--     RAISE NOTICE + skip.
--   * Prelim source row: active quiz (deleted_at IS NULL) with
--     title ILIKE 'PRELIM EXAMINATION%' whose attachments is a non-empty jsonb
--     array, oldest first (ORDER BY created_at LIMIT 1). Not found / empty →
--     RAISE NOTICE + skip.
--   * Targets: active quizzes on ICT1 matched by EXACT title. For each, the
--     matched file elements are appended after removing any existing element with
--     the same name (replace-by-name). Unrelated pre-existing entries are kept —
--     nothing else is dropped. Setting the same value again yields the same array,
--     so re-running is a no-op in effect.
--   * Missing target quiz or missing source file element → RAISE NOTICE and
--     continue with the rest (graceful; never aborts the migration).
--   * RAISE NOTICE per quiz updated with kept/attached counts.
--
-- Mapping (target quiz exact title ← source file name(s) in the prelim row):
--   'Quiz 1' ← 'TVE100 Week1 Slide_Introduction to the Course.pdf'
--   'Quiz 2' ← 'TVE100 Week2 Slide_The Teacher as a Professional.pdf'
--   'Quiz 3' ← 'TVE100 Week3 Slide_The Teacher and the Community.pdf'
--   'Quiz 4' ← 'TVE100 Week4 Slides_Understanding School Culture.pdf'
--   'Quiz 5' ← 'ICT1_Week5 Online Collaboration Tools.pptx'
--   'Quiz 6' ← 'ICT1_Week6 Learning Management Systems.pptx'
--   'Quiz 7' ← 'ICT1_Week7 Multimedia in Education.pptx'
--   'FINAL EXAMINATION (Coverage: Weeks 1-7)' ← ALL 7 elements (same as prelim)

DO $ict1_attach_week_materials$
DECLARE
  v_course        uuid;
  v_prelim        uuid;
  v_prelim_atts   jsonb;
  v_target        record;
  v_quiz          record;
  v_file          text;
  v_elem          jsonb;
  v_matched       jsonb;
  v_matched_names text[];
  v_keep          jsonb;
  v_new           jsonb;
  v_hits          integer;
BEGIN
  -- ── Course lookup: ICT1 by its unique code, never a hard-coded uuid ───────
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_attach_week_materials: course ICT1 missing - nothing to do';
    RETURN;
  END IF;

  -- ── Prelim source row: active quiz with the 7 source attachments ─────────
  SELECT id, attachments
    INTO v_prelim, v_prelim_atts
    FROM public.quizzes
   WHERE course_id = v_course
     AND title ILIKE 'PRELIM EXAMINATION%'
     AND deleted_at IS NULL
     AND jsonb_typeof(attachments) = 'array'
     AND jsonb_array_length(attachments) > 0
   ORDER BY created_at
   LIMIT 1;

  IF v_prelim IS NULL THEN
    RAISE NOTICE 'ict1_attach_week_materials: no active ICT1 ''PRELIM EXAMINATION%%'' quiz with a non-empty attachments array - nothing to do (never inventing URLs)';
    RETURN;
  END IF;

  RAISE NOTICE 'ict1_attach_week_materials: copying attachment elements from prelim quiz % (% file(s))',
    v_prelim, jsonb_array_length(v_prelim_atts);

  -- ── Target mapping: exact quiz title ← source file name(s) ──────────────
  FOR v_target IN
    SELECT t.title, t.files
      FROM (VALUES
        ('Quiz 1'::text, ARRAY['TVE100 Week1 Slide_Introduction to the Course.pdf']::text[]),
        ('Quiz 2'::text, ARRAY['TVE100 Week2 Slide_The Teacher as a Professional.pdf']::text[]),
        ('Quiz 3'::text, ARRAY['TVE100 Week3 Slide_The Teacher and the Community.pdf']::text[]),
        ('Quiz 4'::text, ARRAY['TVE100 Week4 Slides_Understanding School Culture.pdf']::text[]),
        ('Quiz 5'::text, ARRAY['ICT1_Week5 Online Collaboration Tools.pptx']::text[]),
        ('Quiz 6'::text, ARRAY['ICT1_Week6 Learning Management Systems.pptx']::text[]),
        ('Quiz 7'::text, ARRAY['ICT1_Week7 Multimedia in Education.pptx']::text[]),
        ('FINAL EXAMINATION (Coverage: Weeks 1-7)'::text,
          ARRAY[
            'TVE100 Week1 Slide_Introduction to the Course.pdf',
            'TVE100 Week2 Slide_The Teacher as a Professional.pdf',
            'TVE100 Week3 Slide_The Teacher and the Community.pdf',
            'TVE100 Week4 Slides_Understanding School Culture.pdf',
            'ICT1_Week5 Online Collaboration Tools.pptx',
            'ICT1_Week6 Learning Management Systems.pptx',
            'ICT1_Week7 Multimedia in Education.pptx'
          ]::text[])
      ) AS t(title, files)
  LOOP
    -- Collect the whole attachment elements (verbatim) for this target's files.
    v_matched := '[]'::jsonb;
    v_matched_names := ARRAY[]::text[];

    FOREACH v_file IN ARRAY v_target.files LOOP
      SELECT e.value
        INTO v_elem
        FROM jsonb_array_elements(v_prelim_atts) AS e(value)
       WHERE e.value->>'name' = v_file
       LIMIT 1;

      IF v_elem IS NULL THEN
        RAISE NOTICE 'ict1_attach_week_materials: source file % not present in prelim attachments - skipped (no URL invented)', v_file;
        CONTINUE;
      END IF;

      v_matched := v_matched || jsonb_build_array(v_elem);
      v_matched_names := array_append(v_matched_names, v_file);
    END LOOP;

    IF jsonb_array_length(v_matched) = 0 THEN
      RAISE NOTICE 'ict1_attach_week_materials: no source elements for % - left untouched', v_target.title;
      CONTINUE;
    END IF;

    -- Update every active ICT1 row with this exact title (normally exactly one).
    v_hits := 0;

    FOR v_quiz IN
      SELECT id, attachments
        FROM public.quizzes
       WHERE course_id = v_course
         AND title = v_target.title
         AND deleted_at IS NULL
       ORDER BY created_at
    LOOP
      -- Keep every existing entry EXCEPT the ones we are replacing by name
      -- (name-less / unrelated entries survive). Then append the source elements.
      v_keep := (
        SELECT COALESCE(jsonb_agg(e.value ORDER BY e.ord), '[]'::jsonb)
          FROM jsonb_array_elements(
                 CASE
                   WHEN jsonb_typeof(v_quiz.attachments) = 'array' THEN v_quiz.attachments
                   ELSE '[]'::jsonb
                 END
               ) WITH ORDINALITY AS e(value, ord)
         WHERE e.value->>'name' IS NULL
            OR NOT (e.value->>'name' = ANY (v_matched_names))
      );
      v_new := v_keep || v_matched;

      UPDATE public.quizzes
         SET attachments = v_new
       WHERE id = v_quiz.id;

      v_hits := v_hits + 1;

      RAISE NOTICE 'ict1_attach_week_materials: % (id %) - attached % file(s), kept % unrelated, total %',
        v_target.title, v_quiz.id, jsonb_array_length(v_matched),
        jsonb_array_length(v_keep), jsonb_array_length(v_new);
    END LOOP;

    IF v_hits = 0 THEN
      RAISE NOTICE 'ict1_attach_week_materials: no active ICT1 quiz titled % - skipped', v_target.title;
    END IF;
  END LOOP;
END;
$ict1_attach_week_materials$;
