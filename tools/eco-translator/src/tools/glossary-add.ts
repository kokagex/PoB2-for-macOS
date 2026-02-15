import { z } from "zod";
import { join } from "node:path";
import { projectDir, readJson, writeJson } from "../lib/storage.js";

export const GlossaryAddSchema = z.object({
  projectId: z.string().min(1).describe("Project identifier"),
  entries: z.array(z.object({
    source: z.string().describe("Source term"),
    target: z.string().describe("Translated term"),
    context: z.string().optional().describe("Usage context"),
  })).min(1).describe("Terms to add"),
}).strict();

interface GlossaryFile {
  entries: { source: string; target: string; context?: string; addedAt: string }[];
}

export async function glossaryAdd(params: z.infer<typeof GlossaryAddSchema>) {
  const dir = projectDir(params.projectId);
  const glossary = await readJson<GlossaryFile>(join(dir, "glossary.json")) ?? { entries: [] };
  const existing = new Set(glossary.entries.map((e) => e.source.toLowerCase()));

  let added = 0;
  let skipped = 0;
  for (const entry of params.entries) {
    if (existing.has(entry.source.toLowerCase())) {
      skipped++;
    } else {
      glossary.entries.push({
        source: entry.source,
        target: entry.target,
        context: entry.context,
        addedAt: new Date().toISOString(),
      });
      existing.add(entry.source.toLowerCase());
      added++;
    }
  }

  await writeJson(join(dir, "glossary.json"), glossary);

  return {
    content: [{
      type: "text" as const,
      text: `Glossary updated: +${added} added, ${skipped} skipped (duplicates). Total: ${glossary.entries.length}`,
    }],
  };
}
