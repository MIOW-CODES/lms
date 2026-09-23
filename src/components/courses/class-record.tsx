import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { Download, FileSpreadsheet } from "lucide-react";
import { toast } from "sonner";
import {
  listAssignments,
  listQuizScoresForCourse,
  listQuizzes,
  listSubmissionsForAssignment,
  gradeRemarks,
  type Profile,
} from "@/lib/lms";
import { buildXlsx, downloadBlob, type XlsxCell } from "@/lib/xlsx";
import { Badge, Card, EmptyState } from "@/components/lms";
import { UserAvatar } from "@/components/ui-elements";
import { cn } from "@/lib/utils";

/**
 * Class Record / grade sheet: a matrix of students against every worksheet and
 * assignment in a course, with per-student totals, percentage and remarks.
 * Exportable to .xlsx and CSV so teachers can manage records offline.
 */
export function ClassRecord({
  courseId,
  courseCode,
  roster,
}: {
  courseId: string;
  courseCode: string;
  roster: Profile[];
}) {
  const { data: quizzes } = useQuery({
    queryKey: ["quizzes"],
    queryFn: listQuizzes,
  });
  const { data: assignments } = useQuery({
    queryKey: ["assignments"],
    queryFn: listAssignments,
  });
  const { data: quizScores } = useQuery({
    queryKey: ["quiz-scores", courseId],
    queryFn: () => listQuizScoresForCourse(courseId),
    enabled: !!courseId,
  });

  const courseQuizzes = useMemo(
    () => (quizzes ?? []).filter((q) => q.course_id === courseId),
    [quizzes, courseId],
  );
  const courseAssignments = useMemo(
    () => (assignments ?? []).filter((a) => a.course_id === courseId),
    [assignments, courseId],
  );

  // Assignment scores: one submission query per assignment (parallel).
  const { data: assignmentScores } = useQuery({
    queryKey: ["assignment-scores", courseId, courseAssignments.map((a) => a.id).join(",")],
    queryFn: async () => {
      const results = await Promise.all(
        courseAssignments.map((a) =>
          listSubmissionsForAssignment(a.id)
            .then((subs) => [a.id, subs] as const)
            .catch(() => [a.id, []] as const),
        ),
      );
      const map = new Map<string, Map<string, number | null>>();
      for (const [id, subs] of results) {
        const byStudent = new Map<string, number | null>();
        for (const s of subs) byStudent.set(s.student_id, s.score);
        map.set(id, byStudent);
      }
      return map;
    },
    enabled: !!courseId && courseAssignments.length > 0,
  });

  const quizById = useMemo(() => {
    const m = new Map<string, { title: string; total: number }>();
    for (const q of quizScores ?? []) {
      let total = 0;
      for (const s of Object.values(q.scores)) total = Math.max(total, s.total);
      m.set(q.quiz_id, { title: q.title, total });
    }
    return m;
  }, [quizScores]);

  const columns = useMemo(() => {
    const cols: Array<{ key: string; label: string; total: number; kind: "quiz" | "assignment" }> =
      [];
    for (const q of courseQuizzes) {
      const meta = quizById.get(q.id);
      cols.push({ key: `q:${q.id}`, label: q.title, total: meta?.total ?? 0, kind: "quiz" });
    }
    for (const a of courseAssignments) {
      cols.push({
        key: `a:${a.id}`,
        label: a.title,
        total: a.total_points ?? 0,
        kind: "assignment",
      });
    }
    return cols;
  }, [courseQuizzes, courseAssignments, quizById]);

  const cellScore = (
    studentId: string,
    col: { key: string; kind: "quiz" | "assignment" },
  ): number | null => {
    if (col.kind === "quiz") {
      const quizId = col.key.slice(2);
      const q = (quizScores ?? []).find((x) => x.quiz_id === quizId);
      return q?.scores[studentId]?.score ?? null;
    }
    const assignmentId = col.key.slice(2);
    return assignmentScores?.get(assignmentId)?.get(studentId) ?? null;
  };

  const rows = useMemo(() => {
    // cellScore closes over quizScores/assignmentScores, which are both in the
    // dependency list below — so the memo recomputes whenever scores change.
    return roster.map((s) => {
      let obtained = 0;
      let possible = 0;
      const cells = columns.map((col) => {
        const score = cellScore(s.id, col);
        if (score != null && col.total > 0) {
          obtained += score;
          possible += col.total;
        }
        return score;
      });
      const pct = possible > 0 ? Math.round((obtained / possible) * 1000) / 10 : null;
      return { student: s, cells, obtained, possible, pct };
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [roster, columns, quizScores, assignmentScores]);

  const hasData = columns.length > 0 && roster.length > 0;

  const exportXlsx = () => {
    if (!hasData) {
      toast.error("Nothing to export yet.");
      return;
    }
    const header: XlsxCell[] = [
      "Student No",
      "Name",
      "Section",
      ...columns.map((c) => `${c.label} (${c.total})`),
      "Obtained",
      "Possible",
      "Percentage",
      "Remarks",
    ];
    const body: XlsxCell[][] = rows.map((r) => [
      r.student.student_id ?? "",
      r.student.full_name,
      r.student.section ?? "",
      ...r.cells.map((c) => (c == null ? "" : c)),
      r.obtained,
      r.possible,
      r.pct ?? "",
      r.pct != null ? gradeRemarks(r.pct) : "",
    ]);
    const blob = buildXlsx([{ name: "Class Record", rows: [header, ...body] }]);
    downloadBlob(blob, `${courseCode || "class"}-class-record.xlsx`);
    toast.success("Excel exported.");
  };

  const exportCsv = () => {
    if (!hasData) {
      toast.error("Nothing to export yet.");
      return;
    }
    const header = [
      "Student No",
      "Name",
      "Section",
      ...columns.map((c) => `${c.label} (${c.total})`),
      "Obtained",
      "Possible",
      "Percentage",
      "Remarks",
    ];
    const lines = rows.map((r) =>
      [
        r.student.student_id ?? "",
        r.student.full_name,
        r.student.section ?? "",
        ...r.cells.map((c) => (c == null ? "" : String(c))),
        String(r.obtained),
        String(r.possible),
        r.pct != null ? String(r.pct) : "",
        r.pct != null ? gradeRemarks(r.pct) : "",
      ]
        .map((v) => `"${v.replace(/"/g, '""')}"`)
        .join(","),
    );
    const csv = [header.map((h) => `"${h}"`).join(","), ...lines].join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    downloadBlob(blob, `${courseCode || "class"}-class-record.csv`);
    toast.success("CSV exported.");
  };

  if (!courseId)
    return <EmptyState title="Pick a course" sub="Choose a course to view its class record." />;
  if (!hasData) {
    return (
      <EmptyState
        title="No assessments yet"
        sub="Post worksheets or assignments so scores can appear in the class record."
      />
    );
  }

  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <p className="text-xs text-muted-foreground">
          {columns.length} assessment{columns.length !== 1 ? "s" : ""} · {roster.length} student
          {roster.length !== 1 ? "s" : ""}
        </p>
        <div className="flex gap-2">
          <button
            onClick={exportCsv}
            className="flex items-center gap-1.5 rounded-xl border border-border bg-card px-4 py-2 text-sm font-semibold hover:bg-muted"
          >
            <Download className="h-4 w-4" /> CSV
          </button>
          <button
            onClick={exportXlsx}
            className="flex items-center gap-1.5 rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground hover:opacity-90"
          >
            <FileSpreadsheet className="h-4 w-4" /> Excel
          </button>
        </div>
      </div>

      <Card className="custom-scrollbar overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs uppercase tracking-wide text-muted-foreground">
              <th className="sticky left-0 z-10 bg-card p-4">Student</th>
              {columns.map((c) => (
                <th key={c.key} className="max-w-[140px] truncate p-4 text-center" title={c.label}>
                  {c.label}
                  <span className="block text-[10px] font-normal normal-case text-muted-foreground">
                    /{c.total}
                  </span>
                </th>
              ))}
              <th className="p-4 text-center">Total</th>
              <th className="p-4 text-center">%</th>
              <th className="p-4">Remarks</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {rows.map((r) => (
              <tr key={r.student.id}>
                <td className="sticky left-0 z-10 bg-card p-4">
                  <div className="flex items-center gap-2.5">
                    <UserAvatar src={r.student.avatar_url} name={r.student.full_name} />
                    <div>
                      <p className="font-semibold">{r.student.full_name}</p>
                      <p className="text-xs text-muted-foreground">
                        {r.student.student_id} · {r.student.section ?? "—"}
                      </p>
                    </div>
                  </div>
                </td>
                {r.cells.map((c, i) => (
                  <td key={columns[i]!.key} className="p-4 text-center">
                    {c == null ? (
                      <span className="text-muted-foreground">—</span>
                    ) : (
                      <span className="font-semibold">{c}</span>
                    )}
                  </td>
                ))}
                <td className="p-4 text-center font-semibold">
                  {r.obtained}/{r.possible}
                </td>
                <td className="p-4 text-center">
                  <span
                    className={cn(
                      "font-display font-bold",
                      r.pct != null && r.pct < 75 && "text-rose-600 dark:text-rose-400",
                    )}
                  >
                    {r.pct != null ? `${r.pct}%` : "—"}
                  </span>
                </td>
                <td className="p-4">
                  {r.pct != null ? (
                    <Badge
                      tone={
                        r.pct >= 90
                          ? "green"
                          : r.pct >= 80
                            ? "indigo"
                            : r.pct >= 75
                              ? "amber"
                              : "red"
                      }
                    >
                      {gradeRemarks(r.pct)}
                    </Badge>
                  ) : (
                    "—"
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  );
}
