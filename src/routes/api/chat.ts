// ClassMate Assistant streaming chat endpoint.
// Calls OpenCode Go directly with mimo-v2.5 (bypasses AI SDK streaming for reasoning models).
import { createFileRoute } from "@tanstack/react-router";

type ChatRequestBody = {
  messages?: unknown;
  token?: unknown;
  worksheetContext?: unknown;
};

/** Sanitize the optional Create Worksheet form context (course/title/sourceMaterial). */
function parseWorksheetContext(
  raw: unknown,
): { course?: string; title?: string; sourceMaterial?: string } | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const o = raw as Record<string, unknown>;
  const course = typeof o["course"] === "string" ? o["course"].slice(0, 200) : undefined;
  const title = typeof o["title"] === "string" ? o["title"].slice(0, 200) : undefined;
  const sourceMaterial =
    typeof o["sourceMaterial"] === "string" ? o["sourceMaterial"].slice(0, 15000) : undefined;
  if (!course && !title && !sourceMaterial) return undefined;
  const ctx: { course?: string; title?: string; sourceMaterial?: string } = {};
  if (course) ctx.course = course;
  if (title) ctx.title = title;
  if (sourceMaterial) ctx.sourceMaterial = sourceMaterial;
  return ctx;
}

interface ChatMessage {
  role: "user" | "assistant";
  content?: string;
  parts?: Array<{ type?: string; text?: string }>;
}

/**
 * Keep prompts small enough to start fast — long source dumps are the main
 * latency driver. Tuned to the mimo-v2.5 context window; revisit if the model
 * (or its max context) changes.
 */
const MAX_MESSAGE_CHARS = 24_000;
const MAX_TOTAL_CHARS = 60_000;

/**
 * Collapse a UI message to plain text, trimming pathological inputs while always
 * preserving the most recent turns.
 */
function toOpenAIMessages(messages: ChatMessage[], systemPrompt: string) {
  const out: Array<{ role: string; content: string }> = [];
  for (const m of messages) {
    if (m.role !== "user" && m.role !== "assistant") continue;
    let text = "";
    if (typeof m.content === "string") text = m.content;
    else if (Array.isArray(m.parts)) {
      text = m.parts
        .filter((p) => p.type === "text")
        .map((p) => p.text ?? "")
        .join("");
    }
    text = text.trim();
    if (!text) continue;
    if (text.length > MAX_MESSAGE_CHARS) {
      text = `${text.slice(0, MAX_MESSAGE_CHARS)}\n…[truncated ${text.length - MAX_MESSAGE_CHARS} chars]`;
    }
    out.push({ role: m.role, content: text });
  }
  // Drop the oldest turns if the whole prompt is still too large; always keep the last one.
  let total = out.reduce((n, m) => n + m.content.length, 0);
  while (total > MAX_TOTAL_CHARS && out.length > 1) {
    const dropped = out.shift()!;
    total -= dropped.content.length;
  }
  return [{ role: "system", content: systemPrompt }, ...out];
}

const chatRateLimits = new Map<string, number>();
const CHAT_RATE_LIMIT_MS = 10_000; // 10 seconds between requests

export const Route = createFileRoute("/api/chat")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        let body: ChatRequestBody;
        try {
          body = (await request.json()) as ChatRequestBody;
        } catch {
          return new Response("Invalid JSON body", { status: 400 });
        }
        const { messages, token } = body;
        if (!Array.isArray(messages)) {
          return new Response("Messages are required", { status: 400 });
        }
        if (messages.length > 50) return new Response("Too many messages", { status: 400 });
        if (typeof token !== "string" || token.length === 0) {
          return new Response("Sign in to chat", { status: 401 });
        }

        const apiKey = process.env["OPENCODE_API_KEY"] ?? process.env["AI_GATEWAY_KEY"];
        if (!apiKey) {
          return new Response("Missing OPENCODE_API_KEY", { status: 500 });
        }

        const [{ requireSession }, { systemPromptFor }] = await Promise.all([
          import("@/lib/server"),
          import("@/lib/chat-tools.server"),
        ]);

        let profile;
        try {
          profile = await requireSession(token);
        } catch {
          return new Response("Session expired — please sign in again", { status: 401 });
        }

        // ClassMate Assistant is staff-only. Students must not be able to invoke
        // the assistant even by calling the endpoint directly.
        if (profile.role === "student") {
          return new Response("ClassMate is not available for student accounts", { status: 403 });
        }

        const now = Date.now();
        const lastRequest = chatRateLimits.get(profile.id);
        if (lastRequest && now - lastRequest < CHAT_RATE_LIMIT_MS) {
          return new Response("Too many requests — please wait a moment", { status: 429 });
        }
        chatRateLimits.set(profile.id, now);
        // Evict stale entries every request to prevent unbounded memory growth
        for (const [key, ts] of chatRateLimits) {
          if (now - ts > 60_000) chatRateLimits.delete(key);
        }

        const ctx = parseWorksheetContext(body.worksheetContext);
        const oaMessages = toOpenAIMessages(messages, systemPromptFor(profile, ctx));

        const { AI_BASE_URL } = await import("@/lib/ai-gateway.server");
        const sessionId = `miow-${profile.id}-${Date.now()}`;
        const apiRes = await fetch(`${AI_BASE_URL}/chat/completions`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${apiKey}`,
            "Content-Type": "application/json",
            "x-opencode-session": sessionId,
          },
          body: JSON.stringify({
            model: "mimo-v2.5",
            messages: oaMessages,
            stream: true,
            max_tokens: 65536,
          }),
        });

        if (!apiRes.ok) {
          const err = await apiRes.text();
          console.error("[chat] OpenCode Go error:", apiRes.status, err);
          return new Response(`AI service error: ${apiRes.status}`, { status: 502 });
        }

        // Buffer-based SSE parser — handles TCP packet splits correctly
        const encoder = new TextEncoder();
        const decoder = new TextDecoder();
        let textStarted = false;
        let reasoningStarted = false;
        const textId = `txt-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
        const reasoningId = `rsn-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
        let buffer = "";

        const sse = (payload: unknown) => encoder.encode(`data: ${JSON.stringify(payload)}\n\n`);

        const transform = new TransformStream({
          transform(chunk, controller) {
            buffer += decoder.decode(chunk, { stream: true });
            let nlIdx;
            while ((nlIdx = buffer.indexOf("\n")) !== -1) {
              const line = buffer.slice(0, nlIdx).trim();
              buffer = buffer.slice(nlIdx + 1);
              if (!line.startsWith("data: ")) continue;
              const data = line.slice(6).trim();
              if (data === "[DONE]") {
                if (reasoningStarted) {
                  controller.enqueue(sse({ type: "reasoning-end", id: reasoningId }));
                }
                if (textStarted) {
                  controller.enqueue(sse({ type: "text-end", id: textId }));
                }
                controller.enqueue(encoder.encode("data: [DONE]\n\n"));
                continue;
              }
              try {
                const parsed: {
                  choices?: Array<{
                    delta?: { content?: string; reasoning_content?: string; reasoning?: string };
                  }>;
                } = JSON.parse(data);
                const delta = parsed.choices?.[0]?.delta;
                if (!delta) continue;

                // Reasoning models stream their chain-of-thought first. Forward it
                // so the UI shows live progress instead of a stalled "Thinking…".
                const reasoning = delta.reasoning_content ?? delta.reasoning;
                if (typeof reasoning === "string" && reasoning.length > 0) {
                  if (!reasoningStarted) {
                    controller.enqueue(sse({ type: "reasoning-start", id: reasoningId }));
                    reasoningStarted = true;
                  }
                  controller.enqueue(
                    sse({ type: "reasoning-delta", id: reasoningId, delta: reasoning }),
                  );
                  continue;
                }

                const content = delta.content;
                if (content === null || content === undefined || content === "") continue;
                if (reasoningStarted) {
                  controller.enqueue(sse({ type: "reasoning-end", id: reasoningId }));
                  reasoningStarted = false;
                }
                if (!textStarted) {
                  controller.enqueue(sse({ type: "text-start", id: textId }));
                  textStarted = true;
                }
                controller.enqueue(sse({ type: "text-delta", id: textId, delta: content }));
              } catch (e) {
                console.error("[chat-api]", e);
              }
            }
          },
        });

        const body_ = apiRes.body!.pipeThrough(transform);
        return new Response(body_, {
          headers: {
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            Connection: "keep-alive",
            "X-Vercel-AI-UI-Message-Stream": "v1",
          },
        });
      },
    },
  },
});
