-- Kent Alexis T. Alia — web developer admin grant (user request, 2026-10-09).
-- Creates the account if missing, ensures role = admin either way. Idempotent.

DO $$
DECLARE
  v_id uuid;
BEGIN
  SELECT id INTO v_id FROM public.profiles
   WHERE lower(email) = 'kentalexis.alia@g.msuiit.edu.ph';

  IF v_id IS NULL THEN
    INSERT INTO public.profiles (
      id, student_id, email, pin, pin_hash, full_name, role,
      rfid_uid, avatar_url, grade_level, section
    ) VALUES (
      gen_random_uuid(),
      NULL,
      'kentalexis.alia@g.msuiit.edu.ph',
      '1234',
      extensions.crypt('1234', extensions.gen_salt('bf', 10)),
      'Kent Alexis T. Alia',
      'admin'::public.profile_role,
      NULL,
      NULL,
      NULL,
      NULL
    );
    RAISE NOTICE 'created admin profile kentalexis.alia@g.msuiit.edu.ph';
  ELSIF (SELECT role FROM public.profiles WHERE id = v_id)
        <> 'admin'::public.profile_role THEN
    UPDATE public.profiles SET role = 'admin' WHERE id = v_id;
    RAISE NOTICE 'promoted kentalexis.alia@g.msuiit.edu.ph to admin';
  ELSE
    RAISE NOTICE 'kentalexis.alia@g.msuiit.edu.ph already admin — no change';
  END IF;
END $$;
