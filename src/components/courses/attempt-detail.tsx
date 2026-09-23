import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Check, EyeOff, Save, X } from "lucide-react";
import { listStudentAttemptDetail, overrideQuizAttempt } from "@/lib/lms";
import { Badge } from "@/components/lms";
import { switchSeverity } from "@/lib/anti-cheat";
import { cn } from "@/lib/utils";

/**
 * Per-question inspection of one student's worksheet attempts, plus a teacher
 * override form. The AI can mis-grade essays/short answers, so the teacher's
 * score always supersedes the computed effective score.
 */
export function AttemptDetail({
  quizId,
  studentId,
  studentName,
  onChanged,
}: {
  quizId: string;
  studentId: string;
  studentName: string;
  onChanged?: () => void;
}) {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ["attempt-detail", quizId, studentId],
    queryFn: () => listStudentAttemptDetail(quizId, studentId),
  });

  const [score, setScore] = useState<string>("");
  const [total, setTotal] = useState<string>("");
  const [notes, setNotes] = useState<string>("");
  const [saving, setSaving] = useState(false);
  const [seeded, setSeeded] = useState(false);

  // Seed the override form once data arrives (without clobbering user edits).
  if (data && !seeded) {
    setScore(data.override?.score?.toString() ?? "");
    setTotal(data.override?.total?.toString() ?? "");
    setNotes(data.override?.notes ?? "");
    setSeeded(true);
  }

  const refresh = () => {
    qc.invalidateQueries({ queryKey: ["attempt-detail", quizId, studentId] });
    qc.invalidateQueries({ queryKey: ["quiz-attempts", quizId] });
    qc.invalidateQueries({ queryKey: ["quiz-scores"] });
    onChanged?.();
  };

  const saveOverride = async () => {
    setSaving(true);
    try {
      const parsedScore = score.trim() === "" ? null : Number(score);
      const parsedTotal = total.trim() === "" ? null : Number(total);
      if (parsedScore != null && (!Number.isFinite(parsedScore) || parsedScore < 0)) {
        toast.error("Score must be a non-negative number.");
        return;
      }
      if (parsedTotal != null && (!Number.isFinite(parsedTotal) || parsedTotal <= 0)) {
        toast.error("Total must be a positive number.");
        return;
      }
      await overrideQuizAttempt(quizId, studentId, parsedScore, parsedTotal, notes.trim() || null);
      toast.success("Override saved — this supersedes the AI score.");
      refresh();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Could not save the override.");
    } finally {
      setSaving(false);
    }
  };

  if (isLoading)
    return <p className="py-6 text-center text-sm text-muted-foreground">Loading attempt…</p>;
  if (!data) return null;

  return (
    <div className="mt-3 space-y-4 border-t border-border/60 pt-3">
      <div className="flex flex-wrap items-center gap-2">
        <p className="text-sm font-semibold">{studentName}</p>
        {data.override && (
          <Badge tone="amber">
            Teacher override: {data.override.score ?? "—"}/{data.override.total ?? "—"}
          </Badge>
        )}
      </div>

      {data.attempts.length === 0 ? (
        <p className="text-sm text-muted-foreground">No attempts recorded.</p>
      ) : (
        data.attempts.map((a) => {
          const switches = a.tab_switches.length;
          const severity = switchSeverity(switches);
          return (
            <div key={a.attempt_number} className="rounded-xl border border-border/60 p-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <p className="text-sm font-semibold">
                  Attempt #{a.attempt_number} — {a.score}/{a.total}
                </p>
                {switches > 0 && (
                  <span
                    className={cn(
                      "flex items-center gap-1 rounded px-1.5 py-0.5 text-[11px] font-semibold",
                      severity.bg,
                      severity.text,
                    )}
                  >
                    <EyeOff className="h-3 w-3" /> {switches} tab switch(es)
                  </span>
                )}
              </div>
              <ul className="mt-2 space-y-2">
                {a.results.map((r) => (
                  <li key={r.id} className="rounded-lg bg-muted/40 p-2.5 text-sm">
                    <div className="flex items-start gap-2">
                      {r.correct ? (
                        <Check className="mt-0.5 h-4 w-4 shrink-0 text-emerald-500" />
                      ) : (
                        <X className="mt-0.5 h-4 w-4 shrink-0 text-rose-500" />
                      )}
                      <div className="min-w-0 flex-1">
                        <p className="font-medium">{r.question}</p>
                        <p className="mt-0.5 text-xs text-muted-foreground">
                          Answered:{" "}
                          <span className={r.correct ? "text-emerald-600" : "text-rose-600"}>
                            {r.chosen ?? "— (blank)"}
                          </span>
                        </p>
                        {!r.correct && (
                          <p className="text-xs text-muted-foreground">
                            Expected: <span className="text-foreground">{r.correct_answer}</span>
                          </p>
                        )}
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          );
        })
      )}

      {/* Teacher override form */}
      <div className="rounded-xl bg-muted/40 p-3">
        <p className="text-xs font-bold uppercase tracking-wide text-muted-foreground">
          Teacher override (supersedes AI score)
        </p>
        <div className="mt-2 flex flex-wrap items-center gap-2">
          <input
            value={score}
            onChange={(e) => setScore(e.target.value.replace(/[^0-9.]/g, ""))}
            inputMode="decimal"
            placeholder="Score"
            aria-label="Override score"
            className="h-10 w-24 rounded-lg border border-input bg-background px-3 text-center text-sm outline-none focus:ring-2 focus:ring-ring"
          />
          <span className="text-muted-foreground">/</span>
          <input
            value={total}
            onChange={(e) => setTotal(e.target.value.replace(/[^0-9.]/g, ""))}
            inputMode="decimal"
            placeholder="Total"
            aria-label="Override total"
            className="h-10 w-24 rounded-lg border border-input bg-background px-3 text-center text-sm outline-none focus:ring-2 focus:ring-ring"
          />
          <input
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Notes (optional)"
            aria-label="Override notes"
            className="h-10 min-w-48 flex-1 rounded-lg border border-input bg-background px-3 text-sm outline-none focus:ring-2 focus:ring-ring"
          />
          <button
            onClick={saveOverride}
            disabled={saving}
            className="flex h-10 items-center gap-1.5 rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground hover:opacity-90 disabled:opacity-50"
          >
            <Save className="h-4 w-4" /> {saving ? "Saving…" : "Save override"}
          </button>
        </div>
        <p className="mt-2 text-xs text-muted-foreground">
          Leave both score and total blank to clear an override and fall back to the AI score.
        </p>
      </div>
    </div>
  );
}
