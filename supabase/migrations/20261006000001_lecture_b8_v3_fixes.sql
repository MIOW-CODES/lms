-- 20261006000001: B8 section enrollment for the Lecture course (TLE 105) + v3 fixes
-- (quiz-file sync from TVE100, single Prelim per course, Week 5-7 materials). Idempotent.
DO $v3$
DECLARE
  v_src   uuid;   -- TVE100
  v_ict1  uuid;   -- ICT1 ('ICT 1 - LAB')
  v_lect  uuid;   -- lecture course ('TLE 105' / 'LECTURE_TLE 105%')
BEGIN
  -- ── 0. Resolve courses by code/title (never a hard-coded uuid) ───────────
  SELECT id INTO v_src  FROM public.courses WHERE code = 'TVE100' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_ict1 FROM public.courses WHERE code = 'ICT1'   ORDER BY created_at LIMIT 1;
  SELECT id INTO v_lect FROM public.courses WHERE code = 'TLE 105' ORDER BY created_at LIMIT 1;
  IF v_lect IS NULL THEN
    SELECT id INTO v_lect
    FROM public.courses
    WHERE title ILIKE 'LECTURE_TLE 105%'
    ORDER BY created_at
    LIMIT 1;
    IF v_lect IS NOT NULL THEN
      RAISE NOTICE 'v3: lecture course matched by title ILIKE LECTURE_TLE 105%% -> %', v_lect;
    END IF;
  END IF;

  IF v_src IS NULL THEN
    RAISE NOTICE 'v3: course TVE100 missing - clone + quiz-file sync skipped';
  END IF;
  IF v_ict1 IS NULL THEN
    RAISE NOTICE 'v3: course ICT1 missing - ICT1 work skipped';
  END IF;
  IF v_lect IS NULL THEN
    RAISE NOTICE 'v3: lecture course (code TLE 105 OR title ILIKE LECTURE_TLE 105%%) not found - lecture work skipped (not guessed)';
  END IF;

  -- ==========================================================================
  -- (4a) Enroll the 45 lecture students into the lecture course.
  -- Roster = 20261004000001_seed_ict1_meeting_members.sql with in_lecture=true
  -- (everyone except CALUNOD 2020-3440). Profiles already exist in production;
  -- only public.enrollments rows are written (ON CONFLICT DO NOTHING).
  -- ==========================================================================
  <<v3_enroll_lecture>>
  DECLARE
    v_added    integer;
    v_profiles integer;
  BEGIN
    IF v_lect IS NOT NULL THEN
      INSERT INTO public.enrollments (student_id, course_id)
      SELECT p.id, v_lect
      FROM public.profiles p
      WHERE p.student_id IN (
        '2024-2699', '2024-2712', '2024-2017', '2024-1977', '2023-3693',
        '2024-2724', '2022-4168', '2024-3145', '2024-2739', '2023-1550',
        '2024-2094', '2024-2084', '2024-2753', '2024-2766', '2024-2776',
        '2024-2683', '2022-7023', '2022-6116', '2024-2503', '2024-2514',
        '2024-0877', '2024-2530', '2024-2875', '2024-2211', '2024-2557',
        '2024-2212', '2024-2968', '2022-6850', '2022-3418', '2024-2214',
        '2024-3172', '2024-2249', '2024-2586', '2024-2599', '2021-1692',
        '2025-0858', '2024-1459', '2024-3454', '2024-2606', '2024-2287',
        '2024-2614', '2024-2627', '2025-2624', '2024-1710', '2024-2655', '2020-3440'
      )
      ON CONFLICT (student_id, course_id) DO NOTHING;

      GET DIAGNOSTICS v_added = ROW_COUNT;

      SELECT count(*) INTO v_profiles
      FROM public.profiles
      WHERE student_id IN (
        '2024-2699', '2024-2712', '2024-2017', '2024-1977', '2023-3693',
        '2024-2724', '2022-4168', '2024-3145', '2024-2739', '2023-1550',
        '2024-2094', '2024-2084', '2024-2753', '2024-2766', '2024-2776',
        '2024-2683', '2022-7023', '2022-6116', '2024-2503', '2024-2514',
        '2024-0877', '2024-2530', '2024-2875', '2024-2211', '2024-2557',
        '2024-2212', '2024-2968', '2022-6850', '2022-3418', '2024-2214',
        '2024-3172', '2024-2249', '2024-2586', '2024-2599', '2021-1692',
        '2025-0858', '2024-1459', '2024-3454', '2024-2606', '2024-2287',
        '2024-2614', '2024-2627', '2025-2624', '2024-1710', '2024-2655', '2020-3440'
      );

      IF v_profiles < 45 THEN
        RAISE NOTICE 'v3: only % of the 45 lecture-student profiles exist - those students were not enrolled', v_profiles;
      END IF;
      RAISE NOTICE 'v3: lecture enrollments - % new rows written (existing enrollments preserved)', v_added;
    END IF;
  END v3_enroll_lecture;

  -- ==========================================================================
  -- (4b) Clone ALL TVE100 quizzes (+ quiz_questions) and assignments to the
  -- lecture course. Same rules as 20261004000004_clone_tve100_assessments_to
  -- _ict1.sql (verbatim column copy except id/course_id; soft-deleted target
  -- rows count as "present" so teacher deletions are never resurrected; no
  -- student data is cloned). "Same title" here = normalized title (see header),
  -- which also prevents cloning a duplicate when a '(Coverage: ...)'-suffixed
  -- variant already exists.
  -- ==========================================================================
  <<v3_clone_to_lecture>>
  DECLARE
    v_new_quiz_id uuid;
    v_q_count     integer;
    v_quizzes     integer := 0;
    v_questions   integer := 0;
    v_assignments integer := 0;
    r             record;
  BEGIN
    IF v_src IS NOT NULL AND v_lect IS NOT NULL THEN
      -- 1. Quizzes + their questions
      FOR r IN
        SELECT q.*
        FROM public.quizzes q
        WHERE q.course_id = v_src
          AND q.deleted_at IS NULL
          AND NOT EXISTS (
            SELECT 1
            FROM public.quizzes d
            WHERE d.course_id = v_lect
              AND lower(btrim(regexp_replace(d.title, '[[:space:]]*[(]coverage:[^)]*[)][[:space:]]*$', '', 'i')))
                = lower(btrim(regexp_replace(q.title, '[[:space:]]*[(]coverage:[^)]*[)][[:space:]]*$', '', 'i')))
          )
        ORDER BY q.created_at, lower(btrim(q.title))
      LOOP
        -- Re-check inside the loop: two source quizzes may share a title.
        IF EXISTS (
          SELECT 1
          FROM public.quizzes d
          WHERE d.course_id = v_lect
            AND lower(btrim(regexp_replace(d.title, '[[:space:]]*[(]coverage:[^)]*[)][[:space:]]*$', '', 'i')))
              = lower(btrim(regexp_replace(r.title, '[[:space:]]*[(]coverage:[^)]*[)][[:space:]]*$', '', 'i')))
        ) THEN
          CONTINUE;
        END IF;

        INSERT INTO public.quizzes (
          course_id, title, duration_minutes, allow_retake, max_attempts,
          retake_score_policy, attachments, score_released, answer_key_released,
          question_count, created_at
        ) VALUES (
          v_lect, r.title, r.duration_minutes, r.allow_retake, r.max_attempts,
          r.retake_score_policy, r.attachments, r.score_released, r.answer_key_released,
          r.question_count, r.created_at
        )
        RETURNING id INTO v_new_quiz_id;

        INSERT INTO public.quiz_questions (quiz_id, question, options, correct_answer, position)
        SELECT v_new_quiz_id, qq.question, qq.options, qq.correct_answer, qq.position
        FROM public.quiz_questions qq
        WHERE qq.quiz_id = r.id;

        GET DIAGNOSTICS v_q_count = ROW_COUNT;
        v_questions := v_questions + v_q_count;
        v_quizzes   := v_quizzes + 1;
      END LOOP;

      -- 2. Assignments
      FOR r IN
        SELECT a.*
        FROM public.assignments a
        WHERE a.course_id = v_src
          AND a.deleted_at IS NULL
          AND NOT EXISTS (
            SELECT 1
            FROM public.assignments d
            WHERE d.course_id = v_lect
              AND lower(btrim(regexp_replace(d.title, '[[:space:]]*[(]coverage:[^)]*[)][[:space:]]*$', '', 'i')))
                = lower(btrim(regexp_replace(a.title, '[[:space:]]*[(]coverage:[^)]*[)][[:space:]]*$', '', 'i')))
          )
        ORDER BY a.created_at, lower(btrim(a.title))
      LOOP
        IF EXISTS (
          SELECT 1
          FROM public.assignments d
          WHERE d.course_id = v_lect
            AND lower(btrim(regexp_replace(d.title, '[[:space:]]*[(]coverage:[^)]*[)][[:space:]]*$', '', 'i')))
              = lower(btrim(regexp_replace(r.title, '[[:space:]]*[(]coverage:[^)]*[)][[:space:]]*$', '', 'i')))
        ) THEN
          CONTINUE;
        END IF;

        INSERT INTO public.assignments (
          course_id, title, description, due_date, total_points,
          component_type, attachments, score_released, created_at
        ) VALUES (
          v_lect, r.title, r.description, r.due_date, r.total_points,
          r.component_type, r.attachments, r.score_released, r.created_at
        );

        v_assignments := v_assignments + 1;
      END LOOP;

      RAISE NOTICE 'v3: cloned to lecture course - % quizzes (% questions), % assignments',
        v_quizzes, v_questions, v_assignments;
    END IF;
  END v3_clone_to_lecture;

  -- ==========================================================================
  -- (1)+(4c) QUIZ FILE RE-SYNC — for every active quiz on ICT1 and on the
  -- lecture course, re-donate the CURRENT TVE100 attachments of the quiz with
  -- the same normalized title. Replace semantics: attachments := TVE100's set
  -- (so a stale/empty target set is fully corrected). If the best-matching
  -- TVE100 quiz has no files, the target is left unchanged. Source pick when
  -- several TVE100 quizzes share a title: file-bearing first, then oldest.
  -- Paths are copied verbatim (no ownership check on /api/public/material for
  -- course materials - see header) so no storage files must be moved.
  -- ==========================================================================
  <<v3_quiz_file_sync>>
  DECLARE
    v_tgt      uuid;
    v_s_atts   jsonb;
    v_n        integer;
    v_updated  integer := 0;
    v_nofile   integer := 0;
    r          record;
  BEGIN
    IF v_src IS NOT NULL THEN
      FOREACH v_tgt IN ARRAY ARRAY[v_ict1, v_lect] LOOP
        IF v_tgt IS NULL THEN
          CONTINUE;
        END IF;

        FOR r IN
          SELECT q.id, q.title
          FROM public.quizzes q
          WHERE q.course_id = v_tgt
            AND q.deleted_at IS NULL
          ORDER BY q.created_at, lower(btrim(q.title)), q.id
        LOOP
          SELECT s.attachments INTO v_s_atts
          FROM public.quizzes s
          WHERE s.course_id = v_src
            AND s.deleted_at IS NULL
            AND lower(btrim(regexp_replace(s.title, '[[:space:]]*[(]coverage:[^)]*[)][[:space:]]*$', '', 'i')))
              = lower(btrim(regexp_replace(r.title, '[[:space:]]*[(]coverage:[^)]*[)][[:space:]]*$', '', 'i')))
          ORDER BY (jsonb_array_length(COALESCE(s.attachments, '[]'::jsonb)) > 0) DESC,
                   s.created_at, s.id
          LIMIT 1;

          IF v_s_atts IS NOT NULL AND jsonb_array_length(COALESCE(v_s_atts, '[]'::jsonb)) > 0 THEN
            UPDATE public.quizzes
            SET attachments = v_s_atts
            WHERE id = r.id
              AND attachments IS DISTINCT FROM v_s_atts;
            GET DIAGNOSTICS v_n = ROW_COUNT;
            v_updated := v_updated + v_n;
          ELSE
            v_nofile := v_nofile + 1;   -- no TVE100 files for this title -> target untouched
          END IF;
        END LOOP;
      END LOOP;

      RAISE NOTICE 'v3: quiz-file sync - % quiz rows updated, % left unchanged (no TVE100 files for their title)',
        v_updated, v_nofile;
    END IF;
  END v3_quiz_file_sync;

  -- ==========================================================================
  -- (2)+(4c) PRELIM DEDUPE — exactly ONE active '%prelim%' row per course.
  -- Rule (see header): keep the row that has the exam file (any attachment
  -- other than the 3 Week 5-7 lecture slides); ties -> quiz over assignment ->
  -- most quiz_questions -> oldest created_at -> lowest id. Losers are
  -- soft-deleted (deleted_at = now()), never hard-deleted. Runs AFTER the
  -- quiz-file sync so "has the exam file" sees the final attachment sets.
  -- ==========================================================================
  <<v3_prelim_dedupe>>
  DECLARE
    v_tgt     uuid;
    v_n       integer;
    v_win_id  uuid;
    v_win_kind text;
    v_del_q   integer;
    v_del_a   integer;
  BEGIN
    FOREACH v_tgt IN ARRAY ARRAY[v_ict1, v_lect] LOOP
      IF v_tgt IS NULL THEN
        CONTINUE;
      END IF;

      SELECT count(*) INTO v_n
      FROM (
        SELECT q.id FROM public.quizzes q
        WHERE q.course_id = v_tgt AND q.deleted_at IS NULL AND q.title ILIKE '%prelim%'
        UNION ALL
        SELECT a.id FROM public.assignments a
        WHERE a.course_id = v_tgt AND a.deleted_at IS NULL AND a.title ILIKE '%prelim%'
      ) x;

      IF v_n = 0 THEN
        RAISE NOTICE 'v3: prelim dedupe - course % has no active prelim rows - nothing to do', v_tgt;
        CONTINUE;
      END IF;
      IF v_n = 1 THEN
        RAISE NOTICE 'v3: prelim dedupe - course % already has exactly one active prelim row', v_tgt;
        CONTINUE;
      END IF;

      SELECT c.id, c.kind INTO v_win_id, v_win_kind
      FROM (
        SELECT q.id,
               'quiz'::text AS kind,
               q.created_at,
               (SELECT count(*) FROM public.quiz_questions qq WHERE qq.quiz_id = q.id) AS qcount,
               EXISTS (
                 SELECT 1 FROM jsonb_array_elements(COALESCE(q.attachments, '[]'::jsonb)) e
                 WHERE COALESCE(e->>'path', e->>'name', '')
                       !~ '(material_1759632000000_a1b2c3d4|material_1759632001000_b2c3d4e5|material_1759632002000_c3d4e5f6)[.]pptx$'
               ) AS has_exam_file
        FROM public.quizzes q
        WHERE q.course_id = v_tgt AND q.deleted_at IS NULL AND q.title ILIKE '%prelim%'
        UNION ALL
        SELECT a.id,
               'assignment'::text,
               a.created_at,
               0,
               EXISTS (
                 SELECT 1 FROM jsonb_array_elements(COALESCE(a.attachments, '[]'::jsonb)) e
                 WHERE COALESCE(e->>'path', e->>'name', '')
                       !~ '(material_1759632000000_a1b2c3d4|material_1759632001000_b2c3d4e5|material_1759632002000_c3d4e5f6)[.]pptx$'
               )
        FROM public.assignments a
        WHERE a.course_id = v_tgt AND a.deleted_at IS NULL AND a.title ILIKE '%prelim%'
      ) c
      ORDER BY c.has_exam_file DESC,
               (c.kind = 'quiz') DESC,
               c.qcount DESC,
               c.created_at ASC,
               c.id ASC
      LIMIT 1;

      UPDATE public.quizzes
      SET deleted_at = now()
      WHERE course_id = v_tgt
        AND deleted_at IS NULL
        AND title ILIKE '%prelim%'
        AND id <> v_win_id;
      GET DIAGNOSTICS v_del_q = ROW_COUNT;

      UPDATE public.assignments
      SET deleted_at = now()
      WHERE course_id = v_tgt
        AND deleted_at IS NULL
        AND title ILIKE '%prelim%'
        AND id <> v_win_id;
      GET DIAGNOSTICS v_del_a = ROW_COUNT;

      RAISE NOTICE 'v3: prelim dedupe - course % kept % %, soft-deleted % quiz + % assignment duplicate(s)',
        v_tgt, v_win_kind, v_win_id, v_del_q, v_del_a;
    END LOOP;
  END v3_prelim_dedupe;

  -- ==========================================================================
  -- (4d) LECTURE COURSE 'Week 5-7 Lecture Materials' + 'Coverage: Weeks 1-7'
  -- on its prelim — same pattern as 20261004000005_ict1_week5_7_materials.sql,
  -- scoped to the lecture course. ICT1 is intentionally NOT touched here:
  -- its prelim coverage text/titles are already correct (problem 3).
  -- The 3 pptx attachment objects are reused WITH THE ICT1 PATHS (files live
  -- in the bucket under the ICT1 course folder from the v2 upload, and
  -- /api/public/material does not enforce course ownership) — so no storage
  -- file must be copied. If ICT1 is missing, paths fall back to the lecture
  -- course id and the files would then have to be uploaded under that folder.
  -- ==========================================================================
  <<v3_lecture_week5_7>>
  DECLARE
    v_prefix    uuid;
    v_atts      jsonb := '[]'::jsonb;
    v_paths     text[] := ARRAY[]::text[];
    v_course    uuid;
    r           record;
    r2          record;
    v_path      text;
    v_merged    jsonb;
    v_desc      text;
    v_title     text;
    v_asg_ins   integer := 0;
    v_asg_upd   integer := 0;
    v_qz_upd    integer := 0;
  BEGIN
    v_course := v_lect;
    v_prefix := COALESCE(v_ict1, v_lect);

    IF v_course IS NOT NULL THEN
      -- ── Build the 3 attachment objects (byte-identical to
      --    20261004000005, but path-prefixed with v_prefix) ─────────────────
      FOR r2 IN
        SELECT * FROM (VALUES
          ('ICT1_Week5 Online Collaboration Tools.pptx',  'material_1759632000000_a1b2c3d4.pptx', 85918),
          ('ICT1_Week6 Learning Management Systems.pptx', 'material_1759632001000_b2c3d4e5.pptx', 79130),
          ('ICT1_Week7 Multimedia in Education.pptx',     'material_1759632002000_c3d4e5f6.pptx', 82712)
        ) AS t(fname, fsuffix, fsize)
      LOOP
        v_path := v_prefix::text || '/' || r2.fsuffix;
        v_paths := array_append(v_paths, v_path);
        v_atts := v_atts || jsonb_build_array(jsonb_build_object(
          'name', r2.fname,
          'url',  '/api/public/material?p=' || replace(v_path, '/', '%2F'),
          'size', r2.fsize,
          'type', 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          'path', v_path
        ));
      END LOOP;

      -- ── (a) 'Week 5-7 Lecture Materials' carrier assignment ───────────────
      FOR r IN
        SELECT id, description, attachments
        FROM public.assignments
        WHERE course_id = v_course
          AND deleted_at IS NULL
          AND (
            lower(btrim(title)) = 'week 5-7 lecture materials'
            OR EXISTS (
              SELECT 1 FROM jsonb_array_elements(attachments) e
              WHERE e->>'path' = ANY (v_paths)
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

      -- ── (b1) Prelim ASSIGNMENTS: coverage line + slide attachments ────────
      FOR r IN
        SELECT id, title, description, attachments
        FROM public.assignments
        WHERE course_id = v_course
          AND deleted_at IS NULL
          AND title ILIKE '%prelim%'
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

      -- ── (b2) Prelim QUIZZES: coverage line + slide attachments ────────────
      FOR r IN
        SELECT id, title, attachments
        FROM public.quizzes
        WHERE course_id = v_course
          AND deleted_at IS NULL
          AND title ILIKE '%prelim%'
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

        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'quizzes' AND column_name = 'description'
        ) THEN
          -- Future-proof: only planned/executed if quizzes ever grows a description.
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
          -- No description column in this schema: surface coverage in the only
          -- free text a quiz row has - an additive title suffix, only when the
          -- title does not already mention "week" (idempotent).
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

      RAISE NOTICE 'v3: lecture week5-7 - assignment inserted %, assignment rows updated %, quiz rows updated %',
        v_asg_ins, v_asg_upd, v_qz_upd;
    END IF;
  END v3_lecture_week5_7;

  RAISE NOTICE 'v3: done (src TVE100 %, ICT1 %, lecture %)', v_src, v_ict1, v_lect;
END $v3$;
