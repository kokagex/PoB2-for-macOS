import { estimateTokens } from "./token-counter.js";

export interface Section {
  index: number;
  title: string;
  level: number;        // heading level (1-6), 0 for preamble
  content: string;       // full markdown including heading
  estimatedTokens: number;
}

/**
 * Split markdown by headings (# through ####).
 * Returns array of sections with token estimates.
 */
export function splitMarkdown(markdown: string): Section[] {
  const lines = markdown.split("\n");
  const sections: Section[] = [];
  let currentLines: string[] = [];
  let currentTitle = "";
  let currentLevel = 0;
  let hasPreamble = false;
  let hasHeadings = false;

  for (const line of lines) {
    const headingMatch = line.match(/^(#{1,4})\s+(.+)$/);
    if (headingMatch) {
      hasHeadings = true;
      // Flush previous section
      if (currentLines.length > 0) {
        const content = currentLines.join("\n").trim();
        if (content) {
          sections.push({
            index: sections.length,
            title: currentTitle || (hasPreamble ? "Preamble" : "Document"),
            level: currentLevel,
            content,
            estimatedTokens: estimateTokens(content),
          });
        }
      }
      currentTitle = headingMatch[2].trim();
      currentLevel = headingMatch[1].length;
      currentLines = [line];
    } else {
      if (sections.length === 0 && currentTitle === "" && line.trim()) {
        hasPreamble = true;
      }
      currentLines.push(line);
    }
  }

  // Flush last section
  if (currentLines.length > 0) {
    const content = currentLines.join("\n").trim();
    if (content) {
      const fallbackTitle = hasPreamble && hasHeadings ? "Preamble" : "Document";
      sections.push({
        index: sections.length,
        title: currentTitle || fallbackTitle,
        level: currentLevel,
        content,
        estimatedTokens: estimateTokens(content),
      });
    }
  }

  return sections;
}
