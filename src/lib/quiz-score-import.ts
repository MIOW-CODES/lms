import * as XLSX from "xlsx";
import type { Profile } from "@/lib/lms";

export type QuizScoreImportStatus = "ready" | "blank" | "unmatched" | "invalid" | "filtered";

export interface QuizScoreImportRow {
  line: number;
  student: Profile | null;
  rawIdentifier: string;
  rawName: string;
  rawSection: string;
  rawScore: string;
  score: number | null;
  status: QuizScoreImportStatus;
  message?: string;
}

export interface QuizScoreImportResult {
  rows: QuizScoreImportRow[];
  matchedCount: number;
  readyCount: number;
  blankCount: number;
  unmatchedCount: number;
  invalidCount: number;
  filteredCount: number;
}

function normalizeHeader(value: unknown): string {
  return String(value ?? "")
    .toLowerCase()
    .trim()
    .replace(/[\s_\-–—()%/.]+/g, "");
}

function normalizeStudentNumber(value: unknown): string {
  return String(value ?? "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "");
}

function normalizeName(value: unknown): string {
  return String(value ?? "")
    .toLowerCase()
    .replace(/[,.'"-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function parseQuizScoreSpreadsheet(
  buffer: ArrayBuffer | Uint8Array | string,
  roster: Profile[],
  sectionFilter: string,
): QuizScoreImportResult {
  const workbook =
    typeof buffer === "string"
      ? XLSX.read(buffer, { type: "string", raw: true })
      : XLSX.read(buffer, { type: "array", raw: true });
  const sheet = workbook.Sheets[workbook.SheetNames[0] ?? ""];
  if (!sheet) throw new Error("The spreadsheet does not contain a worksheet.");
  const rawRows = XLSX.utils.sheet_to_json<unknown[]>(sheet, { header: 1, defval: "" });

  let headerIndex = -1;
  let idCol = -1;
  let nameCol = -1;
  let sectionCol = -1;
  let scoreCol = -1;
  for (let rowIndex = 0; rowIndex < Math.min(10, rawRows.length); rowIndex++) {
    const row = rawRows[rowIndex] ?? [];
    const columns = row.map(normalizeHeader);
    const foundId = columns.findIndex((name) =>
      ["studentno", "studentid", "idnumber", "lrn", "id"].includes(name),
    );
    const foundScore = columns.findIndex((name) =>
      ["quizscore", "score", "quiz4", "quiz4score"].includes(name),
    );
    if (foundId >= 0 && foundScore >= 0) {
      headerIndex = rowIndex;
      idCol = foundId;
      nameCol = columns.findIndex((name) => ["name", "studentname", "fullname"].includes(name));
      sectionCol = columns.findIndex((name) => ["section", "class"].includes(name));
      scoreCol = foundScore;
      break;
    }
  }
  if (headerIndex < 0) {
    throw new Error('Could not find the required "Student No" and "Quiz Score" columns.');
  }

  const byNumber = new Map<string, Profile>();
  const byNameAndSection = new Map<string, Profile[]>();
  for (const student of roster) {
    const number = normalizeStudentNumber(student.student_id);
    if (number) byNumber.set(number, student);
    const key = `${normalizeName(student.full_name)}|${normalizeName(student.section)}`;
    byNameAndSection.set(key, [...(byNameAndSection.get(key) ?? []), student]);
  }

  const rows: QuizScoreImportRow[] = rawRows.slice(headerIndex + 1).map((row, index) => {
    const rawIdentifier = String(row[idCol] ?? "").trim();
    const rawName = nameCol >= 0 ? String(row[nameCol] ?? "").trim() : "";
    const rawSection = sectionCol >= 0 ? String(row[sectionCol] ?? "").trim() : "";
    const rawScore = String(row[scoreCol] ?? "").trim();
    const line = headerIndex + index + 2;

    if (
      sectionFilter !== "all" &&
      rawSection &&
      normalizeName(rawSection) !== normalizeName(sectionFilter)
    ) {
      return {
        line,
        student: null,
        rawIdentifier,
        rawName,
        rawSection,
        rawScore,
        score: null,
        status: "filtered",
      };
    }

    let student = rawIdentifier ? byNumber.get(normalizeStudentNumber(rawIdentifier)) : undefined;
    if (!student && rawName) {
      const matches =
        byNameAndSection.get(`${normalizeName(rawName)}|${normalizeName(rawSection)}`) ?? [];
      if (matches.length === 1) student = matches[0];
    }
    if (!student) {
      return {
        line,
        student: null,
        rawIdentifier,
        rawName,
        rawSection,
        rawScore,
        score: null,
        status: "unmatched",
        message: "No enrolled student matched this student number or name and section.",
      };
    }
    if (
      sectionFilter !== "all" &&
      normalizeName(student.section) !== normalizeName(sectionFilter)
    ) {
      return {
        line,
        student: null,
        rawIdentifier,
        rawName,
        rawSection,
        rawScore,
        score: null,
        status: "filtered",
      };
    }
    if (rawSection && normalizeName(rawSection) !== normalizeName(student.section)) {
      return {
        line,
        student,
        rawIdentifier,
        rawName,
        rawSection,
        rawScore,
        score: null,
        status: "invalid",
        message: `Section mismatch: roster says ${student.section ?? "no section"}.`,
      };
    }
    if (!rawScore) {
      return {
        line,
        student,
        rawIdentifier,
        rawName,
        rawSection,
        rawScore,
        score: null,
        status: "blank",
      };
    }
    const score = Number(rawScore);
    if (!Number.isFinite(score) || score < 0 || score > 100000) {
      return {
        line,
        student,
        rawIdentifier,
        rawName,
        rawSection,
        rawScore,
        score: null,
        status: "invalid",
        message: `Invalid score: ${rawScore}. Enter a number from 0 to 100000.`,
      };
    }
    return {
      line,
      student,
      rawIdentifier,
      rawName,
      rawSection,
      rawScore,
      score: Math.round(score * 100) / 100,
      status: "ready",
    };
  });

  const seen = new Map<string, number>();
  rows.forEach((row, index) => {
    if (!row.student || row.status === "filtered") return;
    const previous = seen.get(row.student.id);
    if (previous !== undefined) {
      for (const duplicateIndex of [previous, index]) {
        const duplicateRow = rows[duplicateIndex];
        if (!duplicateRow) continue;
        rows[duplicateIndex] = {
          ...duplicateRow,
          status: "invalid",
          score: null,
          message: "Student appears more than once in the import file.",
        };
      }
    } else {
      seen.set(row.student.id, index);
    }
  });

  return {
    rows,
    matchedCount: rows.filter((row) => row.student != null).length,
    readyCount: rows.filter((row) => row.status === "ready").length,
    blankCount: rows.filter((row) => row.status === "blank").length,
    unmatchedCount: rows.filter((row) => row.status === "unmatched").length,
    invalidCount: rows.filter((row) => row.status === "invalid").length,
    filteredCount: rows.filter((row) => row.status === "filtered").length,
  };
}
