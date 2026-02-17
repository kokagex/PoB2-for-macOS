import { z } from "zod";
import { join } from "node:path";
import { projectDir, readJson, writeJson, writeText } from "../lib/storage.js";

export const SaveTranslationSchema = z.object({
  projectId: z.string().min(1).describe("Project identifier"),
  sectionIndex: z.number().int().min(0).describe("Section number"),
  translatedContent: z.string().min(1).describe("Translated markdown content"),
  newTerms: z.array(z.object({
    source: z.string().describe("Source term"),
    target: z.string().describe("Translated term"),
    context: z.string().optional().describe("Usage context"),
  })).optional().describe("New glossary terms discovered during translation"),
}).strict();

interface StatusFile {
  projectId: string;
  sourceUrl: string;
  fetchedAt: string;
  sections: { index: number; title: string; filename: string; status: string; translatedAt?: string }[];
}

interface GlossaryFile {
  entries: { source: string; target: string; context?: string; addedAt: string }[];
}

export async function saveTranslation(params: z.infer<typeof SaveTranslationSchema>) {
  const dir = projectDir(params.projectId);
  const status = await readJson<StatusFile>(join(dir, "status.json"));
  if (!status) {
    return { content: [{ type: "text" as const, text: `Project "${params.projectId}" not found.` }] };
  }

  const section = status.sections[params.sectionIndex];
  if (!section) {
    return { content: [{ type: "text" as const, text: `Section ${params.sectionIndex} not found.` }] };
  }

  // Save translation
  await writeText(join(dir, "translations", section.filename), params.translatedContent);

  // Update status
  section.status = "translated";
  section.translatedAt = new Date().toISOString();
  await writeJson(join(dir, "status.json"), status);

  // Add new terms to glossary
  let termsAdded = 0;
  if (params.newTerms && params.newTerms.length > 0) {
    const glossary = await readJson<GlossaryFile>(join(dir, "glossary.json")) ?? { entries: [] };
    const existing = new Set(glossary.entries.map((e) => e.source.toLowerCase()));
    for (const term of params.newTerms) {
      if (!existing.has(term.source.toLowerCase())) {
        glossary.entries.push({
          source: term.source,
          target: term.target,
          context: term.context,
          addedAt: new Date().toISOString(),
        });
        existing.add(term.source.toLowerCase());
        termsAdded++;
      }
    }
    await writeJson(join(dir, "glossary.json"), glossary);
  }

  // Find next section
  const translated = status.sections.filter((s) => s.status === "translated").length;
  const next = status.sections.find((s) => s.status === "pending");

  const lines = [
    `Section ${params.sectionIndex} ("${section.title}") saved.`,
    `Progress: ${translated}/${status.sections.length} (${Math.round(translated / status.sections.length * 100)}%)`,
  ];
  if (termsAdded > 0) lines.push(`Glossary: +${termsAdded} terms`);
  if (next) {
    lines.push(`\nNext recommended: Section ${next.index} — "${next.title}"`);
  } else {
    lines.push("\nAll sections translated!");
  }

  return { content: [{ type: "text" as const, text: lines.join("\n") }] };
}
