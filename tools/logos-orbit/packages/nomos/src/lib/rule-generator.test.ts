import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  generateRuleFromFailure,
  hashCondition,
} from "./rule-generator.js";
import type { FailureInput } from "./rule-generator.js";

function makeInput(overrides: Partial<FailureInput> = {}): FailureInput {
  return {
    failureId: "fail_abc12345",
    failureType: "logic_error",
    description: "Mismatch in calculated damage values",
    rootCause: "Incorrect modifier stacking order",
    sessionContext: {
      lastIntegrityConfidence: 0.8,
      lastChronosEntropy: 0.3,
      actionCount: 12,
    },
    ...overrides,
  };
}

describe("generateRuleFromFailure", () => {
  it("generates a valid rule structure", () => {
    const result = generateRuleFromFailure(makeInput());
    assert.ok(result.rule.id.startsWith("RULE_"), `ID should start with RULE_, got ${result.rule.id}`);
    assert.ok(result.rule.id.length === 13, `ID should be RULE_ + 8 hex chars, got ${result.rule.id}`);
    assert.ok(result.rule.message.length > 0, "message must not be empty");
    assert.ok(result.rule.createdFrom.length > 0, "createdFrom must not be empty");
    assert.ok(result.rule.createdAt.length > 0, "createdAt must not be empty");
    assert.ok(result.rule.condition.length > 0, "condition must not be empty");
    assert.ok(result.rule.evidence.length > 0, "evidence must not be empty");
    assert.ok(Array.isArray(result.rule.tags), "tags must be an array");
    assert.ok(result.rule.tags.length > 0, "tags must not be empty");
    assert.ok(["error", "warning"].includes(result.rule.severity), "severity must be error or warning");
  });

  it("severity=error for confidence < 0.4", () => {
    const result = generateRuleFromFailure(
      makeInput({
        sessionContext: {
          lastIntegrityConfidence: 0.3,
          lastChronosEntropy: 0.2,
          actionCount: 5,
        },
      })
    );
    assert.equal(result.rule.severity, "error");
  });

  it("severity=error for confidence_fail type", () => {
    const result = generateRuleFromFailure(
      makeInput({ failureType: "confidence_fail" })
    );
    assert.equal(result.rule.severity, "error");
  });

  it("severity=error for drift_stop type", () => {
    const result = generateRuleFromFailure(
      makeInput({ failureType: "drift_stop" })
    );
    assert.equal(result.rule.severity, "error");
  });

  it("severity=warning for confidence >= 0.4 with normal failure type", () => {
    const result = generateRuleFromFailure(makeInput());
    assert.equal(result.rule.severity, "warning");
  });

  it("severity=warning for runtime_error with high confidence", () => {
    const result = generateRuleFromFailure(
      makeInput({ failureType: "runtime_error" })
    );
    assert.equal(result.rule.severity, "warning");
  });
});

describe("hashCondition", () => {
  it("produces same hash for equivalent conditions", () => {
    const h1 = hashCondition("logic error detected: bad stacking");
    const h2 = hashCondition("LOGIC ERROR DETECTED: bad stacking");
    const h3 = hashCondition("logic  error   detected:  bad  stacking");
    assert.equal(h1, h2, "case should not matter");
    assert.equal(h1, h3, "whitespace normalization should produce same hash");
  });

  it("produces different hash for different conditions", () => {
    const h1 = hashCondition("logic error detected: bad stacking");
    const h2 = hashCondition("runtime error in execution: null pointer");
    assert.notEqual(h1, h2);
  });

  it("returns an 8-character hex string", () => {
    const h = hashCondition("some condition text");
    assert.equal(h.length, 8);
    assert.match(h, /^[0-9a-f]{8}$/);
  });
});
