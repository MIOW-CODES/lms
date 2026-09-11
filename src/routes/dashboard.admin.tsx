import { createFileRoute, Outlet } from "@tanstack/react-router";

// Layout route for the admin/teacher portal. The dashboard body lives in
// dashboard.admin.index.tsx; child pages (students, courses, gradebook,
// attendance kiosk, announcements, settings) mount through <Outlet />.
//
// NOTE: No beforeLoad auth guard is needed here. useProfile() returns null
// when not authenticated, and all child pages already handle this case by
// rendering nothing or redirecting as appropriate.
export const Route = createFileRoute("/dashboard/admin")({
  component: AdminLayout,
});

function AdminLayout() {
  return <Outlet />;
}
