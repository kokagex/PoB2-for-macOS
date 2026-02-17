import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { VerifyReasoningSchema } from "./verify_reasoning.js";

const now = new Date().toISOString();

function validInput() {
  return {
    premises: [
      {
        statement: "All cats are animals",
        source: "observed",
        timestamp: now,
      },
    ],
    conclusion: {
      statement: "My cat is an animal",
      source: "derived",
      timestamp: now,
    },
    context: "testing deduction",
  };
}

describe("VerifyReasoningSchema", () => {
  it("accepts valid input", () => {
    const result = VerifyReasoningSchema.safeParse(validInput());
    assert.ok(result.success, "should accept valid input");
  });

  it("accepts input with derivationSteps", () => {
    const input = {
      ...validInput(),
      derivationSteps: [
        { from: ["premise-1"], to: "conclusion", rule: "modus ponens" },
      ],
    };
    const result = VerifyReasoningSchema.safeParse(input);
    assert.ok(result.success, "should accept input with derivationSteps");
  });

  it("rejects empty premises (C-I3)", () => {
    const input = { ...validInput(), premises: [] };
    const result = VerifyReasoningSchema.safeParse(input);
    assert.ok(!result.success, "should reject empty premises");
  });

  it("rejects self-reflection fields in premises (.strict())", () => {
    const input = {
      ...validInput(),
      premises: [
        {
          statement: "test",
          source: "observed",
          timestamp: now,
          confidence: 0.9, // self-reflection field, should be rejected
        },
      ],
    };
    const result = VerifyReasoningSchema.safeParse(input);
    assert.ok(!result.success, "should reject extra fields on premises");
  });

  it("rejects extra fields on the top level (.strict())", () => {
    const input = {
      ...validInput(),
      selfAssessment: "I am very confident", // not allowed
    };
    const result = VerifyReasoningSchema.safeParse(input);
    assert.ok(!result.success, "should reject extra top-level fields");
  });

  it("rejects empty context", () => {
    const input = { ...validInput(), context: "" };
    const result = VerifyReasoningSchema.safeParse(input);
    assert.ok(!result.success, "should reject empty context");
  });
});
