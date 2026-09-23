/**
 * Import a subject database (CSV or JSON) into the MIOW-LMS `subjects` catalog.
 *
 * Usage:
 *   bun run scripts/import-subjects.ts <file.csv|file.json> [--offer] [--enroll]
 *
 * Flags:
 *   --offer    Also create a `courses` offering for each subject (idempotent by code).
 *   --enroll   With --offer, enroll students whose `section` matches the subject's section.
 *
 * CSV headers (case-insensitive, flexible aliases):
 *   code        (required)  e.g. TVE100
 *   title       (required)  e.g. The Teacher and the Community
 *   units       (optional)
 *   lecture     (optional)  lecture hours
 *   lab         (optional)  lab hours
 *   description (optional)
 *   prereq      (optional)  prerequisites
 *   level       (optional)  jhs | shs | college (default college)
 *   program     (optional)  e.g. BTVTED-DT
 *   year        (optional)  1..4 college year
 *   term        (optional)  e.g. 1st Semester
 *
 * JSON may be either an array of objects or { subjects: [...] }.
 *
 * Safe to re-run: subjects upsert on `code`, offerings upsert on `code`.
 */
import { readFile } from "node:fs/promises";
import path from "node:path";
import { Pool } from "pg";

const DATABASE_URL =
  process.env["DATABASE_URL"] ?? "postgres://miow:miow_dev_password@localhost:5432/miow";

type SubjectInput = {
  code: string;
  title: string;
  units?: number | null;
  lecture_hours?: number | null;
  lab_hours?: number | null;
  description?: string | null;
  prerequisites?: string | null;
  education_level?: "jhs" | "shs" | "college" | null;
  program?: string | null;
  college_year?: number | null;
  term?: string | null;
  /** Optional cohort/section to auto-enroll (e.g. "B8"). */
  section?: string | null;
};

/** Parse a minimal CSV (handles quoted fields and commas inside quotes). */
function parseCsv(text: string): Array<Record<string, string>> {
  const rows: string[][] = [];
  let field = "";
  let row: string[] = [];
  let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]!;
    if (inQuotes) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else inQuotes = false;
      } else field += ch;
    } else if (ch === '"') inQuotes = true;
    else if (ch === ",") {
      row.push(field);
      field = "";
    } else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && text[i + 1] === "\n") i++;
      row.push(field);
      field = "";
      if (row.some((c) => c.trim() !== "")) rows.push(row);
      row = [];
    } else field += ch;
  }
  if (field !== "" || row.length) {
    row.push(field);
    if (row.some((c) => c.trim() !== "")) rows.push(row);
  }
  if (!rows.length) return [];
  const headers = rows[0]!.map((h) => h.trim().toLowerCase());
  return rows.slice(1).map((r) => {
    const obj: Record<string, string> = {};
    headers.forEach((h, i) => (obj[h] = (r[i] ?? "").trim()));
    return obj;
  });
}

const pick = (row: Record<string, string>, aliases: string[]): string | undefined => {
  for (const a of aliases) {
    const v = row[a];
    if (v != null && v !== "") return v;
  }
  return undefined;
};

const numOrNull = (v: string | undefined): number | null => {
  if (v == null || v === "") return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

function normalize(raw: Record<string, unknown>): SubjectInput | null {
  const row: Record<string, string> = {};
  for (const [k, v] of Object.entries(raw)) row[k.toLowerCase()] = v == null ? "" : String(v);
  const code = pick(row, ["code", "subject_code", "subject code", "course_code"]);
  const title = pick(row, ["title", "subject_title", "descriptive_title", "name", "description_title"]);
  if (!code || !title) return null;
  const levelRaw = pick(row, ["level", "education_level", "education level"])?.toLowerCase();
  const level =
    levelRaw === "jhs" || levelRaw === "shs" || levelRaw === "college" ? levelRaw : "college";
  return {
    code: code.trim().toUpperCase(),
    title: title.trim(),
    units: numOrNull(pick(row, ["units", "credit", "credits", "unit"])),
    lecture_hours: numOrNull(pick(row, ["lecture", "lecture_hours", "lec", "lec_hours"])),
    lab_hours: numOrNull(pick(row, ["lab", "lab_hours", "laboratory"])),
    description: pick(row, ["description", "desc", "course_description"]) ?? null,
    prerequisites: pick(row, ["prereq", "prerequisites", "pre_requisite", "pre-requisite"]) ?? null,
    education_level: level,
    program: pick(row, ["program", "course", "degree", "program_code"]) ?? null,
    college_year: numOrNull(pick(row, ["year", "college_year", "year_level", "yr"])),
    term: pick(row, ["term", "semester", "sem"]) ?? null,
    section: pick(row, ["section", "cohort", "block"]) ?? null,
  };
}

async function loadSubjects(file: string): Promise<SubjectInput[]> {
  const text = await readFile(file, "utf-8");
  const ext = path.extname(file).toLowerCase();
  let records: Array<Record<string, unknown>> = [];
  if (ext === ".json") {
    const parsed = JSON.parse(text) as unknown;
    if (Array.isArray(parsed)) records = parsed as Array<Record<string, unknown>>;
    else if (parsed && typeof parsed === "object" && Array.isArray((parsed as any).subjects))
      records = (parsed as any).subjects as Array<Record<string, unknown>>;
  } else {
    records = parseCsv(text);
  }
  return records.map(normalize).filter((s): s is SubjectInput => s != null);
}

async function main() {
  const args = process.argv.slice(2);
  const file = args.find((a) => !a.startsWith("--"));
  const offer = args.includes("--offer");
  const enroll = args.includes("--enroll");
  if (!file) {
    console.error("Usage: bun run scripts/import-subjects.ts <file.csv|file.json> [--offer] [--enroll]");
    process.exit(1);
  }

  const subjects = await loadSubjects(file);
  if (!subjects.length) {
    console.error("[import-subjects] No valid subject rows found (need at least code + title).");
    process.exit(1);
  }
  console.log(`[import-subjects] Parsed ${subjects.length} subject(s) from ${file}`);

  const pool = new Pool({ connectionString: DATABASE_URL });
  try {
    let upserted = 0;
    for (const s of subjects) {
      await pool.query(
        `INSERT INTO public.subjects
           (code, title, units, lecture_hours, lab_hours, description, prerequisites,
            education_level, program, college_year, term, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11, now())
         ON CONFLICT (code) DO UPDATE SET
           title = EXCLUDED.title,
           units = EXCLUDED.units,
           lecture_hours = EXCLUDED.lecture_hours,
           lab_hours = EXCLUDED.lab_hours,
           description = EXCLUDED.description,
           prerequisites = EXCLUDED.prerequisites,
           education_level = EXCLUDED.education_level,
           program = EXCLUDED.program,
           college_year = EXCLUDED.college_year,
           term = EXCLUDED.term,
           updated_at = now()`,
        [
          s.code,
          s.title,
          s.units,
          s.lecture_hours,
          s.lab_hours,
          s.description,
          s.prerequisites,
          s.education_level,
          s.program,
          s.college_year,
          s.term,
        ],
      );
      upserted++;
    }
    console.log(`[import-subjects] Upserted ${upserted} subject(s) into public.subjects.`);

    if (offer) {
      let offered = 0;
      for (const s of subjects) {
        const gradeLevel =
          s.education_level === "college" && s.college_year ? 12 + s.college_year : 10;
        await pool.query(
          `INSERT INTO public.courses (title, code, grade_level, education_level, college_year, program, color, grading_system, subject_id)
           VALUES ($1,$2,$3,$4,$5,$6,'indigo',$7, (SELECT id FROM public.subjects WHERE code = $2))
           ON CONFLICT (code) DO UPDATE SET
             title = EXCLUDED.title,
             grade_level = EXCLUDED.grade_level,
             education_level = EXCLUDED.education_level,
             college_year = EXCLUDED.college_year,
             program = EXCLUDED.program,
             subject_id = (SELECT id FROM public.subjects WHERE code = EXCLUDED.code)`,
          [
            s.title,
            s.code,
            gradeLevel,
            s.education_level,
            s.college_year,
            s.program,
            s.education_level === "college" ? "college_semestral" : "k12_quarterly",
          ],
        );
        offered++;
      }
      console.log(`[import-subjects] Created/updated ${offered} course offering(s).`);

      if (enroll) {
        // Enroll students whose `section` matches the section declared on the
        // subject row (if any). Subjects without a section are skipped.
        let total = 0;
        for (const s of subjects) {
          if (!s.section) continue;
          const res = await pool.query(
            `INSERT INTO public.enrollments (student_id, course_id)
             SELECT p.id, c.id
             FROM public.profiles p
             JOIN public.courses c ON c.code = $1
             WHERE p.role = 'student' AND p.deleted_at IS NULL
               AND p.section = $2
             ON CONFLICT (student_id, course_id) DO NOTHING`,
            [s.code, s.section],
          );
          total += res.rowCount ?? 0;
        }
        console.log(`[import-subjects] Auto-enrolled ${total} student(s) by section.`);
      }
    }
    console.log("[import-subjects] Done.");
  } finally {
    await pool.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
