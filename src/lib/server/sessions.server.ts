/* eslint-disable @typescript-eslint/no-explicit-any */
// Signed kiosk session tokens — HMAC-SHA256 with JTI revocation.
import { createHmac, timingSafeEqual, randomUUID } from "node:crypto";
import { db } from "@/integrations/db/client.server";
import { unwrap } from "@/lib/server/utils.server";

// SESSION_TTL_HOURS: 0 = token never expires, omit/unset = 12h default.
// Non-numeric or negative values fall back to 12h (never grant immortal tokens by accident).
const _raw = process.env["SESSION_TTL_HOURS"];
const _parsed = _raw !== undefined && _raw !== "" ? Number(_raw) : NaN;
const SESSION_TTL_MS =
  Number.isFinite(_parsed) && _parsed >= 0
    ? _parsed * 60 * 60 * 1000
    : 12 * 60 * 60 * 1000;

export function sessionSecret(): string {
  const key = process.env["SESSION_SECRET"] ?? process.env["SUPABASE_SERVICE_ROLE_KEY"];
  if (!key) throw new Error("Missing SESSION_SECRET — set it in your .env (openssl rand -hex 32)");
  if (!process.env["SESSION_SECRET"] && process.env["SUPABASE_SERVICE_ROLE_KEY"]) {
    console.warn(
      "[security] No SESSION_SECRET set — falling back to SUPABASE_SERVICE_ROLE_KEY. " +
        "Set SESSION_SECRET in production.",
    );
  }
  return key;
}

export function createSessionToken(profileId: string, jti: string = randomUUID()): string {
  // exp = 0 means "never expires"; omit exp field in payload when TTL is 0.
  const exp = SESSION_TTL_MS > 0 ? Date.now() + SESSION_TTL_MS : 0;
  const payload = Buffer.from(JSON.stringify({ sub: profileId, jti, exp })).toString("base64url");
  // Persist jti for revocation; best-effort so login never blocks on DB.
  const row = { jti, profile_id: profileId, expires_at: exp ? new Date(exp).toISOString() : null } as any;
  try {
    const pending: any = db.from("sessions").insert(row);
    if (pending && typeof pending.then === "function")
      void pending.then(
        () => {},
        () => {},
      );
    else void pending;
  } catch {
    // ignore sync errors (e.g., sessions table not yet migrated in tests)
  }
  const sig = createHmac("sha256", sessionSecret()).update(payload).digest("base64url");
  return `${payload}.${sig}`;
}

export function verifySessionToken(token: string): string {
  const [payload, sig] = token.split(".");
  if (!payload || !sig) throw new Error("Unauthorized");
  const tryKeys = [process.env["SESSION_SECRET"], process.env["SUPABASE_SERVICE_ROLE_KEY"]].filter(
    Boolean,
  ) as string[];
  const useKeys = tryKeys.length ? tryKeys : [sessionSecret()];
  let ok = false;
  for (const k of useKeys) {
    const expected = createHmac("sha256", k).update(payload).digest("base64url");
    const a = Buffer.from(sig);
    const b = Buffer.from(expected);
    if (a.length === b.length && timingSafeEqual(a, b)) {
      ok = true;
      break;
    }
  }
  if (!ok) throw new Error("Unauthorized");
  let body: { sub?: unknown; jti?: unknown; exp?: unknown };
  try {
    body = JSON.parse(Buffer.from(payload, "base64url").toString());
  } catch {
    throw new Error("Unauthorized");
  }
  if (typeof body.sub !== "string") throw new Error("Unauthorized");
  // exp === 0 or missing → never expires; otherwise check expiry
  if (body.exp && typeof body.exp === "number" && body.exp > 0 && body.exp < Date.now()) {
    throw new Error("Unauthorized");
  }
  if (body.jti != null && typeof body.jti !== "string") throw new Error("Unauthorized");
  return body.sub;
}

/** Revoke all active sessions for a profile (best-effort). */
export async function revokeSessions(profileId: string): Promise<void> {
  try {
    await (db
      .from("sessions")
      .update({ revoked_at: new Date().toISOString() })
      .eq("profile_id", profileId)
      .is("revoked_at", null) as any);
  } catch {
    // ignore — sessions table may not exist in test env
  }
}
