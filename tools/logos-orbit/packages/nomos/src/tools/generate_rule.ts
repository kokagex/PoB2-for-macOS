/**
 * generate_rule tool: Generates a rule from a recorded failure.
 *
 * C-N1: Refuses if no recent failure (within 5 minutes).
 * C-N3: All rule fields required.
 * C-N4: Deduplication by condition hash.
 */

import { z } from "zod";
import type { StatusStore, LogosStatus } from "@logos-orbit/shared";
import { generateRuleFromFailure } from "../lib/rule-generator.js";
import { writeRuleYaml, readExistingRuleIds } from "../lib/spec-writer.js";
import type { FailureInput } from "../lib/rule-generator.js";

export const GenerateRuleSchema = z
  .object({
    failureId: z.string().min(1),
    failureType: z
      .enum([
        "logic_error",
        "runtime_error",
        "regression",
        "drift_stop",
        "confidence_fail",
      ]),
    description: z.string().min(1),
    rootCause: z.string().min(1),
    sessionContext: z.object({
      lastIntegrityConfidence: z.number().min(0).max(1),
      lastChronosEntropy: z.number().min(0).max(1),
      actionCount: z.number().int().min(0),
    }),
  })
  .strict();

export type GenerateRuleInput = z.infer<typeof GenerateRuleSchema>;

export interface GenerateRuleResult {
  ruleId: string;
  rulePath: string;
  rule: {
    id: string;
    createdAt: string;
    createdFrom: string;
    condition: string;
    severity: string;
    message: string;
    evidence: string;
    tags: string[];
  };
  isDuplicate: boolean;
}

const FIVE_MINUTES_MS = 5 * 60 * 1000;

export async function generateRule(
  input: GenerateRuleInput,
  store: StatusStore,
  rulesDir: string
): Promise<GenerateRuleResult> {
  // 1. C-N1: Check that lastFailureAnalysis exists and is recent (within 5 min)
  const status = await store.read();
  const lastFailure = status.nomos.lastFailureAnalysis;

  if (!lastFailure) {
    throw new Error(
      "No failure record found. Use record_failure first."
    );
  }

  const recordedAt = new Date(lastFailure.timestamp).getTime();
  const now = Date.now();
  if (now - recordedAt > FIVE_MINUTES_MS) {
    throw new Error(
      "Last failure analysis is older than 5 minutes. Record a new failure."
    );
  }

  // 2. Generate rule
  const failureInput: FailureInput = {
    failureId: input.failureId,
    failureType: input.failureType,
    description: input.description,
    rootCause: input.rootCause,
    sessionContext: input.sessionContext,
  };
  const generated = generateRuleFromFailure(failureInput);

  // 3. C-N4: Deduplication check
  const existingIds = await readExistingRuleIds(rulesDir);
  const isDuplicate = existingIds.has(generated.rule.id);

  let rulePath: string;
  if (!isDuplicate) {
    // 4. Write YAML
    rulePath = await writeRuleYaml(rulesDir, {
      id: generated.rule.id,
      createdAt: generated.rule.createdAt,
      createdFrom: generated.rule.createdFrom,
      condition: generated.rule.condition,
      severity: generated.rule.severity,
      message: generated.rule.message,
      evidence: generated.rule.evidence,
      tags: generated.rule.tags,
    });

    // 5. Update status: push to activeRules, increment totalRulesGenerated
    await store.write("nomos", (current: LogosStatus): LogosStatus => {
      return {
        ...current,
        nomos: {
          ...current.nomos,
          activeRules: [...current.nomos.activeRules, generated.rule],
          totalRulesGenerated: current.nomos.totalRulesGenerated + 1,
        },
      };
    });
  } else {
    rulePath = `${rulesDir}/${generated.rule.id}.yaml`;
  }

  return {
    ruleId: generated.rule.id,
    rulePath,
    rule: generated.rule,
    isDuplicate,
  };
}
