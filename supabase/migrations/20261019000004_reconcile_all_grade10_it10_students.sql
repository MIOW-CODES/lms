-- Reconcile the complete official Grade 10 roster with production.
-- Restores missing profiles, enrolls every roster member in IT10, issues the
-- documented temporary PIN, and clears all row/shared authentication locks.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TEMP TABLE expected_it10_grade10 (
  student_id text PRIMARY KEY,
  email text NOT NULL UNIQUE,
  full_name text NOT NULL,
  section text NOT NULL
) ON COMMIT DROP;

INSERT INTO expected_it10_grade10 (student_id, email, full_name, section) VALUES
  ('2026-0000', 'josephalan.vergara@g.msuiit.edu.ph', 'Joseph Alan B. Vergara', 'Omega'),
  ('2026-0001', 'sittieainah.abdullah@g.msuiit.edu.ph', 'Sittie Ainah Abdullah', 'Omega'),
  ('2026-0002', 'duncanirving.achondo@g.msuiit.edu.ph', 'Duncan Irving Achondo', 'Omega'),
  ('2026-0003', 'samanthajane.aruelo@g.msuiit.edu.ph', 'Samantha Jane Aruelo', 'Omega'),
  ('2026-0004', 'aizekiel.basalo@g.msuiit.edu.ph', 'Aizekiel Basalo', 'Omega'),
  ('2026-0005', 'shanceyalfhea.bianson@g.msuiit.edu.ph', 'Shancey Alfhea Bianson', 'Omega'),
  ('2026-0006', 'donnelanthony.blanco@g.msuiit.edu.ph', 'Donnel Anthony Blanco', 'Omega'),
  ('2026-0007', 'louisemichaella.bugo@g.msuiit.edu.ph', 'Louise Michaella Bugo', 'Omega'),
  ('2026-0008', 'clecel.delosantos@g.msuiit.edu.ph', 'Clecel Delos Santos', 'Omega'),
  ('2026-0009', 'azriel.exile@g.msuiit.edu.ph', 'Azriel dC. Exile', 'Omega'),
  ('2026-0010', 'allison.gabutan@g.msuiit.edu.ph', 'Allison Gabutan', 'Omega'),
  ('2026-0011', 'julianaemmanuelle.hiadan@g.msuiit.edu.ph', 'Juliana Emmanuelle Hiadan', 'Omega'),
  ('2026-0012', 'jaredvince.ibay@g.msuiit.edu.ph', 'Jared Vince Ibay', 'Omega'),
  ('2026-0013', 'badrie.ibrahim@g.msuiit.edu.ph', 'Badrie Ibrahim', 'Omega'),
  ('2026-0014', 'kyliemaxine.lacastesantos@g.msuiit.edu.ph', 'Kylie Maxine Lacastesantos', 'Omega'),
  ('2026-0015', 'xhun.lao@g.msuiit.edu.ph', 'Xhun Lao', 'Omega'),
  ('2026-0016', 'xypaulmatthew.loquinte@g.msuiit.edu.ph', 'Xy- Paul Matthew Loquinte', 'Omega'),
  ('2026-0017', 'annekassidy.luceno@g.msuiit.edu.ph', 'Anne Cassidy Luceño', 'Omega'),
  ('2026-0018', 'ameraaisah.lucman@g.msuiit.edu.ph', 'Amera Aisah Lucman', 'Omega'),
  ('2026-0019', 'zainanadheera.macarambon@g.msuiit.edu.ph', 'Zaina Nadheera Macarambon', 'Omega'),
  ('2026-0020', 'princesswidad.macaraya@g.msuiit.edu.ph', 'Princess Widad Macaraya', 'Omega'),
  ('2026-0021', 'lemarcusseth.madjus@g.msuiit.edu.ph', 'Lemarcus Seth Madjus', 'Omega'),
  ('2026-0022', 'mohammadishaq.magarang@g.msuiit.edu.ph', 'Mohammad Ishaq Magarang', 'Omega'),
  ('2026-0023', 'anikainjeela.magomnang@g.msuiit.edu.ph', 'Anika Injeela Magomnang', 'Omega'),
  ('2026-0024', 'johanaxl.neri@g.msuiit.edu.ph', 'Johan Axl Neri', 'Omega'),
  ('2026-0025', 'jaydenmatthew.paloma@g.msuiit.edu.ph', 'Jayden Matthew Paloma', 'Omega'),
  ('2026-0026', 'lauricegabrielle.pastor@g.msuiit.edu.ph', 'Laurice Gabrielle Pastor', 'Omega'),
  ('2026-0027', 'juliannafaye.sanchez@g.msuiit.edu.ph', 'Julianna Faye Sanchez', 'Omega'),
  ('2026-0028', 'jhalanie.sarip@g.msuiit.edu.ph', 'Jhalanie Sarip', 'Omega'),
  ('2026-0029', 'alainmark.tomarong@g.msuiit.edu.ph', 'Alain Mark Tomarong', 'Omega'),
  ('2026-0030', 'ravenjoy.ungria@g.msuiit.edu.ph', 'Raven Joy Ungria', 'Omega'),
  ('2026-0031', 'abdulmughni.abdisa@g.msuiit.edu.ph', 'Abdul Mughni Abdisa', 'Phi'),
  ('2026-0032', 'attheyaalyssandra.anwar@g.msuiit.edu.ph', 'Atheya Alyssandra Anwar', 'Phi'),
  ('2026-0033', 'aleksandraricayos@g.msuiit.edu.ph', 'Aleksandr O. Aricayos', 'Phi'),
  ('2026-0034', 'zedrickjohn.baje@g.msuiit.edu.ph', 'Zedrick John Baje', 'Phi'),
  ('2026-0035', 'juliana.bicos@g.msuiit.edu.ph', 'Juliana Bicos', 'Phi'),
  ('2026-0036', 'keziah.bocuya@g.msuiit.edu.ph', 'Keziah Bocuya', 'Phi'),
  ('2026-0037', 'fonzdexter.canalita@g.msuiit.edu.ph', 'Fonz Dexter Canalita', 'Phi'),
  ('2026-0038', 'aubrienneashlee.castillon@g.msuiit.edu.ph', 'Aubrienne Ashlee Castillon', 'Phi'),
  ('2026-0039', 'julianna.dampil@g.msuiit.edu.ph', 'Juliana Dampil', 'Phi'),
  ('2026-0040', 'ericaryanne.delosantos@g.msuiit.edu.ph', 'Erica Ryanne Delos Santos', 'Phi'),
  ('2026-0041', 'kiannicholas.fin@g.msuiit.edu.ph', 'Kian Nicholas Fin', 'Phi'),
  ('2026-0042', 'erichmarie.flores@g.msuiit.edu.ph', 'Erich Marie Flores', 'Phi'),
  ('2026-0043', 'janadorothy.gasparin@g.msuiit.edu.ph', 'Jana Dorothy Gasparin', 'Phi'),
  ('2026-0044', 'isobelle.guanzon@g.msuiit.edu.ph', 'Isobelle Guanzon', 'Phi'),
  ('2026-0045', 'sittieaisah.hadjiamen@g.msuiit.edu.ph', 'Sittie Aisah Hadji Amen', 'Phi'),
  ('2026-0046', 'joshanton.longgakit@g.msuiit.edu.ph', 'Josh Anton Longgakit', 'Phi'),
  ('2026-0047', 'arianamari.loquillano@g.msuiit.edu.ph', 'Ariana Mari Loquillano', 'Phi'),
  ('2026-0048', 'anniyazahra.macarambon@g.msuiit.edu.ph', 'Anniya Zahra Macarambon', 'Phi'),
  ('2026-0049', 'amrieljhairene.nunez@g.msuiit.edu.ph', 'Amriel Jhairene Nunez', 'Phi'),
  ('2026-0050', 'daniel.padua@g.msuiit.edu.ph', 'Daniel Padua', 'Phi'),
  ('2026-0051', 'candiceandrei.pagarigan@g.msuiit.edu.ph', 'Candice Andrei Pagarigan', 'Phi'),
  ('2026-0052', 'joshuavince.panerio@g.msuiit.edu.ph', 'Joshua Vince Panerio', 'Phi'),
  ('2026-0053', 'jayne.pepito@g.msuiit.edu.ph', 'Jayne Pepito', 'Phi'),
  ('2026-0054', 'lykashannel.rabe@g.msuiit.edu.ph', 'Lyka Shannel Rabe', 'Phi'),
  ('2026-0055', 'jeanfissoferra.ronquillo@g.msuiit.edu.ph', 'Jeanfiso Ferna Ronquillo', 'Phi'),
  ('2026-0056', 'gabriel.sacay@g.msuiit.edu.ph', 'Gabriel Sacay', 'Phi'),
  ('2026-0057', 'marljoshen.salvador@g.msuiit.edu.ph', 'Marl Joshen Salvador', 'Phi'),
  ('2026-0058', 'princesssavanna.tantao@g.msuiit.edu.ph', 'Princess Savanna Tantao', 'Phi'),
  ('2026-0059', 'aqeelmuhajer.tocalo@g.msuiit.edu.ph', 'Aqeel Muhajer Tocalo', 'Phi'),
  ('2026-0060', 'ethananthony.ubanan@g.msuiit.edu.ph', 'Ethan Anthony Ubanan', 'Phi'),
  ('2026-0061', 'marjun.abadano@g.msuiit.edu.ph', 'Marjun Abadano', 'Sigma'),
  ('2026-0062', 'shiekajannahyry.abulkhair@g.msuiit.edu.ph', 'Shieka Jannahyry Abulkhair', 'Sigma'),
  ('2026-0063', 'susainekyle.aguaviva@g.msuiit.edu.ph', 'Susaine Kyle Aguaviva', 'Sigma'),
  ('2026-0064', 'ryonaciedelle.alibanggo@g.msuiit.edu.ph', 'Ryona Ciedelle Alibanggo', 'Sigma'),
  ('2026-0065', 'rainthirdy.arago@g.msuiit.edu.ph', 'Rain Thirdy Arago', 'Sigma'),
  ('2026-0066', 'calvin.asibal@g.msuiit.edu.ph', 'Calvin Asibal', 'Sigma'),
  ('2026-0067', 'macrandall.batara@g.msuiit.edu.ph', 'Mac Randall Batara', 'Sigma'),
  ('2026-0068', 'jecel.bolo@g.msuiit.edu.ph', 'Jecel Bolo', 'Sigma'),
  ('2026-0069', 'janneiahaunisse.bugay@g.msuiit.edu.ph', 'Janneiah Aunisse Bugay', 'Sigma'),
  ('2026-0070', 'janninemei.dayoc@g.msuiit.edu.ph', 'Jannine Mei Dayoc', 'Sigma'),
  ('2026-0071', 'chancesmianne.emano@g.msuiit.edu.ph', 'Chances Mianne Emano', 'Sigma'),
  ('2026-0072', 'ryanrico.espinosa@g.msuiit.edu.ph', 'Ryan Rico Espinosa', 'Sigma'),
  ('2026-0073', 'gemcarl.fuentes@g.msuiit.edu.ph', 'Gem Carl Fuentes', 'Sigma'),
  ('2026-0074', 'krizzel.hynson@g.msuiit.edu.ph', 'Krizzel Hynson', 'Sigma'),
  ('2026-0075', 'vincecarlo.labanan@g.msuiit.edu.ph', 'Vince Carlo Labanan', 'Sigma'),
  ('2026-0076', 'wellaandrea.lapat@g.msuiit.edu.ph', 'Wella Andrea Lapat', 'Sigma'),
  ('2026-0077', 'lancematthew.llanes@g.msuiit.edu.ph', 'Lance Matthew Llanes', 'Sigma'),
  ('2026-0078', 'davongrey.loberanes@g.msuiit.edu.ph', 'Davon Grey Loberanes', 'Sigma'),
  ('2026-0079', 'lovelyshane.maglangit@g.msuiit.edu.ph', 'Lovely Shane Maglangit', 'Sigma'),
  ('2026-0080', 'zahirimran.mindalano@g.msuiit.edu.ph', 'Zahir Imran Mindalano', 'Sigma'),
  ('2026-0081', 'sheemazareena.moamar@g.msuiit.edu.ph', 'Sheema Zareena Moamar', 'Sigma'),
  ('2026-0082', 'chloe.naldo@g.msuiit.edu.ph', 'Chloe Naldo', 'Sigma'),
  ('2026-0083', 'celomarjr.paquiao@g.msuiit.edu.ph', 'Celomar Jr. Paquiao', 'Sigma'),
  ('2026-0084', 'princepatrick.parami@g.msuiit.edu.ph', 'Prince Patrick Parami', 'Sigma'),
  ('2026-0085', 'zaheer.pasandalan@g.msuiit.edu.ph', 'Zaheer Pasandalan', 'Sigma'),
  ('2026-0086', 'chrisiarhe.ramil@g.msuiit.edu.ph', 'Chrisia Rhe Ramil', 'Sigma'),
  ('2026-0087', 'gabrielle.reyes@g.msuiit.edu.ph', 'Gabrielle Xavi Reyes', 'Sigma'),
  ('2026-0088', 'maryallyza.roque@g.msuiit.edu.ph', 'Mary Allyza Roque', 'Sigma'),
  ('2026-0089', 'kaellahdanielle.roxas@g.msuiit.edu.ph', 'Kaellah Danielle Roxas', 'Sigma'),
  ('2026-0090', 'sittieameena.solaiman@g.msuiit.edu.ph', 'Sittie Ameena Solaiman', 'Sigma'),
  ('2026-0091', 'lorainejulia.sumagang@g.msuiit.edu.ph', 'Loraine Julia Sumagang', 'Sigma'),
  ('2026-0092', 'ceanaxavia.adeva@g.msuiit.edu.ph', 'Ceana Xavia Adeva', 'Tau'),
  ('2026-0093', 'mohammadryan.ampang@g.msuiit.edu.ph', 'Mohammad Ryan Ampang', 'Tau'),
  ('2026-0094', 'seinmikeljames.aquino@g.msuiit.edu.ph', 'Sein Mikel James Aquino', 'Tau'),
  ('2026-0095', 'gianniexielo.arquillos@g.msuiit.edu.ph', 'Gianne Xielo Arquillos', 'Tau'),
  ('2026-0096', 'johngabriel.arteta@g.msuiit.edu.ph', 'John Gabriel Arteta', 'Tau'),
  ('2026-0097', 'josephlevi.baclaan@g.msuiit.edu.ph', 'Joseph Levi Baclaan', 'Tau'),
  ('2026-0098', 'shahannelea.bagro@g.msuiit.edu.ph', 'Shahanne Lea Bagro', 'Tau'),
  ('2026-0099', 'aarongabriel.banaag@g.msuiit.edu.ph', 'Aaron Gabriel Banaag', 'Tau'),
  ('2026-0100', 'karlajoycemenissa.benitez@g.msuiit.edu.ph', 'Karla Joyce Melissa Benitez', 'Tau'),
  ('2026-0101', 'deonnealexa.cabtalan@g.msuiit.edu.ph', 'Deonne Alexa Cabtalan', 'Tau'),
  ('2026-0102', 'hanniel.canete@g.msuiit.edu.ph', 'Hanniel Cañete', 'Tau'),
  ('2026-0103', 'makaylasophie.caunda@g.msuiit.edu.ph', 'Makayla Sophie Caunda', 'Tau'),
  ('2026-0104', 'kristianmikael.cuanan@g.msuiit.edu.ph', 'Kristian Mikael Cuanan', 'Tau'),
  ('2026-0105', 'juanmiguel.dionesio@g.msuiit.edu.ph', 'Juan Miguel Dionesio', 'Tau'),
  ('2026-0106', 'janfaithmarguax.florentin@g.msuiit.edu.ph', 'Jan Faith Marguax Florentin', 'Tau'),
  ('2026-0107', 'gleenpatrick.fuentes@g.msuiit.edu.ph', 'Gleen Patrick Fuentes', 'Tau'),
  ('2026-0108', 'ahmadsadat.lanto@g.msuiit.edu.ph', 'Ahmadsadat Lanto', 'Tau'),
  ('2026-0109', 'isaiah.lluisma@g.msuiit.edu.ph', 'Isaiah Lluisma', 'Tau'),
  ('2026-0110', 'cjcarmonynyl.lopez@g.msuiit.edu.ph', 'CJ Carmelo Nyl Lopez', 'Tau'),
  ('2026-0111', 'mohamadrashid.lucman@g.msuiit.edu.ph', 'Mohammad Rashid Lucman', 'Tau'),
  ('2026-0112', 'billyjohnwel.mapula@g.msuiit.edu.ph', 'Billy Johnwel Mapula', 'Tau'),
  ('2026-0113', 'lyanacorraine.merto@g.msuiit.edu.ph', 'Lyana Corrine Merto', 'Tau'),
  ('2026-0114', 'raniatujannah.mohamad@g.msuiit.edu.ph', 'Raniatu-Jannah Mohamad', 'Tau'),
  ('2026-0115', 'cherrymae.palubon@g.msuiit.edu.ph', 'Cherry Mae Palubon', 'Tau'),
  ('2026-0116', 'johnyssa.pusod@g.msuiit.edu.ph', 'Johnyssa Pusod', 'Tau'),
  ('2026-0117', 'denisemikhyla.raiz@g.msuiit.edu.ph', 'Denise Mikhyla Raiz', 'Tau'),
  ('2026-0118', 'maryalicia.silva@g.msuiit.edu.ph', 'Mary Alicia Silva', 'Tau'),
  ('2026-0119', 'alexiequeen.suminguit@g.msuiit.edu.ph', 'Alexie Queen Suminguit', 'Tau'),
  ('2026-0120', 'christiannibiel.villaruz@g.msuiit.edu.ph', 'Christianni Biel Villaruz', 'Tau'),
  ('2026-0121', 'aiman.yahya@g.msuiit.edu.ph', 'Aiman Yahya', 'Tau');

-- A profile may survive under its email while its student number is missing.
-- Normalize those rows first so the student_id upsert below cannot duplicate it.
UPDATE public.profiles AS p
SET student_id = expected.student_id,
    full_name = expected.full_name,
    role = 'student',
    grade_level = 10,
    section = expected.section,
    deleted_at = NULL
FROM expected_it10_grade10 AS expected
WHERE lower(p.email) = lower(expected.email)
  AND p.student_id IS DISTINCT FROM expected.student_id
  AND NOT EXISTS (
    SELECT 1 FROM public.profiles AS existing
    WHERE existing.student_id = expected.student_id
      AND existing.id <> p.id
  );

INSERT INTO public.profiles (
  student_id, email, pin, pin_hash, full_name, role, grade_level, section,
  pin_must_change, failed_login_attempts, locked_until, deleted_at
)
SELECT
  student_id, email, '1234', NULL, full_name, 'student', 10, section,
  true, 0, NULL, NULL
FROM expected_it10_grade10
ON CONFLICT (student_id) DO UPDATE
SET email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    role = 'student',
    grade_level = 10,
    section = EXCLUDED.section,
    deleted_at = NULL,
    pin = '1234',
    pin_hash = NULL,
    pin_must_change = true,
    failed_login_attempts = 0,
    locked_until = NULL;

WITH canonical_course AS (
  SELECT id
  FROM public.courses
  WHERE upper(btrim(code)) = 'IT10'
  ORDER BY created_at ASC, id ASC
  LIMIT 1
)
INSERT INTO public.enrollments (student_id, course_id)
SELECT p.id, course.id
FROM expected_it10_grade10 AS expected
JOIN public.profiles AS p ON p.student_id = expected.student_id
CROSS JOIN canonical_course AS course
ON CONFLICT (student_id, course_id) DO NOTHING;

WITH roster_profiles AS (
  SELECT p.id, p.student_id, p.email, p.username, p.employee_id
  FROM public.profiles AS p
  JOIN expected_it10_grade10 AS expected ON expected.student_id = p.student_id
), raw_keys AS (
  SELECT 'pin:' || id::text AS value FROM roster_profiles
  UNION ALL SELECT 'login:profile:' || id::text FROM roster_profiles
  UNION ALL SELECT 'secret:' || id::text FROM roster_profiles
  UNION ALL SELECT 'login:ident:' || lower(student_id) FROM roster_profiles
  UNION ALL SELECT 'login:ident:' || lower(email) FROM roster_profiles WHERE email IS NOT NULL
  UNION ALL SELECT 'login:ident:' || lower(username) FROM roster_profiles WHERE username IS NOT NULL
  UNION ALL SELECT 'login:ident:' || lower(employee_id) FROM roster_profiles WHERE employee_id IS NOT NULL
), bucket_keys AS (
  SELECT encode(extensions.digest(value, 'sha256'), 'hex') AS value FROM raw_keys
)
DELETE FROM public.auth_rate_limits AS limits
USING bucket_keys
WHERE limits.bucket_key = bucket_keys.value;

DO $$
DECLARE
  expected_count integer;
  profile_count integer;
  enrollment_count integer;
  credential_count integer;
BEGIN
  SELECT count(*) INTO expected_count FROM expected_it10_grade10;

  SELECT count(*) INTO profile_count
  FROM expected_it10_grade10 AS expected
  JOIN public.profiles AS p ON p.student_id = expected.student_id
  WHERE p.role = 'student'
    AND p.deleted_at IS NULL
    AND p.grade_level = 10
    AND p.section = expected.section
    AND lower(p.email) = lower(expected.email);

  SELECT count(*) INTO enrollment_count
  FROM expected_it10_grade10 AS expected
  JOIN public.profiles AS p ON p.student_id = expected.student_id
  WHERE EXISTS (
    SELECT 1
    FROM public.enrollments AS e
    JOIN public.courses AS c ON c.id = e.course_id
    WHERE e.student_id = p.id
      AND upper(btrim(c.code)) = 'IT10'
  );

  SELECT count(*) INTO credential_count
  FROM expected_it10_grade10 AS expected
  JOIN public.profiles AS p ON p.student_id = expected.student_id
  WHERE p.pin = '1234'
    AND p.pin_hash IS NULL
    AND p.pin_must_change = true
    AND coalesce(p.failed_login_attempts, 0) = 0
    AND p.locked_until IS NULL;

  IF expected_count <> 122
     OR profile_count <> expected_count
     OR enrollment_count <> expected_count
     OR credential_count <> expected_count THEN
    RAISE EXCEPTION
      'Grade 10 IT10 reconciliation failed: expected=%, profiles=%, enrollments=%, credentials=%',
      expected_count, profile_count, enrollment_count, credential_count;
  END IF;

  RAISE NOTICE
    'Grade 10 IT10 reconciliation complete: % profiles, % enrollments, % temporary credentials',
    profile_count, enrollment_count, credential_count;
END $$;
