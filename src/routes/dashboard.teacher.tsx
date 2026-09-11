import { createFileRoute, Outlet } from "@tanstack/react-router";

// Layout for /dashboard/teacher/* — teacher portal. Child routes (index, students, settings) mount via <Outlet />.
//
// NOTE: No beforeLoad auth guard is needed here. useProfile() returns null
// when not authenticated, and all child pages already handle this case by
// rendering nothing or redirecting as appropriate.
export const Route = createFileRoute("/dashboard/teacher")({
  component: TeacherLayout,
});

function TeacherLayout() {
  return <Outlet />;
}
