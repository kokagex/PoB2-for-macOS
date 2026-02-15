/**
 * tattoo_spec tool: Queues a specification tattoo for later application.
 *
 * C-N5: Queue only — NEVER writes to target files directly.
 * Tattoos are applied during consensus synchronization by the orbit layer.
 */

import { z } from "zod";
import { randomUUID } from "node:crypto";
import type { StatusStore, LogosStatus } from "@logos-orbit/shared";

export const TattooSpecSchema = z
  .object({
    targetFile: z.string().min(1),
    content: z.string().min(1),
    position: z.enum(["append", "section"]),
    sectionName: z.string().optional(),
    justification: z.string().min(1),
  })
  .strict();

export type TattooSpecInput = z.infer<typeof TattooSpecSchema>;

export interface TattooSpecResult {
  tattooId: string;
  queued: boolean;
  pendingCount: number;
}

export async function tattooSpec(
  input: TattooSpecInput,
  store: StatusStore
): Promise<TattooSpecResult> {
  // 1. Check HALTED state
  const currentStatus = await store.read();
  if (currentStatus.orbit.consensusState === "HALTED") {
    throw new Error(
      "System is HALTED. Cannot queue tattoos while halted."
    );
  }

  // 2. Validate section position requires sectionName
  if (input.position === "section" && !input.sectionName) {
    throw new Error(
      'sectionName is required when position is "section".'
    );
  }

  // 3. Create tattoo record
  const tattooId = `tattoo_${randomUUID().slice(0, 8)}`;
  const now = new Date().toISOString();

  // 4. C-N5: Queue only — add to pendingTattoos in nomos section
  const updatedStatus = await store.write(
    "nomos",
    (current: LogosStatus): LogosStatus => {
      const newTattoo = {
        id: tattooId,
        targetFile: input.targetFile,
        content: input.content,
        position: input.position as "append" | "section",
        ...(input.sectionName ? { sectionName: input.sectionName } : {}),
        justification: input.justification,
        createdAt: now,
      };

      return {
        ...current,
        nomos: {
          ...current.nomos,
          pendingTattoos: [...current.nomos.pendingTattoos, newTattoo],
        },
      };
    }
  );

  return {
    tattooId,
    queued: true,
    pendingCount: updatedStatus.nomos.pendingTattoos.length,
  };
}
