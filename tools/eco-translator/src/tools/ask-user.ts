import { z } from "zod";

export const AskUserSchema = z.object({
  projectId: z.string().min(1).describe("Project identifier"),
  sectionIndex: z.number().int().min(0).describe("Section being translated"),
  question: z.string().min(1).describe("Question for the user"),
  category: z.enum(["terminology", "ambiguity", "context", "style"])
    .describe("Question category"),
  options: z.array(z.string()).optional()
    .describe("Possible answers to choose from"),
}).strict();

export async function askUser(params: z.infer<typeof AskUserSchema>) {
  const lines = [
    `**Translation Question** (Section ${params.sectionIndex})`,
    `Category: ${params.category}`,
    "",
    params.question,
  ];

  if (params.options && params.options.length > 0) {
    lines.push("", "Options:");
    params.options.forEach((opt, i) => lines.push(`  ${i + 1}. ${opt}`));
  }

  lines.push("", "_Please answer this question before continuing translation._");

  return {
    content: [{ type: "text" as const, text: lines.join("\n") }],
  };
}
