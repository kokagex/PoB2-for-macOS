import { z } from "zod";
import { join } from "node:path";
import { projectDir, readJson, readText } from "../lib/storage.js";
import { estimateTokens } from "../lib/token-counter.js";

export const GetSectionSchema = z.object({
  projectId: z.string().min(1).describe("Project identifier"),
  sectionIndex: z.number().int().min(0).describe("Section number (0-indexed)"),
}).strict();

interface StatusFile {
  sections: { index: number; title: string; filename: string; status: string }[];
}

interface GlossaryFile {
  entries: { source: string; target: string; context?: string; addedAt: string }[];
}

export async function getSection(params: z.infer<typeof GetSectionSchema>) {
  const dir = projectDir(params.projectId);
  const status = await readJson<StatusFile>(join(dir, "status.json"));
  if (!status) {
    return { content: [{ type: "text" as const, text: `Project "${params.projectId}" not found.` }] };
  }

  const section = status.sections[params.sectionIndex];
  if (!section) {
    return { content: [{ type: "text" as const, text: `Section ${params.sectionIndex} not found. Total: ${status.sections.length}` }] };
  }

  const content = await readText(join(dir, "sections", section.filename));
  if (!content) {
    return { content: [{ type: "text" as const, text: `Section file missing: ${section.filename}` }] };
  }

  // Load glossary for context
  const glossary = await readJson<GlossaryFile>(join(dir, "glossary.json"));
  const glossaryText = glossary && glossary.entries.length > 0
    ? "\n\n---\nGlossary (use these translations consistently):\n" +
      glossary.entries.map((e) => `- ${e.source} → ${e.target}`).join("\n")
    : "";

  const tokens = estimateTokens(content);

  return {
    content: [{
      type: "text" as const,
      text: [
        `## Section ${section.index}: ${section.title}`,
        `Estimated tokens: ~${tokens}`,
        "",
        content,
        glossaryText,
      ].join("\n"),
    }],
  };
}
