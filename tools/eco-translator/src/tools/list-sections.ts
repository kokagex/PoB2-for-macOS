import { z } from "zod";
import { join } from "node:path";
import { projectDir, readJson, readText } from "../lib/storage.js";
import { estimateTokens } from "../lib/token-counter.js";

export const ListSectionsSchema = z.object({
  projectId: z.string().min(1).describe("Project identifier"),
}).strict();

interface StatusFile {
  sections: { index: number; title: string; filename: string; status: string; translatedAt?: string }[];
}

export async function listSections(params: z.infer<typeof ListSectionsSchema>) {
  const dir = projectDir(params.projectId);
  const status = await readJson<StatusFile>(join(dir, "status.json"));
  if (!status) {
    return { content: [{ type: "text" as const, text: `Project "${params.projectId}" not found.` }] };
  }

  const lines: string[] = [`Sections for "${params.projectId}":\n`];
  let translated = 0;

  for (const s of status.sections) {
    const content = await readText(join(dir, "sections", s.filename));
    const tokens = content ? estimateTokens(content) : 0;
    const icon = s.status === "translated" ? "[done]" : s.status === "in_progress" ? "[...]" : "[    ]";
    if (s.status === "translated") translated++;
    lines.push(`${icon} ${s.index}: ${s.title} (~${tokens} tokens)`);
  }

  lines.push(`\nProgress: ${translated}/${status.sections.length}`);

  return { content: [{ type: "text" as const, text: lines.join("\n") }] };
}
