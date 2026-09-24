// One-time maintenance endpoint: restore TVE100 (Section B8) student access.
//
// The runtime holds the Supabase service-role key, so this runs the repair
// where raw SQL is not reachable from local tooling. It is guarded by a single
// high-entropy token and is removed immediately after use.
//
// Usage:
//   curl -X POST https://<host>/api/maintenance/repair-roster \
//     -H "x-repair-token: <token>"
import { createFileRoute } from "@tanstack/react-router";

// Temporary capability token — deploy, invoke, then delete this file.
const REPAIR_TOKEN = "e79bb0b50d83e079fd42bbc888cd24829a28d990d1b521fd";

function authorized(request: Request): boolean {
  const header = request.headers.get("x-repair-token") ?? "";
  const query = new URL(request.url).searchParams.get("token") ?? "";
  return header === REPAIR_TOKEN || query === REPAIR_TOKEN;
}

export const Route = createFileRoute("/api/maintenance/repair-roster")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        if (!authorized(request)) return new Response("Not found", { status: 404 });
        try {
          const { repairTve100Roster } = await import("@/lib/server/roster-repair.server");
          const summary = await repairTve100Roster();
          return Response.json({ ok: true, summary });
        } catch (e) {
          return Response.json({ ok: false, error: (e as Error).message }, { status: 500 });
        }
      },
      GET: async ({ request }) => {
        if (!authorized(request)) return new Response("Not found", { status: 404 });
        try {
          const { repairTve100Roster } = await import("@/lib/server/roster-repair.server");
          const summary = await repairTve100Roster();
          return Response.json({ ok: true, summary });
        } catch (e) {
          return Response.json({ ok: false, error: (e as Error).message }, { status: 500 });
        }
      },
    },
  },
});
