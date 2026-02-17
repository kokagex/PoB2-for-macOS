import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  calculateEntropy,
  detectStutter,
} from "./entropy.js";
import type { ActionRecord } from "@logos-orbit/shared";
import { randomUUID } from "node:crypto";

const ACTION_TYPES = ["search", "edit", "read", "write", "verify", "plan", "ask"] as const;

function makeAction(
  actionType: ActionRecord["actionType"],
  intent = "some intent that is long enough",
  target = "some/file.ts"
): ActionRecord {
  return {
    id: `act_${randomUUID().slice(0, 8)}`,
    actionType,
    target,
    intent,
    rationale: "rationale that is long enough",
    timestamp: new Date().toISOString(),
  };
}

describe("calculateEntropy", () => {
  it("returns 0 for empty array", () => {
    assert.equal(calculateEntropy([]), 0);
  });

  it("returns 0 for single action type", () => {
    const actions = Array.from({ length: 10 }, () => makeAction("edit"));
    assert.equal(calculateEntropy(actions), 0);
  });

  it("returns high (>0.9) for uniform distribution of all 7 types", () => {
    const actions: ActionRecord[] = [];
    for (const type of ACTION_TYPES) {
      for (let i = 0; i < 5; i++) {
        actions.push(makeAction(type));
      }
    }
    const entropy = calculateEntropy(actions);
    assert.ok(
      entropy > 0.9,
      `Expected entropy > 0.9 for uniform distribution, got ${entropy}`
    );
  });

  it("returns moderate value for skewed distribution", () => {
    const actions: ActionRecord[] = [
      ...Array.from({ length: 8 }, () => makeAction("edit")),
      ...Array.from({ length: 1 }, () => makeAction("read")),
      ...Array.from({ length: 1 }, () => makeAction("search")),
    ];
    const entropy = calculateEntropy(actions);
    assert.ok(entropy > 0.2, `Expected entropy > 0.2, got ${entropy}`);
    assert.ok(entropy < 0.9, `Expected entropy < 0.9, got ${entropy}`);
  });
});

describe("detectStutter", () => {
  it("detects 3/5 repeated intent+target", () => {
    const repeatedIntent = "searching for the same thing";
    const repeatedTarget = "src/lib/target.ts";
    const actions: ActionRecord[] = [
      makeAction("search", repeatedIntent, repeatedTarget),
      makeAction("edit", "editing something different", "other.ts"),
      makeAction("search", repeatedIntent, repeatedTarget),
      makeAction("read", "reading something else entirely", "readme.md"),
      makeAction("search", repeatedIntent, repeatedTarget),
    ];
    const result = detectStutter(actions);
    assert.equal(result.detected, true);
    assert.ok(result.pattern !== null);
    assert.equal(result.pattern.intent, repeatedIntent);
    assert.equal(result.pattern.target, repeatedTarget);
    assert.equal(result.pattern.count, 3);
  });

  it("does not trigger for diverse actions", () => {
    const actions: ActionRecord[] = [
      makeAction("search", "searching for something specific", "a.ts"),
      makeAction("edit", "editing a different file now", "b.ts"),
      makeAction("read", "reading documentation for context", "c.ts"),
      makeAction("write", "writing a new test file out", "d.ts"),
      makeAction("verify", "verifying the output is correct", "e.ts"),
    ];
    const result = detectStutter(actions);
    assert.equal(result.detected, false);
    assert.equal(result.pattern, null);
  });

  it("respects custom window size and threshold", () => {
    const actions: ActionRecord[] = Array.from({ length: 10 }, () =>
      makeAction("edit", "editing the same thing again", "target.ts")
    );
    const result = detectStutter(actions, 10, 5);
    assert.equal(result.detected, true);
    assert.ok(result.pattern !== null);
    assert.equal(result.pattern.count, 10);
  });
});
