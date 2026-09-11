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
  errorComponent: () => (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="max-w-md text-center">
        <h1 className="text-xl font-semibold tracking-tight text-foreground">
          Student portal error
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">
          Something went wrong in the student portal. Please try refreshing the page.
        </p>
      </div>
    </div>
  ),
});

function StudentLayout() {
  return <Outlet />;
}
