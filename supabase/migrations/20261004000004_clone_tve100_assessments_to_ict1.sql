-- MIOW-LMS: Clone TVE100 assessments (quizzes + assignments) onto ICT1.
--
-- Why: Quizzes 1-4 + Prelim Exam (each with attached handouts and question
-- sets) were authored through the app UI against course TVE100, so they live
-- only in the production DB — there is no local seed to copy from. ICT1
-- ('ICT 1 - LAB') shares the same B8 student cohort and must receive the SAME
-- assessments. This migration therefore clones the rows at apply-time: against
-- the local (empty) DB it is a no-op; against production it does the real clone.
--
-- Clone rules (idempotent — safe to run any number of times):
--   * Source: every non-deleted (deleted_at IS NULL) quizzes/assignments row of
--     course code 'TVE100' that is not already present on course code 'ICT1',
--     where "present" = an ICT1 row (of the same table) with the same
--     case-insensitive title (lower(btrim(title))). A soft-deleted ICT1 row with
--     the same title still counts as present, so a deliberate teacher deletion
--     is never resurrected into a duplicate.
--   * Quizzes copy source columns verbatim except id/course_id (new quiz id,
--     course_id = ICT1): title, duration_minutes, allow_retake, max_attempts,
--     retake_score_policy, attachments, score_released, answer_key_released,
--     question_count, created_at. deleted_at is left NULL (sources are active).
--   * quiz_questions of each cloned quiz are copied verbatim (question, options,
--     correct_answer, position) with new ids re-pointed at the new quiz id.
--   * Assignments copy source columns verbatim except id/course_id: title,
--     description, due_date, total_points, component_type, attachments,
--     score_released, created_at.
--   * attachments jsonb is copied as-is (same storage objects/paths — sharing
--     the same files across the two courses is intended).
--   * NO student data is cloned: no submissions, quiz_attempts, grades,
--     quiz_score_overrides, quiz_retake_grants, attendance.
--
-- Row shapes mirror the app exactly (nothing invented):
--   * attachments: jsonb array of {name, url, size, type, path}
--     (src/lib/server/materials.server.ts:44,136-142 and src/lib/lms.ts:240-246;
--     validated by attachmentMeta in src/lib/server/schemas.server.ts:22-28).
--   * component_type enum: 'written_work' | 'performance_task' |
--     'quarterly_exam' (src/lib/lms.ts:216; schemas.server.ts:264,437).
--   * question_count: integer, 0 = show all questions (20260905000000_question_bank.sql).
--   * Soft delete: deleted_at timestamptz NULL = active
--     (20260825093258_5b5b8ed4-4220-4488-9a9a-27e9a95e8049.sql; app filters
--     deleted_at IS NULL in src/lib/server/quizzes.server.ts:11).
--
-- Both courses are resolved by their UNIQUE code (TVE100 / ICT1), never by a
-- hard-coded uuid, so the migration is correct on any environment. If either
-- course is missing, it raises a notice and does nothing.

DO $clone_tve100_assessments_to_ict1$
DECLARE
  v_src_id       uuid;
  v_dst_id       uuid;
  v_new_quiz_id  uuid;
  v_q_count      integer;
  v_quizzes      integer := 0;
  v_questions    integer := 0;
  v_assignments  integer := 0;
  r              record;
BEGIN
  SELECT id INTO v_src_id FROM public.courses WHERE code = 'TVE100';
  SELECT id INTO v_dst_id FROM public.courses WHERE code = 'ICT1';

  IF v_src_id IS NULL OR v_dst_id IS NULL THEN
    RAISE NOTICE 'clone_tve100_assessments_to_ict1: TVE100 (%) or ICT1 (%) missing - nothing to do',
      v_src_id, v_dst_id;
    RETURN;
  END IF;

  -- ── 1. Quizzes + their questions ──────────────────────────────────────────
  FOR r IN
    SELECT q.*
    FROM public.quizzes q
    WHERE q.course_id = v_src_id
      AND q.deleted_at IS NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.quizzes d
        WHERE d.course_id = v_dst_id
          AND lower(btrim(d.title)) = lower(btrim(q.title))
      )
    ORDER BY q.created_at, lower(btrim(q.title))
  LOOP
    -- Re-check inside the loop: two source quizzes may share a title (the
    -- cursor snapshot would otherwise clone both).
    IF EXISTS (
      SELECT 1
      FROM public.quizzes d
      WHERE d.course_id = v_dst_id
        AND lower(btrim(d.title)) = lower(btrim(r.title))
    ) THEN
      CONTINUE;
    END IF;

    INSERT INTO public.quizzes (
      course_id, title, duration_minutes, allow_retake, max_attempts,
      retake_score_policy, attachments, score_released, answer_key_released,
      question_count, created_at
    ) VALUES (
      v_dst_id, r.title, r.duration_minutes, r.allow_retake, r.max_attempts,
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

  -- ── 2. Assignments ────────────────────────────────────────────────────────
  FOR r IN
    SELECT a.*
    FROM public.assignments a
    WHERE a.course_id = v_src_id
      AND a.deleted_at IS NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.assignments d
        WHERE d.course_id = v_dst_id
          AND lower(btrim(d.title)) = lower(btrim(a.title))
      )
    ORDER BY a.created_at, lower(btrim(a.title))
  LOOP
    IF EXISTS (
      SELECT 1
      FROM public.assignments d
      WHERE d.course_id = v_dst_id
        AND lower(btrim(d.title)) = lower(btrim(r.title))
    ) THEN
      CONTINUE;
    END IF;

    INSERT INTO public.assignments (
      course_id, title, description, due_date, total_points,
      component_type, attachments, score_released, created_at
    ) VALUES (
      v_dst_id, r.title, r.description, r.due_date, r.total_points,
      r.component_type, r.attachments, r.score_released, r.created_at
    );

    v_assignments := v_assignments + 1;
  END LOOP;

  RAISE NOTICE 'clone_tve100_assessments_to_ict1: cloned % quizzes (% questions) and % assignments',
    v_quizzes, v_questions, v_assignments;
END $clone_tve100_assessments_to_ict1$;
