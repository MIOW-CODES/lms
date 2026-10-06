/* eslint-disable @typescript-eslint/no-explicit-any */
// Signed kiosk session tokens — HMAC-SHA256 with JTI revocation.
import { createHmac, timingSafeEqual, randomUUID } from "node:crypto";
import { db } from "@/integrations/db/client.server";
import { unwrap } from "@/lib/server/utils.server";

const SESSION_TTL_MS = Number(process.env["SESSION_TTL_MS"]) || 12 * 60 * 60 * 1000;

export function sessionSecret(): string {
  const key = process.env["SESSION_SECRET"];
  if (!key) throw new Error("Missing SESSION_SECRET env var. Set it in .env");
  return key;
}

/** Row persisted for JTI revocation (see {@link createSessionToken}). */
export interface JtiRow {
  jti: string;
  profile_id: string;
  expires_at: string;
}

/** Pluggable JTI writer — default persists to `sessions`; tests inject stubs. */
export type JtiWriter = (row: JtiRow) => PromiseLike<unknown>;

async function persistJti(row: JtiRow): Promise<void> {
  await unwrap(db.from("sessions").insert(row as any));
}

/**
 * Issue a signed session token. FAIL-CLOSED (Gate-1 3f / C12): the JTI row must
 * be written before the token is returned — if it cannot be persisted the token
 * is never issued and login errors, instead of handing out an unrevocable token.
 */
export async function createSessionToken(
  profileId: string,
  jti: string = randomUUID(),
  writeJti: JtiWriter = persistJti,
): Promise<string> {
  const secret = sessionSecret();
  const exp = Date.now() + SESSION_TTL_MS;
  const payload = Buffer.from(JSON.stringify({ sub: profileId, jti, exp })).toString("base64url");
  try {
    await writeJti({ jti, profile_id: profileId, expires_at: new Date(exp).toISOString() });
  } catch (e) {
    console.error("[sessions] JTI insert failed — refusing to issue token:", e);
    throw new Error("Sign-in failed: the session could not be recorded. Please try again.");
  }
  const sig = createHmac("sha256", secret).update(payload).digest("base64url");
  return `${payload}.${sig}`;
}

export function verifySessionToken(token: string): string {
  const [payload, sig] = token.split(".");
  if (!payload || !sig) throw new Error("Unauthorized");
  const tryKeys = [process.env["SESSION_SECRET"]].filter(Boolean) as string[];
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
  } catch (e) {
    console.error("[sessions] JTI revoke failed:", e);
  }
}
