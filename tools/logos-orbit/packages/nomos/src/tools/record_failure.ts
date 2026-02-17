/**
 * record_failure tool: Records a failure for later rule generation.
 *
 * Stores failure analysis in the nomos section of status.json.
 * Returns a failureId for use with generate_rule.
 */

import { z } from "zod";
import { randomUUID } from "node:crypto";
import type { StatusStore, LogosStatus } from "@logos-orbit/shared";

export const RecordFailureSchema = z
  .object({
    failureType: z.enum([
      "logic_error",
      "runtime_error",
      "regression",
      "drift_stop",
      "confidence_fail",
    ]),
    description: z.string().min(1),
    involvedFiles: z.array(z.string()),
    rootCause: z.string().min(1),
    sessionContext: z.object({
      lastIntegrityConfidence: z.number().min(0).max(1),
      lastChronosEntropy: z.number().min(0).max(1),
      actionCount: z.number().int().min(0),
    }),
  })
  .strict();

export type RecordFailureInput = z.infer<typeof RecordFailureSchema>;

export interface RecordFailureResult {
  failureId: string;
  analysisComplete: boolean;
  suggestedRuleType: string;
  readyForRuleGeneration: boolean;
}

export async function recordFailure(
  input: RecordFailureInput,
  store: StatusStore
): Promise<RecordFailureResult> {
  // 1. Check HALTED state
  const currentStatus = await store.read();
  if (currentStatus.orbit.consensusState === "HALTED") {
    throw new Error(
      "System is HALTED. Cannot record failures while halted."
    );
  }

  // 2. Generate failure ID
  const failureId = `fail_${randomUUID().slice(0, 8)}`;
  const now = new Date().toISOString();

  // 3. Store failure analysis in nomos.lastFailureAnalysis
  await store.write("nomos", (current: LogosStatus): LogosStatus => {
    return {
      ...current,
      nomos: {
        ...current.nomos,
        lastFailureAnalysis: {
          timestamp: now,
          failureType: input.failureType,
          generatedRule: "",
        },
      },
    };
  });

  return {
    failureId,
    analysisComplete: true,
    suggestedRuleType: input.failureType,
    readyForRuleGeneration: true,
  };
}
