/**
 * record_action tool: Records an agent action and monitors for drift.
 *
 * C-C1: NEVER delete from actions array — append only.
 * C-C2: Thresholds are Object.freeze() constants.
 * C-C3: intent and rationale mandatory, min 10 chars.
 */

import { z } from "zod";
import { randomUUID } from "node:crypto";
import type { StatusStore, LogosStatus, ActionRecord } from "@logos-orbit/shared";
import {
  calculateEntropy,
  detectStutter,
  ENTROPY_THRESHOLDS,
} from "../lib/entropy.js";

export const RecordActionSchema = z
  .object({
    actionType: z.enum([
      "search",
      "edit",
      "read",
      "write",
      "verify",
      "plan",
      "ask",
    ]),
    target: z.string().min(1),
    intent: z.string().min(10), // C-C3
    rationale: z.string().min(10), // C-C3
  })
  .strict();

export type RecordActionInput = z.infer<typeof RecordActionSchema>;

const SLIDING_WINDOW = 20;

export interface RecordActionResult {
  actionId: string;
  currentEntropy: number;
  stutterDetected: boolean;
  driftStatus: "NORMAL" | "WARNING" | "HARD_STOP";
  warning: string | null;
}

export async function recordAction(
  input: RecordActionInput,
  store: StatusStore
): Promise<RecordActionResult> {
  // 1. Check HALTED state
  const currentStatus = await store.read();
  if (currentStatus.orbit.consensusState === "HALTED") {
    throw new Error(
      "System is HALTED. Use hard_stop with action=request_release to resume."
    );
  }

  // 2. Create ActionRecord with proper fields
  const actionId = `act_${randomUUID().slice(0, 8)}`;
  const now = new Date().toISOString();
  const actionRecord: ActionRecord = {
    id: actionId,
    timestamp: now,
    actionType: input.actionType,
    target: input.target,
    intent: input.intent,
    rationale: input.rationale,
  };

  // 3. Append to actions (C-C1: never delete)
  const updatedStatus = await store.write(
    "chronos",
    (current: LogosStatus): LogosStatus => {
      const actions = [...current.chronos.actions, actionRecord];
      return {
        ...current,
        chronos: {
          ...current.chronos,
          actions,
          lastCheck: now,
        },
      };
    }
  );

  // 4. Calculate entropy on sliding window
  const recentActions = updatedStatus.chronos.actions.slice(-SLIDING_WINDOW);
  let currentEntropy = calculateEntropy(recentActions);

  // 5. Stutter detection — if detected, force entropy = 1.0
  const stutter = detectStutter(recentActions);
  if (stutter.detected) {
    currentEntropy = 1.0;
  }

  // 6. Determine drift status (C-C2: fixed thresholds)
  let driftStatus: RecordActionResult["driftStatus"] = "NORMAL";
  let warning: string | null = null;

  if (currentEntropy >= ENTROPY_THRESHOLDS.HARD_STOP) {
    driftStatus = "HARD_STOP";
    warning = `Entropy ${currentEntropy.toFixed(3)} exceeds HARD_STOP threshold (${ENTROPY_THRESHOLDS.HARD_STOP}). ${stutter.detected ? `Stutter detected: "${stutter.pattern?.intent}" on "${stutter.pattern?.target}" (${stutter.pattern?.count}x).` : ""}`;
  } else if (currentEntropy >= ENTROPY_THRESHOLDS.WARNING) {
    driftStatus = "WARNING";
    warning = `Entropy ${currentEntropy.toFixed(3)} exceeds WARNING threshold (${ENTROPY_THRESHOLDS.WARNING}).`;
  }

  // 7. On HARD_STOP or WARNING: append drift warning
  if (driftStatus === "HARD_STOP") {
    await store.write("chronos", (current: LogosStatus): LogosStatus => {
      return {
        ...current,
        chronos: {
          ...current.chronos,
          driftWarnings: [
            ...current.chronos.driftWarnings,
            {
              timestamp: now,
              entropy: currentEntropy,
              message: warning!,
              severity: "HARD_STOP" as const,
            },
          ],
        },
        orbit: {
          ...current.orbit,
          consensusState: "HALTED",
        },
      };
    });
  } else if (driftStatus === "WARNING") {
    await store.write("chronos", (current: LogosStatus): LogosStatus => {
      return {
        ...current,
        chronos: {
          ...current.chronos,
          driftWarnings: [
            ...current.chronos.driftWarnings,
            {
              timestamp: now,
              entropy: currentEntropy,
              message: warning!,
              severity: "WARNING" as const,
            },
          ],
        },
      };
    });
  }

  return {
    actionId,
    currentEntropy,
    stutterDetected: stutter.detected,
    driftStatus,
    warning,
  };
}
