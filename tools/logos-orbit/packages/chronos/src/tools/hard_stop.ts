/**
 * hard_stop tool: Trigger, check, or release a hard stop.
 *
 * C-C5: hard_stop release requires userApproval string.
 */

import { z } from "zod";
import type { StatusStore, LogosStatus } from "@logos-orbit/shared";

/** Raw shape (no refine) — used for MCP tool registration. */
export const HardStopRawSchema = z
  .object({
    action: z.enum(["trigger", "check", "request_release"]),
    reason: z.string().min(1).optional(),
    userApproval: z.string().min(1).optional(),
  })
  .strict();

/** Full schema with refinements — used for runtime validation. */
export const HardStopSchema = HardStopRawSchema.refine(
  (d) => d.action !== "trigger" || d.reason,
  { message: "reason required for trigger" }
).refine(
  (d) => d.action !== "request_release" || d.userApproval,
  { message: "userApproval required for release" }
);

export type HardStopInput = z.infer<typeof HardStopSchema>;

export interface HardStopResult {
  hardStopActive: boolean;
  reason: string | null;
  consensusState: string;
  message: string;
}

export async function hardStop(
  input: HardStopInput,
  store: StatusStore
): Promise<HardStopResult> {
  const now = new Date().toISOString();

  if (input.action === "trigger") {
    const reason = input.reason!;

    await store.write("chronos", (current: LogosStatus): LogosStatus => {
      return {
        ...current,
        chronos: {
          ...current.chronos,
          driftWarnings: [
            ...current.chronos.driftWarnings,
            {
              timestamp: now,
              entropy: 1.0,
              message: `HARD_STOP triggered: ${reason}`,
              severity: "HARD_STOP" as const,
            },
          ],
          lastCheck: now,
        },
        orbit: {
          ...current.orbit,
          consensusState: "HALTED",
        },
      };
    });

    return {
      hardStopActive: true,
      reason,
      consensusState: "HALTED",
      message: `Hard stop triggered: ${reason}`,
    };
  }

  if (input.action === "check") {
    const status = await store.read();
    const isHalted = status.orbit.consensusState === "HALTED";
    const lastWarning =
      status.chronos.driftWarnings.length > 0
        ? status.chronos.driftWarnings[status.chronos.driftWarnings.length - 1]
        : null;

    return {
      hardStopActive: isHalted,
      reason: lastWarning ? lastWarning.message : null,
      consensusState: status.orbit.consensusState,
      message: isHalted
        ? "System is HALTED. Use request_release with userApproval to resume."
        : "System is operating normally.",
    };
  }

  // action === "request_release" (C-C5: requires userApproval)
  const status = await store.read();
  if (status.orbit.consensusState !== "HALTED") {
    return {
      hardStopActive: false,
      reason: null,
      consensusState: status.orbit.consensusState,
      message: "No active hard stop to release.",
    };
  }

  await store.write("chronos", (current: LogosStatus): LogosStatus => {
    return {
      ...current,
      chronos: {
        ...current.chronos,
        // DriftWarnings are immutable records, no acknowledged field to flip
        lastCheck: now,
      },
      orbit: {
        ...current.orbit,
        consensusState: "ALIGNED",
      },
    };
  });

  return {
    hardStopActive: false,
    reason: null,
    consensusState: "ALIGNED",
    message: `Hard stop released with user approval: "${input.userApproval}"`,
  };
}
