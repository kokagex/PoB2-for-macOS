import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  detectPenalties,
  calculateConfidence,
  determineVerdict,
} from "./deduction-engine.js";
import { PENALTY_WEIGHTS, type Proposition } from "@logos-orbit/shared";

function prop(
  statement: string,
  source: Proposition["source"] = "observed"
): Proposition {
  return { statement, source, timestamp: new Date().toISOString() };
}

describe("detectPenalties", () => {
  it("returns no penalties for a valid deduction", () => {
    const premises = [
      prop("All servers have logs"),
      prop("Server A is a server"),
    ];
    const conclusion = prop("Server A has logs", "derived");
    const penalties = detectPenalties(premises, conclusion, []);
    assert.equal(penalties.length, 0);
  });

  it("detects contradictory premises", () => {
    const premises = [
      prop("server is running"),
      prop("server is not running"),
    ];
    const conclusion = prop("server needs restart", "derived");
    const penalties = detectPenalties(premises, conclusion, []);
    const found = penalties.find((p) => p.type === "CONTRADICTORY_PREMISES");
    assert.ok(found, "should detect CONTRADICTORY_PREMISES");
    assert.equal(found.weight, PENALTY_WEIGHTS.CONTRADICTORY_PREMISES);
  });

  it("detects concept leap", () => {
    const premises = [
      prop("the database query is slow"),
      prop("the database index is missing"),
    ];
    const conclusion = prop(
      "we should rewrite the entire Rust frontend framework",
      "derived"
    );
    const penalties = detectPenalties(premises, conclusion, []);
    const found = penalties.find((p) => p.type === "CONCEPT_LEAP");
    assert.ok(found, "should detect CONCEPT_LEAP");
  });

  it("detects circular reasoning", () => {
    const premises = [
      prop("X is true because X is true"),
    ];
    const conclusion = prop("X is true", "derived");
    const penalties = detectPenalties(premises, conclusion, []);
    const found = penalties.find((p) => p.type === "CIRCULAR_REASONING");
    assert.ok(found, "should detect CIRCULAR_REASONING");
  });

  it("detects ungrounded assumption", () => {
    const premises = [
      prop("the system is stable", "assumed"),
      prop("the deployment succeeded", "assumed"),
      prop("no errors in logs", "assumed"),
    ];
    const conclusion = prop("system is production ready", "derived");
    const penalties = detectPenalties(premises, conclusion, []);
    const found = penalties.find((p) => p.type === "UNGROUNDED_ASSUMPTION");
    assert.ok(found, "should detect UNGROUNDED_ASSUMPTION");
  });

  it("detects temporal contradiction", () => {
    const priorConclusions = [prop("bug is not resolved", "derived")];
    const premises = [prop("tests pass now")];
    const conclusion = prop("bug is resolved", "derived");
    const penalties = detectPenalties(premises, conclusion, priorConclusions);
    const found = penalties.find((p) => p.type === "TEMPORAL_CONTRADICTION");
    assert.ok(found, "should detect TEMPORAL_CONTRADICTION");
  });
});

describe("calculateConfidence", () => {
  it("returns 1.0 for no penalties", () => {
    assert.equal(calculateConfidence([]), 1.0);
  });

  it("uses fixed weights from PENALTY_WEIGHTS", () => {
    const penalties = [
      {
        type: "CONTRADICTORY_PREMISES" as const,
        weight: PENALTY_WEIGHTS.CONTRADICTORY_PREMISES,
        description: "test",
        timestamp: new Date().toISOString(),
      },
    ];
    assert.equal(
      calculateConfidence(penalties),
      1.0 - PENALTY_WEIGHTS.CONTRADICTORY_PREMISES
    );
  });

  it("never goes below 0", () => {
    const penalties = [
      {
        type: "CONTRADICTORY_PREMISES" as const,
        weight: 0.5,
        description: "a",
        timestamp: new Date().toISOString(),
      },
      {
        type: "CONCEPT_LEAP" as const,
        weight: 0.2,
        description: "b",
        timestamp: new Date().toISOString(),
      },
      {
        type: "UNSUPPORTED_CONCLUSION" as const,
        weight: 0.3,
        description: "c",
        timestamp: new Date().toISOString(),
      },
      {
        type: "UNGROUNDED_ASSUMPTION" as const,
        weight: 0.1,
        description: "d",
        timestamp: new Date().toISOString(),
      },
    ];
    assert.equal(calculateConfidence(penalties), 0);
  });
});

describe("determineVerdict", () => {
  it("returns PASS for confidence >= 0.7", () => {
    assert.equal(determineVerdict(0.7), "PASS");
    assert.equal(determineVerdict(1.0), "PASS");
  });

  it("returns WARN for confidence 0.4-0.69", () => {
    assert.equal(determineVerdict(0.4), "WARN");
    assert.equal(determineVerdict(0.69), "WARN");
  });

  it("returns FAIL for confidence < 0.4", () => {
    assert.equal(determineVerdict(0.39), "FAIL");
    assert.equal(determineVerdict(0), "FAIL");
  });
});

describe("PENALTY_WEIGHTS", () => {
  it("CONTRADICTORY_PREMISES weight is 0.50", () => {
    assert.equal(PENALTY_WEIGHTS.CONTRADICTORY_PREMISES, 0.5);
  });
});
