// Test-account role view — session-scoped portal view switching.
//
// The allowlisted demo Test Account can act as admin, teacher AND student from
// one login. The chosen view is stored on the CURRENT session row
// (sessions.role_view) and honored only for that email in requireSession
// (see auth.server). The real profiles.role is never written.
//
// Security: the server re-checks the SESSION's real profile email against the
// hard allowlist (assertTestAccount) before anything is persisted — every
// other account gets "Forbidden" regardless of role, including admins.

import { assertTestAccount, applyRoleView, type RoleView } from "@/lib/role-view";
import { sessionJti, setSessionRoleView } from "@/lib/server/sessions.server";
import { requireSession } from "@/lib/server/auth.server";
import type { SafeProfile } from "@/lib/server/profiles.server";

/**
 * Switch the caller's session role view. Throws "Forbidden" unless the
 * session's real profile email is the allowlisted test account. A fresh
 * login always starts back at the real role (new session row → NULL view).
 */
export async function setTestRoleView(token: string, view: RoleView): Promise<SafeProfile> {
  const profile = await requireSession(token);
  // Hard allowlist guard — the fn throws for every non-test account.
  assertTestAccount(profile.email);
  const jti = sessionJti(token);
  if (!jti) throw new Error("Forbidden: this session cannot switch role views");
  const updated = await setSessionRoleView(jti, profile.id, view);
  if (!updated) throw new Error("Forbidden: this session cannot switch role views");
  return applyRoleView(profile, view);
}
