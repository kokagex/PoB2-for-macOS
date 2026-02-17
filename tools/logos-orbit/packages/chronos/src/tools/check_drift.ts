/**
 * check_drift tool: Analyze current drift state without recording a new action.
 */

import { z } from "zod";
import type { StatusStore } from "@logos-orbit/shared";
import {
  calculateEntropy,
  detectStutter,
  ENTROPY_THRESHOLDS,
} from "../lib/entropy.js";
import { detectRationaleContradictions } from "../lib/contradiction.js";

export const CheckDriftSchema = z
  .object({
    windowSize: z.number().int().min(5).max(100).default(20),
  })
  .strict();

export type CheckDriftInput = z.infer<typeof CheckDriftSchema>;

export interface CheckDriftResult {
  entropy: number;
  actionDistribution: Record<string, number>;
  stutterPatterns: Array<{
    intent: string;
    target: string;
    count: number;
  }>;
  rationaleContradictions: Array<{
    actionA: string;
    actionB: string;
    contradiction: string;
  }>;
  recommendation: "CONTINUE" | "PAUSE_AND_REFLECT" | "HARD_STOP";
  totalActions: number;
  windowSize: number;
}

export async function checkDrift(
  input: CheckDriftInput,
  store: StatusStore
): Promise<CheckDriftResult> {
  const status = await store.read();
  const allActions = status.chronos.actions;
  const windowActions = allActions.slice(-input.windowSize);

  // Calculate entropy
  const entropy = calculateEntropy(windowActions);

  // Action distribution
  const distribution: Record<string, number> = {};
  for (const action of windowActions) {
    distribution[action.actionType] =
      (distribution[action.actionType] || 0) + 1;
  }

  // Stutter detection
  const stutter = detectStutter(windowActions);
  const stutterPatterns = stutter.detected && stutter.pattern
    ? [stutter.pattern]
    : [];

  // Rationale contradictions
  const contradictions = detectRationaleContradictions(windowActions);

  // Recommendation
  let recommendation: CheckDriftResult["recommendation"] = "CONTINUE";
  if (entropy >= ENTROPY_THRESHOLDS.HARD_STOP || stutter.detected) {
    recommendation = "HARD_STOP";
  } else if (
    entropy >= ENTROPY_THRESHOLDS.WARNING ||
    contradictions.length > 0
  ) {
    recommendation = "PAUSE_AND_REFLECT";
  }

  return {
    entropy,
    actionDistribution: distribution,
    stutterPatterns,
    rationaleContradictions: contradictions,
    recommendation,
    totalActions: allActions.length,
    windowSize: input.windowSize,
  };
}
