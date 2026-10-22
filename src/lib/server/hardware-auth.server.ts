import { timingSafeEqual } from "node:crypto";
import { isIP } from "node:net";
import { consumeSharedRateLimit } from "@/lib/server/auth-rate-limit.server";
import { verifyRfidDeviceKey, touchRfidDevice } from "@/lib/server/rfid-devices.server";

const RATE_LIMIT_MAX = 60;
const RATE_LIMIT_WINDOW_SECONDS = 60;

export function authorized(request: Request): boolean {
  const expected = process.env["HARDWARE_API_KEY"];
  if (!expected) return false;
  const token = (request.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  const tsRaw = request.headers.get("x-hardware-timestamp");
  if (!tsRaw) return false;
  const ts = Date.parse(tsRaw);
  if (!Number.isFinite(ts)) return false;
  if (Math.abs(Date.now() - ts) > 5 * 60 * 1000) return false;
  const a = Buffer.from(token);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

/**
 * Accepts either a registered per-device API key (rfid_devices) or the global
 * HARDWARE_API_KEY. Timestamp freshness rules are identical for both.
 */
export async function authorizedAny(request: Request): Promise<{ ok: boolean; token: string }> {
  const token = (request.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  const tsRaw = request.headers.get("x-hardware-timestamp");
  if (!tsRaw) return { ok: false, token };
  const ts = Date.parse(tsRaw);
  if (!Number.isFinite(ts)) return { ok: false, token };
  if (Math.abs(Date.now() - ts) > 5 * 60 * 1000) return { ok: false, token };
  if (await verifyRfidDeviceKey(token)) return { ok: true, token };
  return { ok: authorized(request), token };
}

export async function guardHardwareRequest(
  request: Request,
  consumeLimit: typeof consumeSharedRateLimit = consumeSharedRateLimit,
): Promise<{ ok: true; ip: string } | { ok: false; response: Response }> {
  const ipCandidates = [
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim(),
    request.headers.get("x-real-ip")?.trim(),
  ];
  const ip =
    ipCandidates.find((candidate): candidate is string => !!candidate && isIP(candidate) !== 0) ??
    "unknown";

  let allowed: boolean;
  try {
    allowed = await consumeLimit(`hardware-ip:${ip}`, RATE_LIMIT_MAX, RATE_LIMIT_WINDOW_SECONDS);
  } catch {
    // Fail closed when the shared limiter is unavailable so a serverless
    // instance failure cannot silently remove the hardware endpoint guard.
    console.error("[hardware] shared rate limiter unavailable");
    return {
      ok: false,
      response: new Response("Service Unavailable", {
        status: 503,
        headers: { "Retry-After": "60", "Cache-Control": "no-store" },
      }),
    };
  }

  if (!allowed) {
    return {
      ok: false,
      response: new Response("Too Many Requests", {
        status: 429,
        headers: { "Retry-After": "60", "Cache-Control": "no-store" },
      }),
    };
  }
  const auth = await authorizedAny(request);
  if (!auth.ok) {
    return { ok: false, response: new Response("Unauthorized", { status: 401 }) };
  }
  // Heartbeat for registered devices — never fails the request.
  await touchRfidDevice(auth.token);
  return { ok: true, ip };
}
