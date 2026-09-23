// Streams course handouts and student submission files from the private
// "course-materials" bucket. The prefix is only "public" in the routing sense —
// every request must carry a valid signed LMS session token. Token is read from
// Authorization: Bearer header first (preferred — avoids token leakage in logs),
// fallback to ?t= query is deprecated and kept only for backward compat.
//
// Access rules:
//  - Course materials (handouts): any signed-in user (students need the
//    reference materials their teachers attach to assignments/worksheets).
//  - Submission files: the owning student, or any staff member.
import { createFileRoute } from "@tanstack/react-router";

const PATH_RE_MATERIAL = /^[0-9a-f-]{36}\/material_\d+_[0-9a-f]{8}\.(pdf|docx?|png|jpe?g|zip)$/;
const PATH_RE_SUBMISSION =
  /^submissions\/([0-9a-f-]{36})\/file_\d+_[0-9a-f]{8}\.(pdf|docx?|png|jpe?g|zip)$/;
const MIME: Record<string, string> = {
  pdf: "application/pdf",
  doc: "application/msword",
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  zip: "application/zip",
};

export const Route = createFileRoute("/api/public/material")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const url = new URL(request.url);
        const p = url.searchParams.get("p") ?? "";
        // Prefer Authorization header; ?t= is deprecated fallback
        const auth = (request.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
        const t = (auth || url.searchParams.get("t")) ?? "";

        const isMaterial = PATH_RE_MATERIAL.test(p);
        const submissionMatch = p.match(PATH_RE_SUBMISSION);
        if (!isMaterial && !submissionMatch) return new Response("Not found", { status: 404 });
        if (!t) return new Response("Unauthorized", { status: 401 });

        const server = await import("@/lib/server");
        let caller;
        try {
          caller = await server.requireSession(t);
        } catch {
          return new Response("Unauthorized", { status: 401 });
        }

        // Submission files are private: only the owning student or staff may read.
        if (submissionMatch) {
          const submissionId = submissionMatch[1]!;
          const { db } = await import("@/integrations/db/client.server");
          const { unwrap } = await import("@/lib/server/utils.server");
          const row = await unwrap<{ student_id: string } | null>(
            db.from("submissions").select("student_id").eq("id", submissionId).maybeSingle(),
          );
          if (!row) return new Response("Not found", { status: 404 });
          const isOwner = caller.id === row.student_id;
          const isStaff = caller.role === "admin" || caller.role === "teacher";
          if (!isOwner && !isStaff) return new Response("Forbidden", { status: 403 });
        }

        const { supabaseAdmin } = await import("@/integrations/db/client.server");
        const { data, error } = await supabaseAdmin.storage.from("course-materials").download(p);
        if (error || !data) return new Response("Not found", { status: 404 });
        const ext = p.split(".").pop()!;
        return new Response(data, {
          headers: {
            "Content-Type": MIME[ext] ?? "application/octet-stream",
            "Content-Disposition": "inline",
            // Signed-in content: never cached by shared caches.
            "Cache-Control": "private, max-age=300",
            "X-Content-Type-Options": "nosniff",
          },
        });
      },
    },
  },
});
