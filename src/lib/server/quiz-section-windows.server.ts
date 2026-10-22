import { db } from "@/integrations/db/client.server";
import { unwrap } from "@/lib/server/utils.server";

export interface QuizSectionWindow {
  quiz_id: string;
  section_name: string;
  opens_at: string | null;
  closes_at: string | null;
}

export async function getQuizSectionWindow(
  quizId: string,
  section: string | null | undefined,
): Promise<QuizSectionWindow | null> {
  const normalizedSection = section?.trim();
  if (!normalizedSection) return null;
  return unwrap<QuizSectionWindow | null>(
    db
      .from("quiz_section_windows")
      .select("quiz_id, section_name, opens_at, closes_at")
      .eq("quiz_id", quizId)
      .ilike("section_name", normalizedSection)
      .maybeSingle(),
  );
}

export async function listQuizSectionWindows(
  quizIds: string[],
  section: string | null | undefined,
): Promise<QuizSectionWindow[]> {
  const normalizedSection = section?.trim();
  if (!quizIds.length || !normalizedSection) return [];
  return unwrap<QuizSectionWindow[]>(
    db
      .from("quiz_section_windows")
      .select("quiz_id, section_name, opens_at, closes_at")
      .in("quiz_id", quizIds)
      .ilike("section_name", normalizedSection),
  );
}
