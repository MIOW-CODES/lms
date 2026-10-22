import { useEffect, useMemo, useState } from "react";
import { createFileRoute, useNavigate, useRouterState } from "@tanstack/react-router";
import { courseLevelLabel } from "@/lib/course-levels";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  Check,
  ChevronsUpDown,
  Download,
  FileSpreadsheet,
  FileUp,
  Plus,
  Search,
  Send,
  X,
} from "lucide-react";
import { toast } from "sonner";
import { LoadingSkeleton, UserAvatar } from "@/components/ui-elements";
import { GradebookImportModal } from "@/components/courses/gradebook-import-modal";
import { QuizScoreImportModal } from "@/components/courses/quiz-score-import-modal";
import { ATTENDANCE_LIMIT_GRADES } from "@/components/courses/constants";
import {
  attendancePercent,
  enrollmentsForCourse,
  gradeRemarks,
  listAllAttendance,
  listCourses,
  listGradesForCourse,
  listStudents,
  termLabel,
  termOptions,
  transmute,
  upsertGrade,
  weightedInitial,
  type AttendanceLog,
  listQuizScoresForCourse,
  createCourseQuizScoreItem,
  saveCourseQuizScore,
  importCourseQuizScores,
  type QuizCourseScore,
  type GradeOverrideFlag,
} from "@/lib/lms";
import { buildXlsx, downloadBlob, type XlsxCell } from "@/lib/xlsx";
import { ClassRecord } from "@/components/courses/class-record";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import {
  OverrideFlagToggle,
  BulkColumnMenu,
  BulkFillModal,
  COLUMN_CONFIG,
  applyBulkColumnFill,
  clearColumnOverridesForRoster,
  extractOverrideFlagsPayload,
  formatOverridesSummary,
  type ColumnKey,
  type OverridesState,
} from "@/components/courses/grade-overrides";
import {
  ADMIN_NAV,
  TEACHER_NAV,
  AppShell,
  Badge,
  Card,
  EmptyState,
  MotionCard,
  useProfile,
} from "@/components/lms";
import { cn, sanitizeDecimal } from "@/lib/utils";

export const Route = createFileRoute("/dashboard/admin/grades")({
  head: () => ({
    meta: [
      { title: "Gradebook | MIOW - Integrated Developmental School" },
      {
        name: "description",
        content: "Encode quarterly grades with automatic DepEd transmutation.",
      },
      { property: "og:title", content: "Gradebook | MIOW - Integrated Developmental School" },
      {
        property: "og:description",
        content: "Encode quarterly grades with automatic DepEd transmutation.",
      },
    ],
  }),
  component: GradebookPage,
});

interface CellState {
  ww: string;
  pt: string;
  ex: string;
}

export function GradebookPage() {
  const profile = useProfile(["admin", "teacher"]);
  const navigate = useNavigate();
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const isPortalMismatch =
    !!profile &&
    ((profile.role === "teacher" && pathname.startsWith("/dashboard/admin/")) ||
      (profile.role === "admin" && pathname.startsWith("/dashboard/teacher/")));
  const qc = useQueryClient();
  const { data: courses } = useQuery({
    queryKey: ["courses"],
    queryFn: listCourses,
    enabled: !!profile && !isPortalMismatch,
  });
  const { data: students } = useQuery({
    queryKey: ["students"],
    queryFn: listStudents,
    enabled: !!profile && !isPortalMismatch,
  });
  // Gate attendance feeds the Attendance (10%) component of the grading scheme.
  const { data: allLogs } = useQuery({
    queryKey: ["all-attendance"],
    queryFn: () => listAllAttendance(ATTENDANCE_LIMIT_GRADES),
    enabled: !!profile && !isPortalMismatch,
  });

  const [courseId, setCourseId] = useState("");
  const [quarter, setQuarter] = useState(1);
  const [section, setSection] = useState("all");
  const [cells, setCells] = useState<Record<string, CellState>>({});
  const [overrides, setOverrides] = useState<OverridesState>({});
  const [bulkFillColumn, setBulkFillColumn] = useState<ColumnKey | null>(null);
  const [saving, setSaving] = useState(false);
  const [published, setPublished] = useState(false);
  const [gradeTab, setGradeTab] = useState<"grades" | "quizzes" | "class">("class");
  const [search, setSearch] = useState("");
  const [coursePickerOpen, setCoursePickerOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [quizScoreImportOpen, setQuizScoreImportOpen] = useState(false);
  const [creatingQuizScoreItem, setCreatingQuizScoreItem] = useState(false);
  const [quizScoreDrafts, setQuizScoreDrafts] = useState<Record<string, string>>({});
  const [recordDirty, setRecordDirty] = useState(false);
  const leaveRecord = () => !recordDirty || window.confirm("Discard unsaved class-record changes?");

  const accessibleCourses = useMemo(
    () =>
      (courses ?? []).filter((item) =>
        profile?.role === "teacher" ? item.teacher_id === profile.id : true,
      ),
    [courses, profile],
  );
  const course = useMemo(
    () => accessibleCourses.find((item) => item.id === courseId),
    [accessibleCourses, courseId],
  );

  useEffect(() => {
    if (!profile || !isPortalMismatch) return;
    navigate({
      to: profile.role === "teacher" ? "/dashboard/teacher/grades" : "/dashboard/admin/grades",
      replace: true,
    });
  }, [isPortalMismatch, navigate, profile]);

  const attByStudent = useMemo(() => {
    const grouped = new Map<string, AttendanceLog[]>();
    (allLogs ?? []).forEach((l) => {
      const arr = grouped.get(l.student_id) ?? [];
      arr.push(l);
      grouped.set(l.student_id, arr);
    });
    const out = new Map<string, number | null>();
    grouped.forEach((logs, id) => out.set(id, attendancePercent(logs)));
    return out;
  }, [allLogs]);
  const attOf = (sid: string): number | null => attByStudent.get(sid) ?? null;

  const { data: enrolledIds } = useQuery({
    queryKey: ["enrollments", courseId],
    queryFn: () => enrollmentsForCourse(courseId),
    enabled: !!course,
  });
  const { data: existing } = useQuery({
    queryKey: ["course-grades", courseId, quarter],
    queryFn: () => listGradesForCourse(courseId, quarter),
    enabled: !!course,
  });
  const { data: quizScores, error: quizScoresError } = useQuery({
    queryKey: ["quiz-scores", courseId],
    queryFn: () => listQuizScoresForCourse(courseId),
    enabled: !!course,
  });
  const quiz4Item = (quizScores ?? []).find(
    (item) => item.kind === "manual" && item.title === "Quiz 4",
  );

  useEffect(() => {
    if (quizScoresError) toast.error("Could not load quiz scores for this course.");
  }, [quizScoresError]);

  useEffect(() => {
    if (!courses) return;
    if (!accessibleCourses.some((item) => item.id === courseId)) {
      setCourseId(accessibleCourses[0]?.id ?? "");
      setRecordDirty(false);
    }
  }, [accessibleCourses, courseId, courses]);

  useEffect(() => {
    const next: Record<string, CellState> = {};
    const nextOverrides: OverridesState = {};
    (existing ?? []).forEach((g) => {
      next[g.student_id] = {
        ww: g.written_work_score?.toString() ?? "",
        pt: g.performance_task_score?.toString() ?? "",
        ex: g.exam_score?.toString() ?? "",
      };
      if (g.override_flags && typeof g.override_flags === "object") {
        const studentFlags: Partial<Record<ColumnKey, GradeOverrideFlag>> = {};
        (["ww", "pt", "ex"] as const).forEach((col) => {
          const flag = g.override_flags?.[col];
          if (flag) {
            studentFlags[col] = {
              note: flag.note ?? null,
              ...(flag.by ? { by: flag.by } : {}),
              ...(flag.at ? { at: flag.at } : {}),
            };
          }
        });
        if (Object.keys(studentFlags).length > 0) {
          nextOverrides[g.student_id] = studentFlags;
        }
      }
    });
    setCells(next);
    setOverrides(nextOverrides);
    setPublished((existing ?? []).length > 0);
  }, [existing]);

  useEffect(() => {
    setSection("all");
  }, [courseId]);

  const isLoading = !courses || !students || (gradeTab === "grades" && !allLogs);

  if (!profile) return null;
  if (isPortalMismatch) return null;

  const nav = profile.role === "admin" ? ADMIN_NAV : TEACHER_NAV;
  const subtitle = profile.role === "admin" ? "Admin Console" : "Teacher Portal";

  if (isLoading)
    return (
      <AppShell nav={nav} profile={profile} subtitle={subtitle}>
        <LoadingSkeleton />
      </AppShell>
    );

  if (profile.role === "teacher" && accessibleCourses.length === 0)
    return (
      <AppShell nav={nav} profile={profile} subtitle={subtitle}>
        <EmptyState
          title="No courses assigned"
          sub="Your teacher account is active, but no courses are assigned to it yet. Ask an administrator to assign your course before entering grades."
        />
      </AppShell>
    );

  // Roster is strictly the course's enrolled students — no grade-level
  // fallback, so a failed/empty enrollment query yields an empty roster
  // instead of widening it to the whole grade level.
  const roster = (students ?? []).filter((s) => !!enrolledIds?.includes(s.id));
  const sections = [
    ...new Set(roster.map((s) => s.section).filter((x): x is string => !!x)),
  ].sort();
  const sectionRoster = section === "all" ? roster : roster.filter((s) => s.section === section);
  const q = search.toLowerCase().trim();
  const visibleRoster = q
    ? sectionRoster.filter(
        (s) =>
          s.full_name.toLowerCase().includes(q) ||
          (s.student_id ?? "").toLowerCase().includes(q) ||
          (s.email ?? "").toLowerCase().includes(q) ||
          (s.section ?? "").toLowerCase().includes(q),
      )
    : sectionRoster;

  const num = (v: string) => (v.trim() === "" ? null : Math.max(0, Math.min(100, Number(v))));

  const preview = (sid: string) => {
    const c = cells[sid];
    if (!c) return null;
    const initial = weightedInitial(num(c.ww), num(c.pt), num(c.ex), attOf(sid));
    if (initial == null) return null;
    return { initial, t: transmute(initial) };
  };

  const saveAll = async () => {
    setSaving(true);
    try {
      let n = 0;
      const valid = roster.filter((s) => {
        const c = cells[s.id];
        const ovr = overrides[s.id];
        const hasScores = c && (c.ww !== "" || c.pt !== "" || c.ex !== "");
        const hasOverrides = ovr && (ovr.ww || ovr.pt || ovr.ex);
        return hasScores || hasOverrides;
      });
      await Promise.all(
        valid.map((s) => {
          const c = cells[s.id] ?? { ww: "", pt: "", ex: "" };
          const initial = weightedInitial(num(c.ww), num(c.pt), num(c.ex), attOf(s.id));
          const override_flags = extractOverrideFlagsPayload(overrides[s.id]);
          return upsertGrade({
            student_id: s.id,
            course_id: courseId,
            quarter,
            written_work_score: num(c.ww),
            performance_task_score: num(c.pt),
            exam_score: num(c.ex),
            transmuted_final_grade: initial != null ? transmute(initial) : null,
            override_flags,
          });
        }),
      );
      n = valid.length;
      toast.success(`Saved and published grades for ${n} student${n === 1 ? "" : "s"}.`);
      setPublished(true);
      qc.invalidateQueries({ queryKey: ["course-grades", courseId, quarter] });
      qc.invalidateQueries({ queryKey: ["grades"] });
    } catch {
      toast.error("Could not save grades.");
    } finally {
      setSaving(false);
    }
  };

  const handleToggleOverride = (studentId: string, col: ColumnKey) => {
    setOverrides((prev) => {
      const studentOvr = { ...(prev[studentId] ?? {}) };
      if (studentOvr[col]) {
        delete studentOvr[col];
      } else {
        studentOvr[col] = { note: null };
      }
      return { ...prev, [studentId]: studentOvr };
    });
  };

  const handleUpdateOverrideNote = (studentId: string, col: ColumnKey, note: string) => {
    setOverrides((prev) => {
      const studentOvr = { ...(prev[studentId] ?? {}) };
      const existingFlag = studentOvr[col] ?? {};
      const trimmed = note.trim();
      studentOvr[col] = {
        ...existingFlag,
        note: trimmed ? trimmed.slice(0, 500) : null,
      };
      return { ...prev, [studentId]: studentOvr };
    });
  };

  const handleBulkFill = (col: ColumnKey, score: string, note: string) => {
    const visibleIds = visibleRoster.map((s) => s.id);
    const res = applyBulkColumnFill(cells, overrides, visibleIds, col, score, note);
    setCells(res.cells);
    setOverrides(res.overrides);
    toast.success(
      `Filled ${COLUMN_CONFIG[col].short} for ${visibleIds.length} visible student${visibleIds.length === 1 ? "" : "s"}.`,
    );
  };

  const handleClearColumnOverrides = (col: ColumnKey) => {
    const visibleIds = visibleRoster.map((s) => s.id);
    const nextOverrides = clearColumnOverridesForRoster(overrides, visibleIds, col);
    setOverrides(nextOverrides);
    toast.success(
      `Cleared ${COLUMN_CONFIG[col].short} overrides for ${visibleIds.length} visible student${visibleIds.length === 1 ? "" : "s"}.`,
    );
  };

  const handleApplyImport = async (
    updatedCells: Record<string, CellState>,
    updatedOverrides: OverridesState,
    appliedCount: number,
    saveImmediately = false,
  ) => {
    setCells(updatedCells);
    setOverrides(updatedOverrides);
    if (saveImmediately) {
      setSaving(true);
      try {
        const valid = roster.filter((s) => {
          const c = updatedCells[s.id];
          const ovr = updatedOverrides[s.id];
          const hasScores = c && (c.ww !== "" || c.pt !== "" || c.ex !== "");
          const hasOverrides = ovr && (ovr.ww || ovr.pt || ovr.ex);
          return hasScores || hasOverrides;
        });
        await Promise.all(
          valid.map((s) => {
            const c = updatedCells[s.id] ?? { ww: "", pt: "", ex: "" };
            const initial = weightedInitial(num(c.ww), num(c.pt), num(c.ex), attOf(s.id));
            const override_flags = extractOverrideFlagsPayload(updatedOverrides[s.id]);
            return upsertGrade({
              student_id: s.id,
              course_id: courseId,
              quarter,
              written_work_score: num(c.ww),
              performance_task_score: num(c.pt),
              exam_score: num(c.ex),
              transmuted_final_grade: initial != null ? transmute(initial) : null,
              override_flags,
            });
          }),
        );
        toast.success(
          `Imported and published grades for ${appliedCount} student${appliedCount === 1 ? "" : "s"}.`,
        );
        setPublished(true);
        qc.invalidateQueries({ queryKey: ["course-grades", courseId, quarter] });
        qc.invalidateQueries({ queryKey: ["grades"] });
      } catch {
        toast.error("Could not save imported grades.");
      } finally {
        setSaving(false);
      }
    } else {
      toast.success(
        `Applied grades for ${appliedCount} student${appliedCount === 1 ? "" : "s"} to gradebook. Review changes and click Save & publish.`,
      );
    }
  };

  const addQuiz4Item = async () => {
    if (!courseId) return;
    setCreatingQuizScoreItem(true);
    try {
      await createCourseQuizScoreItem(courseId, "Quiz 4");
      await qc.invalidateQueries({ queryKey: ["quiz-scores", courseId] });
      toast.success("Quiz 4 is ready in the gradebook.");
    } catch {
      toast.error("Could not add Quiz 4 to this gradebook.");
    } finally {
      setCreatingQuizScoreItem(false);
    }
  };

  const saveManualQuizScore = async (item: QuizCourseScore, studentId: string, raw: string) => {
    const key = `${item.quiz_id}:${studentId}`;
    const trimmed = raw.trim();
    const score = trimmed === "" ? null : Number(trimmed);
    if (score != null && (!Number.isFinite(score) || score < 0 || score > 100000)) {
      toast.error("Enter a score from 0 to 100000.");
      return;
    }
    try {
      await saveCourseQuizScore({ item_id: item.quiz_id, student_id: studentId, score });
      setQuizScoreDrafts((current) => {
        const next = { ...current };
        delete next[key];
        return next;
      });
      await qc.invalidateQueries({ queryKey: ["quiz-scores", courseId] });
    } catch {
      toast.error("Could not save this quiz score.");
    }
  };

  const applyQuizScoreImport = async (rows: Array<{ student_id: string; score: number }>) => {
    if (!quiz4Item) return;
    try {
      const result = await importCourseQuizScores({ item_id: quiz4Item.quiz_id, rows });
      toast.success(`Imported ${result.saved} Quiz 4 score${result.saved === 1 ? "" : "s"}.`);
      await qc.invalidateQueries({ queryKey: ["quiz-scores", courseId] });
    } catch {
      toast.error("Could not import Quiz 4 scores.");
      throw new Error("Quiz 4 score import failed");
    }
  };

  const exportCsv = () => {
    const header = [
      "Student No",
      "Name",
      "Section",
      "Attendance (10%)",
      "WW (20%)",
      "PT (40%)",
      "Exam (30%)",
      "Initial",
      "Transmuted",
      "Remarks",
      "Overrides",
    ];
    const rows = visibleRoster.map((s) => {
      const c = cells[s.id] ?? { ww: "", pt: "", ex: "" };
      const p = preview(s.id);
      const ovr = formatOverridesSummary(overrides[s.id]);
      return [
        s.student_id ?? "",
        s.full_name,
        s.section ?? "",
        attOf(s.id) ?? "",
        c.ww,
        c.pt,
        c.ex,
        p ? p.initial.toFixed(1) : "",
        p ? String(p.t) : "",
        p ? gradeRemarks(p.t) : "",
        ovr,
      ];
    });
    const csv = [header, ...rows]
      .map((r) => r.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(","))
      .join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${course?.code ?? "grades"}-Q${quarter}${section === "all" ? "" : `-${section}`}.csv`;
    a.click();
    URL.revokeObjectURL(url);
    toast.success("CSV exported.");
  };

  const exportXlsx = () => {
    const header: XlsxCell[] = [
      "Student No",
      "Name",
      "Section",
      "Attendance (10%)",
      "WW (20%)",
      "PT (40%)",
      "Exam (30%)",
      "Initial",
      "Transmuted",
      "Remarks",
      "Overrides",
    ];
    const body: XlsxCell[][] = visibleRoster.map((s) => {
      const c = cells[s.id] ?? { ww: "", pt: "", ex: "" };
      const p = preview(s.id);
      const ovr = formatOverridesSummary(overrides[s.id]);
      return [
        s.student_id ?? "",
        s.full_name,
        s.section ?? "",
        attOf(s.id) ?? "",
        c.ww,
        c.pt,
        c.ex,
        p ? Number(p.initial.toFixed(1)) : "",
        p ? p.t : "",
        p ? gradeRemarks(p.t) : "",
        ovr,
      ];
    });
    const termTag = termLabel(quarter, course).replace(/[^A-Za-z0-9]+/g, "-");
    const blob = buildXlsx([{ name: "Grades", rows: [header, ...body] }]);
    downloadBlob(
      blob,
      `${course?.code ?? "grades"}-${termTag}${section === "all" ? "" : `-${section}`}.xlsx`,
    );
    toast.success("Excel exported.");
  };

  return (
    <AppShell nav={nav} profile={profile} subtitle={subtitle}>
      <div className="mb-1 flex flex-wrap items-center gap-2">
        <h1 className="font-display text-2xl font-bold sm:text-3xl">Gradebook</h1>
        {published && <Badge tone="green">Published</Badge>}
      </div>
      <p className="mb-5 mt-1 max-w-4xl text-sm text-muted-foreground">
        {gradeTab === "class"
          ? "Record individual quizzes, examinations and performance tasks, then review class attendance. Save drafts while working; publish complete records when ready. Weights: Attendance 10% · Written Works 20% · Examination 30% · Performance Tasks 40%."
          : "Legacy category summary: enter component percentages (0–100). Records published from Class Record must be revised and republished in that tab."}
      </p>

      <div className="mb-5 grid min-w-0 grid-cols-1 gap-3 sm:flex sm:flex-wrap sm:items-center">
        <button
          type="button"
          onClick={() => setCoursePickerOpen(true)}
          aria-haspopup="dialog"
          aria-expanded={coursePickerOpen}
          aria-label={`Choose course${course ? `, current course ${course.code} ${course.title}` : ""}`}
          className="flex min-h-11 w-full min-w-0 items-center justify-between gap-3 rounded-xl border border-input bg-background px-3 text-left text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring sm:min-w-64 sm:max-w-[28rem]"
        >
          <span className="min-w-0 truncate">
            {course
              ? `${course.code} — ${course.title} (${courseLevelLabel(course)})`
              : "Choose a course"}
          </span>
          <ChevronsUpDown className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
        </button>
        <Dialog open={coursePickerOpen} onOpenChange={setCoursePickerOpen}>
          <DialogContent className="overflow-hidden p-0">
            <DialogTitle className="sr-only">Choose a course</DialogTitle>
            <DialogDescription className="sr-only">
              Search assigned courses by code, title, or grade level.
            </DialogDescription>
            <Command className="h-auto">
              <CommandInput placeholder="Search course code, title, grade..." />
              <CommandList className="max-h-[min(60vh,28rem)]">
                <CommandEmpty>No assigned course matches that search.</CommandEmpty>
                <CommandGroup>
                  {accessibleCourses.map((item) => (
                    <CommandItem
                      key={item.id}
                      value={`${item.code} ${item.title} ${courseLevelLabel(item)}`}
                      onSelect={() => {
                        if (leaveRecord()) {
                          setRecordDirty(false);
                          setCourseId(item.id);
                        }
                        setCoursePickerOpen(false);
                      }}
                      className="min-h-11"
                    >
                      <Check
                        className={cn(
                          "h-4 w-4",
                          item.id === courseId ? "opacity-100" : "opacity-0",
                        )}
                        aria-hidden
                      />
                      <span className="min-w-0">
                        <span className="block truncate font-medium">{item.title}</span>
                        <span className="block truncate text-xs text-muted-foreground">
                          {item.code} · {courseLevelLabel(item)}
                        </span>
                      </span>
                    </CommandItem>
                  ))}
                </CommandGroup>
              </CommandList>
            </Command>
          </DialogContent>
        </Dialog>
        <div className="flex w-full flex-wrap gap-1 rounded-xl bg-muted p-1 sm:w-auto">
          {termOptions(course).map((q) => (
            <button
              key={q}
              onClick={() => {
                if (leaveRecord()) {
                  setRecordDirty(false);
                  setQuarter(q);
                }
              }}
              className={cn(
                "min-h-11 flex-1 rounded-lg px-3 py-2 text-xs font-semibold sm:flex-none sm:text-sm",
                quarter === q ? "bg-card shadow-sm" : "text-muted-foreground",
              )}
            >
              {termLabel(q, course)}
            </button>
          ))}
        </div>
        {sections.length > 1 && (
          <select
            value={section}
            onChange={(e) => setSection(e.target.value)}
            aria-label="Filter by section"
            className="h-11 w-full rounded-xl border border-input bg-background px-3 text-sm outline-none focus:ring-2 focus:ring-ring sm:w-auto"
          >
            <option value="all">All sections</option>
            {sections.map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        )}
        <div className="relative min-w-0 w-full flex-1 sm:min-w-56 sm:max-w-xs">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            aria-label="Search students"
            placeholder="Search name, student no., email or section..."
            className="h-11 w-full rounded-xl border border-input bg-background pl-9 pr-3 text-sm outline-none focus:ring-2 focus:ring-ring"
          />
          {search && (
            <button
              onClick={() => setSearch("")}
              aria-label="Clear student search"
              className="absolute right-2 top-1/2 flex h-9 w-9 -translate-y-1/2 items-center justify-center rounded-md text-muted-foreground hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring"
            >
              <X className="h-4 w-4" aria-hidden />
            </button>
          )}
        </div>
        {gradeTab !== "class" && (
          <div className="flex w-full flex-wrap gap-2 sm:ml-auto sm:w-auto">
            {profile.role === "teacher" && (
              <button
                onClick={() => setImportOpen(true)}
                disabled={!courseId || roster.length === 0}
                className="flex min-h-11 flex-1 items-center justify-center gap-1.5 rounded-xl border border-primary/30 bg-primary/5 px-4 py-2.5 text-sm font-semibold text-primary hover:bg-primary/10 disabled:opacity-50 sm:flex-none"
                title="Import grades from Excel or CSV spreadsheet"
              >
                <FileUp className="h-4 w-4" /> Import
              </button>
            )}
            <button
              onClick={exportCsv}
              disabled={!courseId || visibleRoster.length === 0}
              className="flex min-h-11 flex-1 items-center justify-center gap-1.5 rounded-xl border border-border bg-card px-4 py-2.5 text-sm font-semibold hover:bg-muted disabled:opacity-50 sm:flex-none"
            >
              <Download className="h-4 w-4" /> CSV
            </button>
            <button
              onClick={exportXlsx}
              disabled={!courseId || visibleRoster.length === 0}
              className="flex min-h-11 flex-1 items-center justify-center gap-1.5 rounded-xl border border-border bg-card px-4 py-2.5 text-sm font-semibold hover:bg-muted disabled:opacity-50 sm:flex-none"
            >
              <FileSpreadsheet className="h-4 w-4" /> Excel
            </button>
            {profile.role === "teacher" ? (
              <button
                onClick={saveAll}
                disabled={saving || !courseId}
                className="flex min-h-11 flex-1 items-center justify-center gap-1.5 rounded-xl bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground hover:opacity-90 disabled:opacity-50 sm:flex-none"
              >
                <Send className="h-4 w-4" /> {saving ? "Publishing…" : "Save & publish"}
              </button>
            ) : (
              <p className="self-center text-xs text-muted-foreground">
                View-only — only the course teacher can publish grades.
              </p>
            )}
          </div>
        )}
      </div>

      {/* ── Tab Switcher ─────────────────────────────────────────── */}
      {courseId && (
        <div className="mb-5 grid w-full grid-cols-1 gap-1 rounded-xl bg-muted p-1 sm:inline-flex sm:w-fit sm:grid-cols-none">
          <button
            onClick={() => {
              if (leaveRecord()) {
                setRecordDirty(false);
                setGradeTab("grades");
              }
            }}
            className={cn(
              "min-h-11 rounded-lg px-3 py-2 text-sm font-semibold transition sm:px-5",
              gradeTab === "grades"
                ? "bg-card shadow-sm text-foreground"
                : "text-muted-foreground hover:text-foreground",
            )}
          >
            Category summary (legacy)
          </button>
          <button
            onClick={() => {
              if (leaveRecord()) {
                setRecordDirty(false);
                setGradeTab("quizzes");
              }
            }}
            className={cn(
              "min-h-11 rounded-lg px-3 py-2 text-sm font-semibold transition sm:px-5",
              gradeTab === "quizzes"
                ? "bg-card shadow-sm text-foreground"
                : "text-muted-foreground hover:text-foreground",
            )}
          >
            Quiz Scores {quizScores && quizScores.length > 0 ? `(${quizScores.length})` : ""}
          </button>
          <button
            onClick={() => setGradeTab("class")}
            className={cn(
              "min-h-11 rounded-lg px-3 py-2 text-sm font-semibold transition sm:px-5",
              gradeTab === "class"
                ? "bg-card shadow-sm text-foreground"
                : "text-muted-foreground hover:text-foreground",
            )}
          >
            Class Record
          </button>
        </div>
      )}

      {/* ── Grades Tab ───────────────────────────────────────────── */}
      {gradeTab === "grades" && (
        <>
          {!courseId || visibleRoster.length === 0 ? (
            <EmptyState
              title="No students on this roster"
              sub="Enroll students or pick another course or section."
            />
          ) : (
            <Card className="min-w-0 max-w-full overflow-x-auto overscroll-x-contain">
              <table className="w-full min-w-[760px] text-sm">
                <thead>
                  <tr className="border-b border-border text-left text-xs uppercase tracking-wide text-muted-foreground">
                    <th className="p-4">Student</th>
                    <th className="p-4 text-center">Att (10%)</th>
                    <th className="p-4 text-center">
                      <div className="inline-flex items-center justify-center gap-1.5">
                        <span>WW (20%)</span>
                        <BulkColumnMenu
                          columnKey="ww"
                          columnTitle="WW"
                          visibleCount={visibleRoster.length}
                          onOpenFill={() => setBulkFillColumn("ww")}
                          onClear={() => handleClearColumnOverrides("ww")}
                        />
                      </div>
                    </th>
                    <th className="p-4 text-center">
                      <div className="inline-flex items-center justify-center gap-1.5">
                        <span>PT (40%)</span>
                        <BulkColumnMenu
                          columnKey="pt"
                          columnTitle="PT"
                          visibleCount={visibleRoster.length}
                          onOpenFill={() => setBulkFillColumn("pt")}
                          onClear={() => handleClearColumnOverrides("pt")}
                        />
                      </div>
                    </th>
                    <th className="p-4 text-center">
                      <div className="inline-flex items-center justify-center gap-1.5">
                        <span>Exam (30%)</span>
                        <BulkColumnMenu
                          columnKey="ex"
                          columnTitle="Exam"
                          visibleCount={visibleRoster.length}
                          onOpenFill={() => setBulkFillColumn("ex")}
                          onClear={() => handleClearColumnOverrides("ex")}
                        />
                      </div>
                    </th>
                    <th className="p-4 text-center">Initial</th>
                    <th className="p-4 text-center">Transmuted</th>
                    <th className="p-4">Remarks</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {visibleRoster.map((s) => {
                    const c = cells[s.id] ?? { ww: "", pt: "", ex: "" };
                    const p = preview(s.id);
                    const setCell =
                      (k: keyof CellState) => (e: React.ChangeEvent<HTMLInputElement>) =>
                        setCells((all) => ({
                          ...all,
                          [s.id]: { ...c, [k]: sanitizeDecimal(e.target.value) },
                        }));
                    return (
                      <tr key={s.id}>
                        <td className="p-4">
                          <div className="flex items-center gap-2.5">
                            <UserAvatar src={s.avatar_url} name={s.full_name} />
                            <div>
                              <p className="font-semibold">{s.full_name}</p>
                              <p className="text-xs text-muted-foreground">
                                {s.student_id} · {s.section}
                              </p>
                            </div>
                          </div>
                        </td>
                        <td className="p-4 text-center text-muted-foreground">
                          {attOf(s.id) ?? "—"}
                        </td>
                        {(["ww", "pt", "ex"] as const).map((k) => {
                          const isOverridden = !!overrides[s.id]?.[k];
                          const overrideFlag = overrides[s.id]?.[k] ?? null;
                          return (
                            <td key={k} className="p-4 text-center">
                              <div className="inline-flex items-center justify-center gap-1">
                                <input
                                  value={c[k]}
                                  onChange={setCell(k)}
                                  inputMode="decimal"
                                  placeholder="—"
                                  aria-label={`${k === "ww" ? "Written work" : k === "pt" ? "Performance task" : "Exam"} score for ${s.full_name}`}
                                  className={cn(
                                    "h-9 w-20 rounded-lg border border-input bg-background text-center text-sm outline-none transition-colors focus:ring-2 focus:ring-ring",
                                    isOverridden &&
                                      "border-amber-500/70 border-l-[3px] border-l-amber-500 bg-amber-500/5 font-medium dark:border-amber-400/60 dark:border-l-amber-400 dark:bg-amber-400/10",
                                  )}
                                />
                                <OverrideFlagToggle
                                  studentName={s.full_name}
                                  columnKey={k}
                                  override={overrideFlag}
                                  onToggle={() => handleToggleOverride(s.id, k)}
                                  onUpdateNote={(note) => handleUpdateOverrideNote(s.id, k, note)}
                                />
                              </div>
                            </td>
                          );
                        })}
                        <td className="p-4 text-center">{p ? p.initial.toFixed(1) : "—"}</td>
                        <td className="p-4 text-center">
                          <span
                            className={cn(
                              "font-display text-base font-bold",
                              p && p.t < 75 && "text-rose-600 dark:text-rose-400",
                            )}
                          >
                            {p ? p.t : "—"}
                          </span>
                        </td>
                        <td className="p-4">
                          {p ? (
                            <Badge
                              tone={
                                p.t >= 90
                                  ? "green"
                                  : p.t >= 80
                                    ? "indigo"
                                    : p.t >= 75
                                      ? "amber"
                                      : "red"
                              }
                            >
                              {gradeRemarks(p.t)}
                            </Badge>
                          ) : (
                            "—"
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </Card>
          )}
        </>
      )}

      {/* ── Quiz Scores Tab ──────────────────────────────────────── */}
      {gradeTab === "quizzes" && courseId && (
        <div>
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <p className="max-w-2xl text-xs text-muted-foreground">
              Best score per student for each worksheet. Manually entered quiz scores are saved as
              you leave a score cell. Use these scores to inform Written Work (WW).
            </p>
            {quiz4Item ? (
              <button
                type="button"
                onClick={() => setQuizScoreImportOpen(true)}
                className="flex h-10 items-center gap-2 rounded-xl border border-border bg-card px-4 text-xs font-semibold hover:bg-muted"
              >
                <FileUp className="h-4 w-4" /> Import Quiz 4 scores
              </button>
            ) : (
              <button
                type="button"
                disabled={creatingQuizScoreItem}
                onClick={() => void addQuiz4Item()}
                className="flex h-10 items-center gap-2 rounded-xl bg-primary px-4 text-xs font-semibold text-primary-foreground hover:opacity-90 disabled:opacity-50"
              >
                <Plus className="h-4 w-4" />
                {creatingQuizScoreItem ? "Adding…" : "Add Quiz 4"}
              </button>
            )}
          </div>
          {!quizScores || quizScores.length === 0 ? (
            <EmptyState
              title="No quiz columns yet"
              sub="Add Quiz 4 or have students submit worksheets to populate quiz scores."
            />
          ) : visibleRoster.length === 0 ? (
            <EmptyState
              title="No students on this roster"
              sub="Enroll students or pick another course or section."
            />
          ) : (
            <Card className="min-w-0 max-w-full overflow-x-auto overscroll-x-contain">
              <table className="w-full min-w-[600px] text-sm">
                <thead>
                  <tr className="border-b border-border text-left text-xs uppercase tracking-wide text-muted-foreground">
                    <th className="p-4 sticky left-0 bg-card z-10">Student</th>
                    {quizScores.map((q) => (
                      <th key={q.quiz_id} className="p-4 text-center max-w-[180px]" title={q.title}>
                        <span className="block font-bold normal-case">Quiz {q.quiz_number}</span>
                        {q.title !== `Quiz ${q.quiz_number}` && (
                          <span className="mt-1 block truncate text-[10px] font-normal normal-case text-muted-foreground">
                            {q.title}
                          </span>
                        )}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {visibleRoster.map((s) => (
                    <tr key={s.id}>
                      <td className="p-4 sticky left-0 bg-card z-10">
                        <p className="font-semibold">{s.full_name}</p>
                        <p className="text-xs text-muted-foreground">{s.student_id}</p>
                      </td>
                      {quizScores.map((q) => {
                        const score = q.scores[s.id];
                        if (q.kind === "manual") {
                          const draftKey = `${q.quiz_id}:${s.id}`;
                          const value =
                            quizScoreDrafts[draftKey] ?? (score ? String(score.score) : "");
                          return (
                            <td key={q.quiz_id} className="p-2 text-center">
                              <input
                                type="number"
                                min="0"
                                max="100000"
                                step="0.01"
                                inputMode="decimal"
                                aria-label={`Quiz ${q.quiz_number} score for ${s.full_name}`}
                                value={value}
                                onChange={(event) =>
                                  setQuizScoreDrafts((current) => ({
                                    ...current,
                                    [draftKey]: event.target.value,
                                  }))
                                }
                                onBlur={() => {
                                  const draft = quizScoreDrafts[draftKey];
                                  if (draft !== undefined) void saveManualQuizScore(q, s.id, draft);
                                }}
                                className="h-9 w-20 rounded-lg border border-border bg-background px-2 text-center text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                              />
                            </td>
                          );
                        }
                        if (!score)
                          return (
                            <td key={q.quiz_id} className="p-4 text-center text-muted-foreground">
                              —
                            </td>
                          );
                        const pct =
                          score.total != null && score.total > 0
                            ? Math.round((score.score / score.total) * 100)
                            : 0;
                        return (
                          <td key={q.quiz_id} className="p-4 text-center">
                            <span
                              className={cn(
                                "font-semibold",
                                pct >= 90
                                  ? "text-emerald-600 dark:text-emerald-400"
                                  : pct >= 75
                                    ? "text-amber-600 dark:text-amber-400"
                                    : "text-rose-600 dark:text-rose-400",
                              )}
                            >
                              {score.total == null ? score.score : `${score.score}/${score.total}`}
                            </span>
                            {score.total != null && (
                              <span className="ml-1 text-xs text-muted-foreground">({pct}%)</span>
                            )}
                          </td>
                        );
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
            </Card>
          )}
        </div>
      )}

      {/* ── Class Record Tab ─────────────────────────────────────── */}
      {gradeTab === "class" && courseId && (
        <ClassRecord
          key={`${courseId}:${quarter}`}
          courseId={courseId}
          courseCode={course?.code ?? ""}
          quarter={quarter}
          roster={roster}
          visibleRoster={visibleRoster}
          editable={profile.role === "teacher"}
          onDirtyChange={setRecordDirty}
        />
      )}

      <BulkFillModal
        open={bulkFillColumn !== null}
        onClose={() => setBulkFillColumn(null)}
        columnKey={bulkFillColumn}
        columnTitle={bulkFillColumn ? COLUMN_CONFIG[bulkFillColumn].label : ""}
        visibleCount={visibleRoster.length}
        activeSection={section}
        onApply={(score, note) => {
          if (bulkFillColumn) {
            handleBulkFill(bulkFillColumn, score, note);
          }
        }}
      />

      <GradebookImportModal
        open={importOpen}
        onClose={() => setImportOpen(false)}
        course={course}
        quarter={quarter}
        roster={roster}
        currentCells={cells}
        currentOverrides={overrides}
        attOf={attOf}
        onApply={handleApplyImport}
      />

      <QuizScoreImportModal
        open={quizScoreImportOpen}
        onClose={() => setQuizScoreImportOpen(false)}
        item={quiz4Item ?? null}
        roster={roster}
        section={section}
        onApply={applyQuizScoreImport}
      />
    </AppShell>
  );
}
