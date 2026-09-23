/** One uploaded ClassMate source file, with its extracted text. */
export interface SourceFile {
  name: string;
  size: number;
  text: string;
}

/**
 * Combine every uploaded source file into one labelled context block for the
 * ClassMate assistant. A single file is passed through verbatim; multiple files
 * are delimited so the model can tell them apart.
 */
export function aggregateSourceMaterial(files: SourceFile[]): string {
  if (files.length === 0) return "";
  if (files.length === 1) return files[0]!.text;
  return files
    .map((f, i) => `--- SOURCE MATERIAL ${i + 1}: ${f.name} ---\n${f.text.trim()}`)
    .join("\n\n");
}
