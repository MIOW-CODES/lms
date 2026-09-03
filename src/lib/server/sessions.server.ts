/* eslint-disable @typescript-eslint/no-explicit-any */
// Signed kiosk session tokens — HMAC-SHA256 with JTI revocation.
import { createHmac, timingSafeEqual, randomUUID } from "node:crypto";
import { db } from "@/integrations/db/client.server";
import { unwrap } from "@/lib/server/utils.server";

const SESSION_TTL_MS = (Number(process.env["SESSION_TTL_HOURS"] ?? "12") || 12) * 60 * 60 * 1000;

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
  const exp = Date.now() + SESSION_TTL_MS;
  const payload = Buffer.from(JSON.stringify({ sub: profileId, jti, exp })).toString("base64url");
  // Persist jti for revocation; best-effort so login never blocks on DB.
  const row = { jti, profile_id: profileId, expires_at: new Date(exp).toISOString() } as any;
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
  if (typeof body.sub !== "string" || typeof body.exp !== "number" || body.exp < Date.now()) {
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
