import { useRef, useState } from "react";
import { AlertCircle, FileUp } from "lucide-react";
import { toast } from "sonner";
import { Badge, Modal } from "@/components/ui-elements";
import type { Profile, QuizCourseScore } from "@/lib/lms";
import {
  parseQuizScoreSpreadsheet,
  type QuizScoreImportResult,
  type QuizScoreImportStatus,
} from "@/lib/quiz-score-import";

interface QuizScoreImportModalProps {
  open: boolean;
  onClose: () => void;
  item: QuizCourseScore | null;
  roster: Profile[];
  section: string;
  onApply: (rows: Array<{ student_id: string; score: number }>) => Promise<void>;
}

const badgeTone: Record<QuizScoreImportStatus, string> = {
  ready: "green",
  blank: "slate",
  unmatched: "amber",
  invalid: "red",
  filtered: "slate",
};

const statusLabel: Record<QuizScoreImportStatus, string> = {
  ready: "Ready",
  blank: "Blank · keep current",
  unmatched: "Unmatched",
  invalid: "Needs correction",
  filtered: "Outside section filter",
};

export function QuizScoreImportModal({
  open,
  onClose,
  item,
  roster,
  section,
  onApply,
}: QuizScoreImportModalProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [parsed, setParsed] = useState<QuizScoreImportResult | null>(null);
  const [fileName, setFileName] = useState("");
  const [applying, setApplying] = useState(false);

  const close = () => {
    setParsed(null);
    setFileName("");
    setApplying(false);
    onClose();
  };

  const readFile = async (file: File | undefined) => {
    if (!file) return;
    try {
      const result = parseQuizScoreSpreadsheet(await file.arrayBuffer(), roster, section);
      setParsed(result);
      setFileName(file.name);
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Could not read the score file.");
      setParsed(null);
      setFileName("");
    }
  };

  const applyImport = async () => {
    if (!parsed) return;
    const rows = parsed.rows.flatMap((row) =>
      row.status === "ready" && row.student && row.score != null
        ? [{ student_id: row.student.id, score: row.score }]
        : [],
    );
    if (!rows.length) return;
    setApplying(true);
    try {
      await onApply(rows);
      close();
    } catch {
      setApplying(false);
    }
  };

  return (
    <Modal open={open} onClose={close} title={`Import ${item?.title ?? "Quiz 4"} Scores`} wide>
      <div className="space-y-4 p-1">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="text-sm font-semibold">Import scores by student number</p>
            <p className="mt-1 max-w-2xl text-xs text-muted-foreground">
              Columns: Student No, Name, Section, Quiz Score. Nonblank scores update the gradebook;
              blank cells leave existing scores unchanged.
            </p>
          </div>
          <input
            ref={inputRef}
            type="file"
            accept=".csv,.xlsx,.xls"
            className="hidden"
            onChange={(event) => {
              const file = event.target.files?.[0];
              event.currentTarget.value = "";
              void readFile(file);
            }}
          />
          <button
            type="button"
            onClick={() => inputRef.current?.click()}
            className="flex h-10 items-center gap-2 rounded-xl border border-border bg-card px-4 text-xs font-semibold hover:bg-muted"
          >
            <FileUp className="h-4 w-4" /> Choose file
          </button>
        </div>

        {parsed && (
          <>
            <div className="rounded-xl border border-border bg-muted/30 p-3">
              <p className="text-xs font-semibold text-foreground">{fileName}</p>
              <div className="mt-2 flex flex-wrap gap-2">
                <Badge tone="sky">{parsed.matchedCount} matched</Badge>
                <Badge tone="green">{parsed.readyCount} scores ready</Badge>
                <Badge tone="slate">{parsed.blankCount} blank</Badge>
                {parsed.unmatchedCount > 0 && (
                  <Badge tone="amber">{parsed.unmatchedCount} unmatched</Badge>
                )}
                {parsed.invalidCount > 0 && <Badge tone="red">{parsed.invalidCount} invalid</Badge>}
                {parsed.filteredCount > 0 && (
                  <Badge tone="slate">{parsed.filteredCount} outside selected section</Badge>
                )}
              </div>
              {parsed.readyCount === 0 && (
                <p className="mt-2 flex items-center gap-1.5 text-xs text-amber-700 dark:text-amber-300">
                  <AlertCircle className="h-3.5 w-3.5 shrink-0" />
                  This file has no valid scores to import yet. Add scores and choose the file again.
                </p>
              )}
            </div>

            <div className="max-h-[50vh] overflow-auto rounded-xl border border-border">
              <table className="w-full min-w-[680px] text-left text-xs">
                <thead className="sticky top-0 bg-muted text-[10px] uppercase tracking-wide text-muted-foreground">
                  <tr>
                    <th className="p-2.5">Line</th>
                    <th className="p-2.5">Student No</th>
                    <th className="p-2.5">Student</th>
                    <th className="p-2.5">Section</th>
                    <th className="p-2.5 text-right">Score</th>
                    <th className="p-2.5">Import status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {parsed.rows.map((row) => (
                    <tr key={`${row.line}-${row.rawIdentifier}`}>
                      <td className="p-2.5 text-muted-foreground">{row.line}</td>
                      <td className="p-2.5">{row.rawIdentifier || "—"}</td>
                      <td className="p-2.5">{row.student?.full_name ?? (row.rawName || "—")}</td>
                      <td className="p-2.5">{row.rawSection || "—"}</td>
                      <td className="p-2.5 text-right">{row.rawScore || "—"}</td>
                      <td className="p-2.5">
                        <div className="space-y-1">
                          <Badge tone={badgeTone[row.status]}>{statusLabel[row.status]}</Badge>
                          {row.message && (
                            <p className="max-w-64 text-[10px] text-rose-600 dark:text-rose-400">
                              {row.message}
                            </p>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="flex justify-end gap-2 pt-1">
              <button
                type="button"
                onClick={close}
                className="h-10 rounded-xl border border-border bg-card px-4 text-xs font-semibold hover:bg-muted"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={!parsed.readyCount || applying}
                onClick={() => void applyImport()}
                className="h-10 rounded-xl bg-primary px-5 text-xs font-semibold text-primary-foreground hover:opacity-90 disabled:opacity-50"
              >
                {applying ? "Saving…" : `Import ${parsed.readyCount} scores`}
              </button>
            </div>
          </>
        )}
      </div>
    </Modal>
  );
}
