/**
 * Rule generator: Creates rules from failure analysis.
 *
 * Generates deterministic rule IDs via SHA-256 hash of normalized condition text.
 * Severity is auto-calculated from session context and failure type.
 */

import { createHash } from "node:crypto";
import type { Rule } from "@logos-orbit/shared";

// ── Types ───────────────────────────────────────────────────────────────

export interface FailureInput {
  failureId: string;
  failureType:
    | "logic_error"
    | "runtime_error"
    | "regression"
    | "drift_stop"
    | "confidence_fail";
  description: string;
  rootCause: string;
  sessionContext: {
    lastIntegrityConfidence: number;
    lastChronosEntropy: number;
    actionCount: number;
  };
}

export type RuleSeverity = "error" | "warning";

export interface GeneratedRule {
  rule: Rule;
}

// ── Condition templates ─────────────────────────────────────────────────

const CONDITION_TEMPLATES: Record<FailureInput["failureType"], (input: FailureInput) => string> = {
  logic_error: (input) =>
    `logic error detected: ${input.rootCause}`,
  runtime_error: (input) =>
    `runtime error in execution: ${input.rootCause}`,
  regression: (input) =>
    `regression detected: ${input.rootCause}`,
  drift_stop: (input) =>
    `drift stop triggered at entropy ${input.sessionContext.lastChronosEntropy.toFixed(3)}: ${input.rootCause}`,
  confidence_fail: (input) =>
    `confidence below threshold (${input.sessionContext.lastIntegrityConfidence.toFixed(3)}): ${input.rootCause}`,
};

// ── Core functions ──────────────────────────────────────────────────────

/**
 * Normalize a condition string: lowercase, collapse whitespace.
 */
function normalizeCondition(condition: string): string {
  return condition.toLowerCase().replace(/\s+/g, " ").trim();
}

/**
 * Hash a condition string to produce a deterministic 8-char hex ID suffix.
 */
export function hashCondition(condition: string): string {
  const normalized = normalizeCondition(condition);
  return createHash("sha256").update(normalized).digest("hex").slice(0, 8);
}

/**
 * Calculate severity from failure context.
 *
 * - confidence < 0.4 OR failureType is confidence_fail/drift_stop → "error"
 * - Otherwise → "warning"
 */
function calculateSeverity(input: FailureInput): RuleSeverity {
  if (input.sessionContext.lastIntegrityConfidence < 0.4) return "error";
  if (input.failureType === "confidence_fail") return "error";
  if (input.failureType === "drift_stop") return "error";
  return "warning";
}

/**
 * Generate a Rule from a failure analysis input.
 */
export function generateRuleFromFailure(input: FailureInput): GeneratedRule {
  const condition = CONDITION_TEMPLATES[input.failureType](input);
  const hash = hashCondition(condition);
  const ruleId = `RULE_${hash}`;
  const severity = calculateSeverity(input);
  const now = new Date().toISOString();

  const evidence = [
    `failureId: ${input.failureId}`,
    `failureType: ${input.failureType}`,
    `description: ${input.description}`,
    `confidence: ${input.sessionContext.lastIntegrityConfidence}`,
    `entropy: ${input.sessionContext.lastChronosEntropy}`,
    `actionCount: ${input.sessionContext.actionCount}`,
  ].join("; ");

  const rule: Rule = {
    id: ruleId,
    createdAt: now,
    createdFrom: `failure:${input.failureId}`,
    condition,
    severity,
    message: `[${severity}] ${condition}`,
    evidence,
    tags: [input.failureType],
  };

  return { rule };
}
