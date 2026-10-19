-- Draft records are independent of published grades; saves use optimistic locking.
CREATE TABLE IF NOT EXISTS public.class_records (
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  quarter integer NOT NULL CHECK (quarter BETWEEN 1 AND 8),
  revision integer NOT NULL DEFAULT 1,
  draft jsonb NOT NULL,
  updated_by uuid REFERENCES public.profiles(id),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (course_id, quarter)
);
ALTER TABLE public.class_records ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.class_records FROM anon, authenticated;
GRANT ALL ON public.class_records TO service_role;
ALTER TABLE public.grades ADD COLUMN IF NOT EXISTS class_record_snapshot jsonb;

CREATE OR REPLACE FUNCTION public.save_class_record(
  p_course uuid, p_quarter integer, p_revision integer, p_draft jsonb,
  p_actor uuid, p_publications jsonb DEFAULT '[]'::jsonb
) RETURNS integer LANGUAGE plpgsql SET search_path = public AS $$
DECLARE next_revision integer; publication jsonb; snap jsonb;
BEGIN
  IF p_revision = 0 THEN
    INSERT INTO class_records(course_id, quarter, revision, draft, updated_by)
      VALUES(p_course, p_quarter, 1, p_draft, p_actor)
      ON CONFLICT DO NOTHING RETURNING revision INTO next_revision;
  ELSE
    UPDATE class_records SET draft=p_draft, revision=revision+1, updated_by=p_actor, updated_at=now()
      WHERE course_id=p_course AND quarter=p_quarter AND revision=p_revision
      RETURNING revision INTO next_revision;
  END IF;
  IF next_revision IS NULL THEN
    RAISE EXCEPTION 'This class record changed in another window. Reload before saving.';
  END IF;
  FOR publication IN SELECT value FROM jsonb_array_elements(p_publications) LOOP
    snap := publication->'snapshot';
    INSERT INTO grades(student_id, course_id, quarter, written_work_score, performance_task_score,
      exam_score, transmuted_final_grade, class_record_snapshot)
    VALUES ((publication->>'student_id')::uuid, p_course, p_quarter,
      (snap->>'ww')::numeric, (snap->>'pt')::numeric, (snap->>'ex')::numeric,
      CASE WHEN snap->>'scale'='deped' THEN (snap->>'final')::numeric ELSE NULL END, snap)
    ON CONFLICT (student_id, course_id, quarter) DO UPDATE SET
      written_work_score=EXCLUDED.written_work_score, performance_task_score=EXCLUDED.performance_task_score,
      exam_score=EXCLUDED.exam_score, transmuted_final_grade=EXCLUDED.transmuted_final_grade,
      class_record_snapshot=EXCLUDED.class_record_snapshot;
  END LOOP;
  RETURN next_revision;
END $$;
REVOKE ALL ON FUNCTION public.save_class_record(uuid,integer,integer,jsonb,uuid,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.save_class_record(uuid,integer,integer,jsonb,uuid,jsonb) TO service_role;

-- IT10 keeps the highest attempt regardless of creation/import/seed code path.
CREATE OR REPLACE FUNCTION public.enforce_it10_highest_score() RETURNS trigger
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF EXISTS(SELECT 1 FROM courses WHERE id=NEW.course_id AND upper(btrim(code))='IT10') THEN
    NEW.retake_score_policy := 'highest_score';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS enforce_it10_highest_score ON public.quizzes;
CREATE TRIGGER enforce_it10_highest_score BEFORE INSERT OR UPDATE OF course_id, retake_score_policy
  ON public.quizzes FOR EACH ROW EXECUTE FUNCTION public.enforce_it10_highest_score();
UPDATE public.quizzes SET retake_score_policy='highest_score'
  WHERE course_id IN (SELECT id FROM public.courses WHERE upper(btrim(code))='IT10')
    AND retake_score_policy IS DISTINCT FROM 'highest_score';
