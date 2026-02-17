import { z } from "zod";
import { join } from "node:path";
import { projectDir, readJson } from "../lib/storage.js";

export const GlossaryLookupSchema = z.object({
  projectId: z.string().min(1).describe("Project identifier"),
  query: z.string().min(1).describe("Search keyword (partial match)"),
}).strict();

interface GlossaryFile {
  entries: { source: string; target: string; context?: string; addedAt: string }[];
}

export async function glossaryLookup(params: z.infer<typeof GlossaryLookupSchema>) {
  const dir = projectDir(params.projectId);
  const glossary = await readJson<GlossaryFile>(join(dir, "glossary.json"));
  if (!glossary) {
    return { content: [{ type: "text" as const, text: `Project "${params.projectId}" not found or no glossary.` }] };
  }

  const q = params.query.toLowerCase();
  const matches = glossary.entries.filter(
    (e) => e.source.toLowerCase().includes(q) || e.target.toLowerCase().includes(q)
  );

  if (matches.length === 0) {
    return { content: [{ type: "text" as const, text: `No glossary matches for "${params.query}".` }] };
  }

  const lines = matches.map((e) => {
    let line = `- ${e.source} → ${e.target}`;
    if (e.context) line += ` (${e.context})`;
    return line;
  });

  return { content: [{ type: "text" as const, text: `Glossary matches (${matches.length}):\n${lines.join("\n")}` }] };
}
