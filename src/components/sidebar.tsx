import { Fragment, type ReactNode } from "react";
import { Link, useRouterState } from "@tanstack/react-router";
import { motion } from "framer-motion";
import {
  BarChart3,
  BookOpen,
  CalendarCheck,
  ClipboardList,
  GraduationCap,
  Layers,
  LayoutDashboard,
  LogOut,
  Megaphone,
  Settings,
  Users,
} from "lucide-react";
import type { Profile, Role } from "@/lib/lms";
import { cn } from "@/lib/utils";
import { MiowMark } from "@/components/brand";
import { ThemeToggle } from "@/components/ui-elements";
import { ChatWidget } from "@/components/chat-widget";
import { useSignOut } from "@/hooks";

export interface NavItem {
  to: string;
  label: string;
  icon: ReactNode;
}

export const STUDENT_NAV: NavItem[] = [
  { to: "/dashboard/student", label: "Dashboard", icon: <LayoutDashboard className="h-4 w-4" /> },
  { to: "/dashboard/student/courses", label: "Courses", icon: <BookOpen className="h-4 w-4" /> },
  { to: "/dashboard/student/grades", label: "Grades", icon: <BarChart3 className="h-4 w-4" /> },
  {
    to: "/dashboard/student/assignments",
    label: "Activities",
    icon: <ClipboardList className="h-4 w-4" />,
  },
  {
    to: "/dashboard/student/attendance",
    label: "Attendance",
    icon: <CalendarCheck className="h-4 w-4" />,
  },
  { to: "/dashboard/student/settings", label: "Settings", icon: <Settings className="h-4 w-4" /> },
];

// Admin Console — system-level surfaces only. Gradebook editing and the
// attendance kiosk are teacher duties and are NOT in this nav.
export const ADMIN_NAV: NavItem[] = [
  { to: "/dashboard/admin", label: "Dashboard", icon: <LayoutDashboard className="h-4 w-4" /> },
  { to: "/dashboard/admin/students", label: "Students", icon: <Users className="h-4 w-4" /> },
  {
    to: "/dashboard/admin/teachers",
    label: "Teachers",
    icon: <GraduationCap className="h-4 w-4" />,
  },

  { to: "/dashboard/admin/courses", label: "Courses", icon: <BookOpen className="h-4 w-4" /> },
  {
    to: "/dashboard/admin/announcements",
    label: "Announcements",
    icon: <Megaphone className="h-4 w-4" />,
  },
  { to: "/dashboard/admin/settings", label: "Settings", icon: <Settings className="h-4 w-4" /> },
];

// Teacher Portal — classroom surfaces. Dashboard + Students Info give
// teachers a quick roster scoped to the courses they lead.
export const TEACHER_NAV: NavItem[] = [
  { to: "/dashboard/teacher", label: "Dashboard", icon: <LayoutDashboard className="h-4 w-4" /> },
  { to: "/dashboard/teacher/students", label: "Students", icon: <Users className="h-4 w-4" /> },
  { to: "/dashboard/admin/courses", label: "Courses", icon: <BookOpen className="h-4 w-4" /> },
  {
    to: "/dashboard/admin/announcements",
    label: "Announcements",
    icon: <Megaphone className="h-4 w-4" />,
  },
  { to: "/dashboard/admin/grades", label: "Gradebook", icon: <Layers className="h-4 w-4" /> },
  {
    to: "/dashboard/admin/attendance",
    label: "Attendance",
    icon: <CalendarCheck className="h-4 w-4" />,
  },
  { to: "/dashboard/teacher/settings", label: "Settings", icon: <Settings className="h-4 w-4" /> },
];

/** Sidebar nav for a staff member, keyed by their exact role. */
export function staffNav(role: Role): NavItem[] {
  return role === "admin" ? ADMIN_NAV : TEACHER_NAV;
}

/** Self-service settings route for a role — used by the header/profile pill. */
export function settingsPathFor(role: Role): string {
  if (role === "admin") return "/dashboard/admin/settings";
  if (role === "teacher") return "/dashboard/teacher/settings";
  return "/dashboard/student/settings";
}

export function AppShell({
  nav,
  profile,
  subtitle,
  children,
}: {
  nav: NavItem[];
  profile: Profile;
  subtitle: string;
  children: ReactNode;
}) {
  const signOut = useSignOut();
  const pathname = useRouterState({ select: (s) => s.location.pathname });

  return (
    <div className="relative min-h-screen bg-background lg:flex">
      <aside className="hidden w-80 shrink-0 flex-col bg-sidebar p-6 lg:sticky lg:top-0 lg:flex lg:min-h-screen">
        {/* Logo */}
        <div className="mb-9 flex items-center gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[11px] bg-sidebar-primary text-base font-extrabold text-sidebar-primary-foreground">
            M
          </div>
          <div>
            <p className="font-display text-lg font-extrabold tracking-tight text-sidebar-foreground">
              MIOW
            </p>
            <p className="text-[11px] text-sidebar-foreground/40">IDS Online Workspace</p>
          </div>
        </div>

        {/* Navigation */}
        <nav className="flex flex-1 flex-col gap-0.5">
          {nav.map((n, i) => {
            const active = pathname === n.to;
            const showSection = i === 0 || i === 3 || i === 5;
            return (
              <Fragment key={n.to}>
                {showSection && (
                  <p className="px-3.5 pb-1 pt-4 text-[10px] font-semibold uppercase tracking-widest text-sidebar-foreground/25">
                    {i === 0 ? "Main" : i === 3 ? "Management" : "System"}
                  </p>
                )}
                <Link
                  to={n.to}
                  aria-label={n.label}
                  className={cn(
                    "relative flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                    active
                      ? "bg-sidebar-accent font-semibold text-sidebar-primary"
                      : "text-sidebar-foreground/45 hover:bg-sidebar-accent/50 hover:text-sidebar-foreground/80",
                  )}
                >
                  {n.icon}
                  <span className="truncate">{n.label}</span>
                  {active && (
                    <motion.span
                      layoutId="nav-active"
                      className="absolute left-0 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-full bg-sidebar-primary"
                    />
                  )}
                </Link>
              </Fragment>
            );
          })}
        </nav>

        {/* Divider */}
        <div className="my-3 h-px bg-sidebar-border" />

        {/* Quick Stats (sidebar) */}
        <div className="mb-4 grid grid-cols-2 gap-2">
          <div className="rounded-xl bg-sidebar-accent/50 p-3.5 text-center">
            <p className="text-xl font-extrabold text-sidebar-primary">94%</p>
            <p className="mt-0.5 text-[10px] font-semibold uppercase tracking-wider text-sidebar-foreground/35">
              Attendance
            </p>
          </div>
          <div className="rounded-xl bg-sidebar-accent/50 p-3.5 text-center">
            <p className="text-xl font-extrabold text-sidebar-primary">23</p>
            <p className="mt-0.5 text-[10px] font-semibold uppercase tracking-wider text-sidebar-foreground/35">
              Pending
            </p>
          </div>
        </div>

        {/* User Card */}
        <div className="rounded-xl bg-sidebar-accent/40 p-3">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-sidebar-primary text-sm font-bold text-sidebar-primary-foreground">
              {profile.full_name
                .split(" ")
                .map((n) => n[0] ?? "")
                .join("")
                .slice(0, 2)}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold text-sidebar-foreground">
                {profile.full_name}
              </p>
              <p className="truncate text-[11px] capitalize text-sidebar-foreground/40">
                {profile.role}
              </p>
            </div>
            <div className="h-2 w-2 flex-shrink-0 rounded-full bg-green-400 shadow-[0_0_6px_rgba(74,222,128,0.4)]" />
            <Link
              to={settingsPathFor(profile.role)}
              title="Settings"
              aria-label="Open settings"
              className="rounded-lg p-1.5 text-sidebar-foreground/40 hover:bg-sidebar-accent hover:text-sidebar-foreground"
            >
              <Settings className="h-4 w-4" />
            </Link>
            <button
              onClick={signOut}
              title="Sign out"
              aria-label="Sign out"
              className="rounded-lg p-1.5 text-sidebar-foreground/40 hover:bg-sidebar-accent hover:text-sidebar-foreground"
            >
              <LogOut className="h-4 w-4" />
            </button>
          </div>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        {/* Mobile header */}
        <header className="sticky top-0 z-20 flex items-center gap-3 border-b border-border/60 bg-background/80 px-4 py-3 backdrop-blur-md lg:hidden">
          <MiowMark className="h-8 w-8 shrink-0 rounded-lg" />
          <div className="min-w-0">
            <p className="font-display text-sm font-extrabold tracking-[0.08em]">MIOW</p>
            <p className="truncate text-[10px] text-muted-foreground">MSU-IIT IDS</p>
          </div>
          <div className="ml-auto flex items-center gap-1">
            <ThemeToggle />
            <Link
              to={settingsPathFor(profile.role)}
              aria-label="Open settings"
              className="rounded-lg p-2 text-muted-foreground hover:bg-muted"
            >
              <Settings className="h-4 w-4" />
            </Link>
            <button
              onClick={signOut}
              aria-label="Sign out"
              className="rounded-lg p-2 text-muted-foreground hover:bg-muted"
            >
              <LogOut className="h-4 w-4" />
            </button>
          </div>
        </header>

        <nav className="flex gap-2 overflow-x-auto border-b border-border/60 bg-background/60 px-4 py-2 backdrop-blur-md lg:hidden">
          {nav.map((n) => (
            <Link
              key={n.to}
              to={n.to}
              aria-label={n.label}
              className={cn(
                "flex items-center gap-1.5 whitespace-nowrap rounded-full px-3 py-1.5 text-xs font-semibold",
                pathname === n.to
                  ? "bg-primary text-primary-foreground"
                  : "bg-muted text-muted-foreground",
              )}
            >
              {n.icon}
              {n.label}
            </Link>
          ))}
        </nav>
        <main className="mx-auto w-full max-w-6xl flex-1 p-4 sm:p-6 lg:p-8">{children}</main>
      </div>
      <ChatWidget profile={profile} />
    </div>
  );
}
