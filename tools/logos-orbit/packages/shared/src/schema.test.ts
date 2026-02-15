import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  PropositionSchema,
  PenaltySchema,
  PENALTY_WEIGHTS,
  LogosStatusSchema,
  createEmptyStatus,
} from "./schema.js";

describe("PropositionSchema", () => {
  const valid = {
    statement: "The sky is blue",
    source: "observed",
    timestamp: new Date().toISOString(),
  };

  it("accepts a valid proposition", () => {
    const result = PropositionSchema.safeParse(valid);
    assert.equal(result.success, true);
  });

  it("rejects an empty statement", () => {
    const result = PropositionSchema.safeParse({ ...valid, statement: "" });
    assert.equal(result.success, false);
  });

  it("rejects an invalid source", () => {
    const result = PropositionSchema.safeParse({
      ...valid,
      source: "hallucination",
    });
    assert.equal(result.success, false);
  });

  it("rejects confidence field (strict mode)", () => {
    const result = PropositionSchema.safeParse({
      ...valid,
      confidence: 0.9,
    });
    assert.equal(result.success, false);
  });

  it("rejects certainty field (strict mode)", () => {
    const result = PropositionSchema.safeParse({
      ...valid,
      certainty: "high",
    });
    assert.equal(result.success, false);
  });
});

describe("PenaltySchema", () => {
  it("accepts a valid penalty", () => {
    const result = PenaltySchema.safeParse({
      type: "CONTRADICTORY_PREMISES",
      weight: 0.5,
      description: "Two premises contradict each other",
      timestamp: new Date().toISOString(),
    });
    assert.equal(result.success, true);
  });

  it("rejects an unknown penalty type", () => {
    const result = PenaltySchema.safeParse({
      type: "MADE_UP_PENALTY",
      weight: 0.5,
      description: "Invalid",
      timestamp: new Date().toISOString(),
    });
    assert.equal(result.success, false);
  });
});

describe("PENALTY_WEIGHTS", () => {
  it("is frozen", () => {
    assert.equal(Object.isFrozen(PENALTY_WEIGHTS), true);
  });

  it("has correct values", () => {
    assert.equal(PENALTY_WEIGHTS.CONTRADICTORY_PREMISES, 0.5);
    assert.equal(PENALTY_WEIGHTS.UNSUPPORTED_CONCLUSION, 0.3);
    assert.equal(PENALTY_WEIGHTS.TEMPORAL_CONTRADICTION, 0.25);
    assert.equal(PENALTY_WEIGHTS.CONCEPT_LEAP, 0.2);
    assert.equal(PENALTY_WEIGHTS.CIRCULAR_REASONING, 0.15);
    assert.equal(PENALTY_WEIGHTS.UNGROUNDED_ASSUMPTION, 0.1);
  });
});

describe("LogosStatusSchema", () => {
  it("validates createEmptyStatus() output", () => {
    const status = createEmptyStatus();
    const result = LogosStatusSchema.safeParse(status);
    assert.equal(result.success, true);
  });
});
