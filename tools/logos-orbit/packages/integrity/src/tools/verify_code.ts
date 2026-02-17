import { z } from "zod";
import { readFile } from "node:fs/promises";
import {
  PENALTY_WEIGHTS,
  type Penalty,
  type LogosStatus,
  type StatusStore,
} from "@logos-orbit/shared";
import { calculateConfidence, determineVerdict } from "../lib/deduction-engine.js";

// ── Schema ──────────────────────────────────────────────────────────────────

export const VerifyCodeSchema = z
  .object({
    filePath: z.string().min(1, "filePath must not be empty"),
    claimedBehavior: z.string().min(1, "claimedBehavior must not be empty"),
    changedLines: z
      .array(
        z
          .object({
            from: z.number().int().min(1),
            to: z.number().int().min(1),
          })
          .refine((r) => r.from <= r.to, {
            message: "from must be <= to",
          })
      )
      .min(1, "At least one changedLines range required"),
  })
  .strict();

export type VerifyCodeInput = z.infer<typeof VerifyCodeSchema>;

// ── Stopwords ───────────────────────────────────────────────────────────────

const STOPWORDS = new Set([
  "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
  "have", "has", "had", "do", "does", "did", "will", "would", "shall",
  "should", "may", "might", "must", "can", "could", "of", "in", "to",
  "for", "with", "on", "at", "from", "by", "about", "as", "into",
  "through", "during", "before", "after", "and", "but", "or", "not",
  "it", "its", "this", "that", "these", "those", "i", "we", "you",
  "they", "he", "she", "my", "our", "your", "their",
]);

function contentTokens(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 0 && !STOPWORDS.has(t));
}

// ── HALTED check ────────────────────────────────────────────────────────────

function isHalted(status: LogosStatus): boolean {
  return status.orbit.consensusState === "HALTED";
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function makePenalty(
  type: Penalty["type"],
  description: string
): Penalty {
  return {
    type,
    weight: PENALTY_WEIGHTS[type],
    description,
    timestamp: new Date().toISOString(),
  };
}

// ── Handler ─────────────────────────────────────────────────────────────────

export async function verifyCode(
  input: VerifyCodeInput,
  store: StatusStore
): Promise<{
  confidence: number;
  verdict: "PASS" | "WARN" | "FAIL";
  penalties: Array<{ type: string; weight: number; description: string }>;
  totalVerifications: number;
}> {
  const current = await store.read();

  if (isHalted(current)) {
    throw new Error(
      "System is HALTED due to a prior integrity failure. Dismiss the critical alert to resume."
    );
  }

  const penalties: Penalty[] = [];

  // 1. Try to read the file
  let fileContent: string;
  try {
    fileContent = await readFile(input.filePath, "utf-8");
  } catch {
    penalties.push(
      makePenalty(
        "UNSUPPORTED_CONCLUSION",
        `File not found: ${input.filePath}`
      )
    );
    const confidence = calculateConfidence(penalties);
    const verdict = determineVerdict(confidence);

    await writeResult(store, confidence, penalties, verdict);

    return {
      confidence,
      verdict,
      penalties: penalties.map((p) => ({
        type: p.type,
        weight: p.weight,
        description: p.description,
      })),
      totalVerifications: (await store.read()).integrity.penalties.length,
    };
  }

  const lines = fileContent.split("\n");

  // 2. Check changedLines within file bounds
  for (const range of input.changedLines) {
    if (range.from > lines.length || range.to > lines.length) {
      penalties.push(
        makePenalty(
          "UNSUPPORTED_CONCLUSION",
          `Changed lines ${range.from}-${range.to} exceed file length (${lines.length} lines)`
        )
      );
    }
  }

  // 3. Token overlap analysis
  const changedCode = input.changedLines
    .map((range) =>
      lines.slice(Math.max(0, range.from - 1), range.to).join("\n")
    )
    .join("\n");

  const claimTokens = contentTokens(input.claimedBehavior);
  const codeTokens = new Set(contentTokens(changedCode));

  if (claimTokens.length > 0) {
    const overlapCount = claimTokens.filter((t) => codeTokens.has(t)).length;
    const overlapRatio = overlapCount / claimTokens.length;

    if (overlapRatio < 0.1) {
      penalties.push(
        makePenalty(
          "CONCEPT_LEAP",
          `Only ${Math.round(overlapRatio * 100)}% of claimed behavior tokens found in changed code`
        )
      );
    }
  }

  const confidence = calculateConfidence(penalties);
  const verdict = determineVerdict(confidence);

  await writeResult(store, confidence, penalties, verdict);

  const updated = await store.read();

  return {
    confidence,
    verdict,
    penalties: penalties.map((p) => ({
      type: p.type,
      weight: p.weight,
      description: p.description,
    })),
    totalVerifications: updated.integrity.penalties.length,
  };
}

async function writeResult(
  store: StatusStore,
  confidence: number,
  penalties: Penalty[],
  verdict: "PASS" | "WARN" | "FAIL"
): Promise<void> {
  await store.write("integrity", (s) => {
    const now = new Date().toISOString();
    const newStatus = {
      ...s,
      integrity: {
        ...s.integrity,
        score: confidence,
        penalties: [...s.integrity.penalties, ...penalties],
        lastCheck: now,
      },
    };

    if (verdict === "FAIL") {
      newStatus.orbit = {
        ...s.orbit,
        consensusState: "HALTED" as const,
        alerts: [
          ...s.orbit.alerts,
          {
            id: crypto.randomUUID(),
            level: "critical" as const,
            message: "INTEGRITY HALTED: code verification failed",
            source: "integrity" as const,
            timestamp: now,
            dismissed: false,
          },
        ],
      };
    }

    return newStatus;
  });
}
