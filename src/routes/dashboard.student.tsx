import { createFileRoute, Outlet } from "@tanstack/react-router";

// Layout route for the student portal. The dashboard body lives in
// dashboard.student.index.tsx; child pages (grades, assignments, quizzes,
// attendance, settings) mount through <Outlet />.
//
// NOTE: No beforeLoad auth guard is needed here. useProfile() returns null
// when not authenticated, and all child pages already handle this case by
// rendering nothing or redirecting as appropriate.
export const Route = createFileRoute("/dashboard/student")({
  component: StudentLayout,
});

function StudentLayout() {
  return <Outlet />;
}
