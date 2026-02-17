import { z } from "zod";
import axios from "axios";
import { join } from "node:path";
import { splitMarkdown } from "../lib/markdown-splitter.js";
import { projectDir, ensureDir, writeText, writeJson } from "../lib/storage.js";

export const FetchPageSchema = z.object({
  url: z.string().url().describe("URL of the page to fetch"),
  projectId: z.string()
    .min(1).max(64)
    .regex(/^[a-z0-9_-]+$/, "Must be lowercase alphanumeric with hyphens/underscores")
    .describe("Project identifier (slug)"),
}).strict();

export type FetchPageInput = z.infer<typeof FetchPageSchema>;

export async function fetchPage(params: FetchPageInput) {
  const jinaUrl = `https://r.jina.ai/${params.url}`;
  const response = await axios.get(jinaUrl, {
    headers: { Accept: "text/markdown" },
    timeout: 30000,
  });

  const markdown: string = response.data;
  const dir = projectDir(params.projectId);
  const sectionsDir = join(dir, "sections");
  const translationsDir = join(dir, "translations");
  await ensureDir(sectionsDir);
  await ensureDir(translationsDir);

  // Save source
  await writeText(join(dir, "source.md"), markdown);

  // Split and save sections
  const sections = splitMarkdown(markdown);
  for (const section of sections) {
    const filename = `${String(section.index).padStart(3, "0")}-${slugify(section.title)}.md`;
    await writeText(join(sectionsDir, filename), section.content);
  }

  // Initialize status
  const status = {
    projectId: params.projectId,
    sourceUrl: params.url,
    fetchedAt: new Date().toISOString(),
    sections: sections.map((s) => ({
      index: s.index,
      title: s.title,
      filename: `${String(s.index).padStart(3, "0")}-${slugify(s.title)}.md`,
      status: "pending" as const,
    })),
  };
  await writeJson(join(dir, "status.json"), status);

  // Initialize empty glossary
  await writeJson(join(dir, "glossary.json"), { entries: [] });

  return {
    content: [{
      type: "text" as const,
      text: [
        `Project "${params.projectId}" created.`,
        `Source: ${params.url}`,
        `Total: ${markdown.length} bytes, ${sections.length} sections`,
        "",
        "Sections:",
        ...sections.map((s) =>
          `  ${s.index}: ${s.title} (~${s.estimatedTokens} tokens)`
        ),
      ].join("\n"),
    }],
  };
}

function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 40) || "untitled";
}
