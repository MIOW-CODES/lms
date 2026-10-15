// Test-account role view — shared pure helpers (client + server).
//
// The demo "Test Account" (test@g.msuiit.edu.ph, real role: teacher) must be
// able to act as admin, teacher AND student from one login. The chosen view is
// stored per-session (sessions.role_view) and honored ONLY for the allowlisted
// email below — every other account keeps its real role everywhere.
//
// This module is deliberately dependency-free so the sidebar can gate the
// switcher's visibility while the server re-checks the same allowlist before
// writing anything.

/** The allowlisted profile email that may use the role-view switcher. */
export const TEST_ACCOUNT_EMAIL = "test@g.msuiit.edu.ph";
export const TEST_STUDENT_EMAIL = "it10@g.msuiit.edu.ph";

/** The sessions.role_view values — mirrors the real role vocabulary. */
export const ROLE_VIEWS = ["teacher", "admin", "student"] as const;

export type RoleView = (typeof ROLE_VIEWS)[number];

/** True only for the allowlisted test account (case-insensitive, trimmed). */
export function isTestAccount(email: string | null | undefined): boolean {
  return typeof email === "string" && email.trim().toLowerCase() === TEST_ACCOUNT_EMAIL;
}

/** True for designated testing accounts (e.g., student tester). */
export function isTestStudent(email: string | null | undefined): boolean {
  if (typeof email !== "string") return false;
  const e = email.trim().toLowerCase();
  return e === TEST_STUDENT_EMAIL || e === TEST_ACCOUNT_EMAIL || e === "it10";
}

/**
 * Hard allowlist guard — throws "Forbidden" for every non-test account.
 * Used by the role-view server function so an ordinary teacher/admin can never
 * switch views even if they craft the RPC by hand.
 */
export function assertTestAccount(email: string | null | undefined): void {
  if (!isTestAccount(email)) throw new Error("Forbidden");
}

/** Narrow an untrusted stored value to a valid role view (or null). */
export function parseRoleView(value: unknown): RoleView | null {
  return typeof value === "string" && (ROLE_VIEWS as readonly string[]).includes(value)
    ? (value as RoleView)
    : null;
}

/**
 * Apply a session's stored role view to a profile. The override is ONLY ever
 * honored for the allowlisted test account — everyone else gets their real
 * role back untouched no matter what is stored on the session row.
 */
export function applyRoleView<T extends { email: string | null; role: RoleView }>(
  profile: T,
  storedView: unknown,
): T {
  const view = parseRoleView(storedView);
  if (!view || !isTestAccount(profile.email) || profile.role === view) return profile;
  return { ...profile, role: view };
}
