import { useMemo, useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { ArrowRight, BookOpen, ClipboardList, FileQuestion, Paperclip } from "lucide-react";
import {
  COMPONENT_LABELS,
  daysUntil,
  enrollmentsForStudent,
  fmtDate,
  listAssignments,
  listCourses,
  listQuizzes,
  listSubmissionsForStudent,
  materialHref,
  myQuizSummaries,
  formatSchedule,
  type Assignment,
  type Course,
  type Quiz,
  type QuizAttemptSummary,
  type Submission,
} from "@/lib/lms";
import {
  AppShell,
  Badge,
  EmptyState,
  MotionCard,
  STUDENT_NAV,
  courseStyle,
  useProfile,
} from "@/components/lms";
import { levelLabel } from "@/lib/course-levels";
import { cn } from "@/lib/utils";
import { LoadingSkeleton } from "@/components/ui-elements";
import { CourseWorkspaceShell, type WorkspaceTab } from "@/components/courses/course-workspace";
import { useCourseSelection } from "@/hooks/useCourseWorkspace";

export const Route = createFileRoute("/dashboard/student/courses")({
  head: () => ({
    meta: [
      { title: "Courses | MIOW - Integrated Developmental School" },
      { name: "description", content: "View your enrolled courses, assignments and worksheets." },
      { property: "og:title", content: "Courses | MIOW - Integrated Developmental School" },
      {
        property: "og:description",
        content: "View your enrolled courses, assignments and worksheets.",
      },
    ],
  }),
  component: StudentCoursesPage,
});

type Tab = "courses" | "worksheets" | "assignments";

function StudentCoursesPage() {
  const profile = useProfile(["student"]);
  const [tab, setTab] = useState<Tab>("courses");
  const [selectedCourseId, selectCourse] = useCourseSelection();

  const { data: courses } = useQuery({
    queryKey: ["courses"],
    queryFn: listCourses,
    enabled: !!profile,
  });
  const { data: assignments } = useQuery({
    queryKey: ["assignments"],
    queryFn: listAssignments,
    enabled: !!profile,
  });
  const { data: quizzes } = useQuery({
    queryKey: ["quizzes"],
    queryFn: listQuizzes,
    enabled: !!profile,
  });
  const { data: submissions } = useQuery({
    queryKey: ["submissions", profile?.id],
    queryFn: () => {
      if (!profile?.id) return [];
      return listSubmissionsForStudent(profile.id);
    },
    enabled: !!profile,
  });
  const { data: quizSummaries } = useQuery({
    queryKey: ["quiz-summaries"],
    queryFn: myQuizSummaries,
    enabled: !!profile,
  });
  const { data: enrolledCourseIds } = useQuery({
    queryKey: ["enrollments", "student", profile?.id],
    queryFn: () => enrollmentsForStudent(profile!.id),
    enabled: !!profile?.id,
  });

  // A student may belong to several year levels within one course (mixed college
  // sections), so enrollment is the source of truth — grade level is a fallback.
  const myCourses = useMemo(() => {
    const enrolled = new Set(enrolledCourseIds ?? []);
    return (courses ?? []).filter(
      (c) => enrolled.has(c.id) || c.grade_level === profile?.grade_level,
    );
  }, [courses, enrolledCourseIds, profile?.grade_level]);

  const courseIds = useMemo(() => new Set(myCourses.map((c) => c.id)), [myCourses]);
  const myAssignments = (assignments ?? []).filter((a) => courseIds.has(a.course_id));
  const myQuizzes = (quizzes ?? []).filter((q) => courseIds.has(q.course_id));
  const subByAssignment = new Map((submissions ?? []).map((s) => [s.assignment_id, s]));
  const summaryByQuiz = new Map((quizSummaries ?? []).map((s) => [s.quiz_id, s]));

  const isLoading =
    !courses || !assignments || !quizzes || !submissions || !quizSummaries || !enrolledCourseIds;

  if (!profile) return null;

  if (isLoading)
    return (
      <AppShell nav={STUDENT_NAV} profile={profile} subtitle="Student Portal">
        <LoadingSkeleton />
      </AppShell>
    );

  const selectedCourse = myCourses.find((c) => c.id === selectedCourseId) ?? null;

  if (selectedCourse) {
    return (
      <AppShell nav={STUDENT_NAV} profile={profile} subtitle="Student Portal">
        <StudentCourseWorkspace
          course={selectedCourse}
          quizzes={myQuizzes.filter((q) => q.course_id === selectedCourse.id)}
          assignments={myAssignments.filter((a) => a.course_id === selectedCourse.id)}
          subByAssignment={subByAssignment}
          summaryByQuiz={summaryByQuiz}
          onBack={() => selectCourse(null)}
        />
      </AppShell>
    );
  }

  const TABS: Array<{ id: Tab; label: string; icon: React.ReactNode; count: number }> = [
    {
      id: "courses",
      label: "Courses",
      icon: <BookOpen className="h-4 w-4" />,
      count: myCourses.length,
    },
    {
      id: "worksheets",
      label: "Worksheets",
      icon: <FileQuestion className="h-4 w-4" />,
      count: myQuizzes.length,
    },
    {
      id: "assignments",
      label: "Assignments",
      icon: <ClipboardList className="h-4 w-4" />,
      count: myAssignments.length,
    },
  ];

  return (
    <AppShell nav={STUDENT_NAV} profile={profile} subtitle="Student Portal">
      <div className="mb-6">
        <h1 className="font-display text-2xl font-bold sm:text-3xl">Courses</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {myCourses.length} enrolled course{myCourses.length !== 1 ? "s" : ""}
        </p>
      </div>

      {/* Tab bar */}
      <div className="mb-6 flex gap-2">
        {TABS.map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={cn(
              "flex items-center gap-1.5 rounded-xl px-4 py-2.5 text-sm font-semibold transition",
              tab === t.id
                ? "bg-primary text-primary-foreground shadow-sm"
                : "border border-border bg-card text-muted-foreground hover:bg-muted",
            )}
          >
            {t.icon}
            {t.label}
            <span
              className={cn(
                "ml-1 rounded-full px-1.5 py-0.5 text-[10px] font-bold",
                tab === t.id ? "bg-white/20" : "bg-muted-foreground/10",
              )}
            >
              {t.count}
            </span>
          </button>
        ))}
      </div>

      {/* ── Courses tab ─────────────────────────────────────────────── */}
      {tab === "courses" && (
        <>
          {myCourses.length === 0 ? (
            <EmptyState title="No courses yet" sub="Your enrolled courses will appear here." />
          ) : (
            <>
              <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Select a course to see its worksheets, assignments and materials
              </p>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {myCourses.map((c, i) => {
                  const st = courseStyle(c.color);
                  const courseAssignments = myAssignments.filter((a) => a.course_id === c.id);
                  const courseQuizzes = myQuizzes.filter((q) => q.course_id === c.id);
                  return (
                    <MotionCard
                      key={c.id}
                      delay={Math.min(i * 0.05, 0.3)}
                      className="overflow-hidden"
                    >
                      <div className={cn("h-2", st.chip)} />
                      <div className="p-5">
                        <div className="flex items-center justify-between">
                          <p className="text-xs font-bold text-muted-foreground">{c.code}</p>
                          <Badge tone="slate">{levelLabel(c.grade_level)}</Badge>
                        </div>
                        <button
                          type="button"
                          onClick={() => selectCourse(c.id)}
                          aria-label={`Open course ${c.code} — ${c.title}`}
                          className="mt-1.5 block text-left font-semibold leading-snug hover:text-primary"
                        >
                          {c.title}
                        </button>
                        <p className="mt-1 text-xs text-muted-foreground">
                          {c.teacher_name ?? "TBA"}
                        </p>
                        {formatSchedule(c) && (
                          <p className="mt-1 text-xs font-medium text-primary">
                            {formatSchedule(c)}
                          </p>
                        )}
                        <p className="mt-3 text-xs font-semibold text-muted-foreground">
                          {courseAssignments.length} assignment
                          {courseAssignments.length !== 1 ? "s" : ""} · {courseQuizzes.length}{" "}
                          worksheet
                          {courseQuizzes.length !== 1 ? "s" : ""}
                        </p>
                        <button
                          type="button"
                          onClick={() => selectCourse(c.id)}
                          aria-label={`Open course ${c.code} — ${c.title}`}
                          className="mt-3 flex h-9 w-full items-center justify-center rounded-lg bg-primary/10 text-xs font-semibold text-primary hover:bg-primary/15"
                        >
                          Open course →
                        </button>
                      </div>
                    </MotionCard>
                  );
                })}
              </div>
            </>
          )}
        </>
      )}

      {/* ── Worksheets tab ──────────────────────────────────────────── */}
      {tab === "worksheets" && (
        <>
          {myQuizzes.length === 0 ? (
            <EmptyState
              title="No worksheets yet"
              sub="Worksheets posted by your teacher will appear here."
            />
          ) : (
            <div className="grid gap-2">
              {myQuizzes.map((q) => (
                <StudentWorksheetRow
                  key={q.id}
                  quiz={q}
                  course={myCourses.find((c) => c.id === q.course_id)}
                  summary={summaryByQuiz.get(q.id)}
                />
              ))}
            </div>
          )}
        </>
      )}

      {/* ── Assignments tab ─────────────────────────────────────────── */}
      {tab === "assignments" && (
        <>
          {myAssignments.length === 0 ? (
            <EmptyState
              title="No assignments yet"
              sub="Activities posted by your teacher will appear here."
            />
          ) : (
            <div className="grid gap-2">
              {myAssignments.map((a) => (
                <StudentAssignmentRow
                  key={a.id}
                  assignment={a}
                  course={myCourses.find((c) => c.id === a.course_id)}
                  submission={subByAssignment.get(a.id)}
                />
              ))}
            </div>
          )}
        </>
      )}
    </AppShell>
  );
}

/** Student view of a single course: its worksheets and assignments. */
function StudentCourseWorkspace({
  course,
  quizzes,
  assignments,
  subByAssignment,
  summaryByQuiz,
  onBack,
}: {
  course: Course;
  quizzes: Quiz[];
  assignments: Assignment[];
  subByAssignment: Map<string, Submission>;
  summaryByQuiz: Map<string, QuizAttemptSummary>;
  onBack: () => void;
}) {
  const [tab, setTab] = useState("worksheets");

  const tabs: WorkspaceTab[] = [
    {
      id: "worksheets",
      label: "Worksheets",
      icon: <FileQuestion className="h-4 w-4" />,
      count: quizzes.length,
    },
    {
      id: "assignments",
      label: "Assignments",
      icon: <ClipboardList className="h-4 w-4" />,
      count: assignments.length,
    },
  ];

  return (
    <CourseWorkspaceShell
      course={course}
      onBack={onBack}
      tabs={tabs}
      activeTab={tab}
      onTabChange={setTab}
    >
      {tab === "worksheets" &&
        (quizzes.length === 0 ? (
          <EmptyState
            title="No worksheets yet"
            sub="Worksheets posted by your teacher will appear here."
          />
        ) : (
          <div className="grid gap-2">
            {quizzes.map((q) => (
              <StudentWorksheetRow
                key={q.id}
                quiz={q}
                course={course}
                summary={summaryByQuiz.get(q.id)}
              />
            ))}
          </div>
        ))}

      {tab === "assignments" &&
        (assignments.length === 0 ? (
          <EmptyState
            title="No assignments yet"
            sub="Activities posted by your teacher will appear here."
          />
        ) : (
          <div className="grid gap-2">
            {assignments.map((a) => (
              <StudentAssignmentRow
                key={a.id}
                assignment={a}
                course={course}
                submission={subByAssignment.get(a.id)}
              />
            ))}
          </div>
        ))}
    </CourseWorkspaceShell>
  );
}

function MaterialChips({ attachments }: { attachments: Quiz["attachments"] }) {
  if (!attachments || attachments.length === 0) return null;
  return (
    <div className="mt-1.5 flex flex-wrap gap-1">
      {attachments.map((a) => (
        <a
          key={a.path}
          href={materialHref(a)}
          target="_blank"
          rel="noreferrer"
          className="flex items-center gap-1 rounded-md border border-border/60 bg-muted/40 px-1.5 py-0.5 text-[10px] font-medium text-primary hover:underline"
        >
          <Paperclip className="h-2.5 w-2.5" />
          {a.name}
        </a>
      ))}
    </div>
  );
}

function StudentWorksheetRow({
  quiz,
  course,
  summary,
}: {
  quiz: Quiz;
  course?: Course | undefined;
  summary?: QuizAttemptSummary | undefined;
}) {
  const st = courseStyle(course?.color ?? "indigo");
  return (
    <MotionCard className="flex flex-wrap items-center gap-3 p-4">
      <span className={cn("rounded-md px-2 py-0.5 text-[11px] font-bold", st.soft)}>
        {course?.code ?? "—"}
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold">{quiz.title}</p>
        <p className="text-xs text-muted-foreground">
          {quiz.duration_minutes} min
          {quiz.allow_retake
            ? quiz.max_attempts === 0
              ? " · Retakes allowed (unlimited)"
              : ` · Retakes allowed (up to ${quiz.max_attempts})`
            : " · Single attempt"}
        </p>
        <MaterialChips attachments={quiz.attachments} />
      </div>
      {summary && summary.effective_score != null && summary.effective_total != null ? (
        <Badge tone="green">
          Score: {summary.effective_score}/{summary.effective_total}
        </Badge>
      ) : (
        <Badge tone="slate">Not started</Badge>
      )}
      <Link
        to="/dashboard/student/quizzes"
        className="flex h-9 items-center gap-1.5 rounded-lg bg-primary/10 px-3 text-xs font-semibold text-primary hover:bg-primary/15"
      >
        {summary ? "Retake" : "Start"} →
      </Link>
    </MotionCard>
  );
}

function StudentAssignmentRow({
  assignment,
  course,
  submission,
}: {
  assignment: Assignment;
  course?: Course | undefined;
  submission?: Submission | undefined;
}) {
  const st = courseStyle(course?.color ?? "indigo");
  const due = daysUntil(assignment.due_date);
  const status = !submission || submission.status === "pending" ? "pending" : submission.status;
  return (
    <MotionCard className="flex flex-wrap items-center gap-3 p-4">
      <span className={cn("rounded-md px-2 py-0.5 text-[11px] font-bold", st.soft)}>
        {course?.code ?? "—"}
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold">{assignment.title}</p>
        <p className="text-xs text-muted-foreground">
          {COMPONENT_LABELS[assignment.component_type]} · {assignment.total_points} pts
          {assignment.due_date ? ` · due ${fmtDate(assignment.due_date)}` : ""}
        </p>
        <MaterialChips attachments={assignment.attachments} />
      </div>
      {status === "graded" && submission?.score != null ? (
        <Badge tone="green">
          {submission.score}/{assignment.total_points}
        </Badge>
      ) : status === "submitted" ? (
        <Badge tone="amber">Submitted</Badge>
      ) : (
        <Badge
          tone={
            due === "Overdue"
              ? "red"
              : due.includes("today") || due.includes("tomorrow")
                ? "amber"
                : "slate"
          }
        >
          {due}
        </Badge>
      )}
      <Link
        to="/dashboard/student/assignments"
        className="flex h-9 items-center gap-1.5 rounded-lg bg-primary/10 px-3 text-xs font-semibold text-primary hover:bg-primary/15"
      >
        {status === "pending" ? "Submit" : "View"} →
      </Link>
    </MotionCard>
  );
}
