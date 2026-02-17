import { z } from "zod";
import {
  PropositionSchema,
  type Proposition,
  type LogosStatus,
  type StatusStore,
} from "@logos-orbit/shared";
import {
  detectPenalties,
  calculateConfidence,
  determineVerdict,
} from "../lib/deduction-engine.js";

// ── Schema ──────────────────────────────────────────────────────────────────

export const VerifyReasoningSchema = z
  .object({
    premises: z.array(PropositionSchema).min(1, "At least one premise required"),
    conclusion: PropositionSchema,
    derivationSteps: z
      .array(
        z.object({
          from: z.array(z.string()),
          to: z.string(),
          rule: z.string(),
        })
      )
      .optional(),
    context: z.string().min(1, "context must not be empty"),
  })
  .strict();

export type VerifyReasoningInput = z.infer<typeof VerifyReasoningSchema>;

// ── HALTED check ────────────────────────────────────────────────────────────

function isHalted(status: LogosStatus): boolean {
  return status.orbit.consensusState === "HALTED";
}

// ── Handler ─────────────────────────────────────────────────────────────────

export async function verifyReasoning(
  input: VerifyReasoningInput,
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

  // Gather prior conclusions from contradictions
  const priorConclusions: Proposition[] = current.integrity.contradictions
    .filter((c) => !c.resolved)
    .flatMap((c) => [c.propositionA, c.propositionB]);

  const penalties = detectPenalties(
    input.premises,
    input.conclusion,
    priorConclusions
  );

  const confidence = calculateConfidence(penalties);
  const verdict = determineVerdict(confidence);

  // Write results to status
  const updated = await store.write("integrity", (s) => {
    const now = new Date().toISOString();
    const newStatus = { ...s };

    newStatus.integrity = {
      ...s.integrity,
      score: confidence,
      penalties: [...s.integrity.penalties, ...penalties],
      lastCheck: now,
    };

    // If FAIL, set HALTED via consensusState + critical alert
    if (verdict === "FAIL") {
      newStatus.orbit = {
        ...s.orbit,
        consensusState: "HALTED" as const,
        alerts: [
          ...s.orbit.alerts,
          {
            id: crypto.randomUUID(),
            level: "critical" as const,
            message: "INTEGRITY HALTED: verification failed",
            source: "integrity" as const,
            timestamp: now,
            dismissed: false,
          },
        ],
      };
    }

    return newStatus;
  });

  const totalVerifications = updated.integrity.penalties.length;

  return {
    confidence,
    verdict,
    penalties: penalties.map((p) => ({
      type: p.type,
      weight: p.weight,
      description: p.description,
    })),
    totalVerifications,
  };
}
