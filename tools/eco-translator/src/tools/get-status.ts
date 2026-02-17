import { z } from "zod";
import { join } from "node:path";
import { projectDir, readJson } from "../lib/storage.js";

export const GetStatusSchema = z.object({
  projectId: z.string().min(1).describe("Project identifier"),
}).strict();

interface StatusFile {
  projectId: string;
  sourceUrl: string;
  fetchedAt: string;
  sections: { index: number; title: string; filename: string; status: string; translatedAt?: string }[];
}

interface GlossaryFile {
  entries: unknown[];
}

export async function getStatus(params: z.infer<typeof GetStatusSchema>) {
  const dir = projectDir(params.projectId);
  const status = await readJson<StatusFile>(join(dir, "status.json"));
  if (!status) {
    return { content: [{ type: "text" as const, text: `Project "${params.projectId}" not found.` }] };
  }

  const glossary = await readJson<GlossaryFile>(join(dir, "glossary.json"));
  const glossaryCount = glossary?.entries.length ?? 0;
  const translated = status.sections.filter((s) => s.status === "translated").length;
  const total = status.sections.length;
  const next = status.sections.find((s) => s.status === "pending");

  const lines = [
    `# Project: ${status.projectId}`,
    `Source: ${status.sourceUrl}`,
    `Fetched: ${status.fetchedAt}`,
    `Progress: ${translated}/${total} (${Math.round(translated / total * 100)}%)`,
    `Glossary: ${glossaryCount} terms`,
    "",
    "## Sections",
    ...status.sections.map((s) => {
      const icon = s.status === "translated" ? "[done]" : s.status === "in_progress" ? "[...]" : "[    ]";
      return `${icon} ${s.index}: ${s.title}`;
    }),
  ];

  if (next) {
    lines.push("", `**Next recommended:** Section ${next.index} — "${next.title}"`);
  } else {
    lines.push("", "**All sections translated!**");
  }

  return { content: [{ type: "text" as const, text: lines.join("\n") }] };
}
