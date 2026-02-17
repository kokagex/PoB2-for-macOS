import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { VerifyCodeSchema } from "./verify_code.js";

describe("VerifyCodeSchema", () => {
  it("accepts valid input", () => {
    const result = VerifyCodeSchema.safeParse({
      filePath: "/src/index.ts",
      claimedBehavior: "adds error handling to the main function",
      changedLines: [{ from: 10, to: 20 }],
    });
    assert.ok(result.success, "should accept valid input");
  });

  it("accepts multiple changedLines ranges", () => {
    const result = VerifyCodeSchema.safeParse({
      filePath: "/src/index.ts",
      claimedBehavior: "refactors two functions",
      changedLines: [
        { from: 1, to: 5 },
        { from: 20, to: 30 },
      ],
    });
    assert.ok(result.success, "should accept multiple ranges");
  });

  it("rejects empty claimedBehavior", () => {
    const result = VerifyCodeSchema.safeParse({
      filePath: "/src/index.ts",
      claimedBehavior: "",
      changedLines: [{ from: 10, to: 20 }],
    });
    assert.ok(!result.success, "should reject empty claimedBehavior");
  });

  it("rejects changedLines where from > to", () => {
    const result = VerifyCodeSchema.safeParse({
      filePath: "/src/index.ts",
      claimedBehavior: "fixes a bug",
      changedLines: [{ from: 20, to: 10 }],
    });
    assert.ok(!result.success, "should reject from > to");
  });

  it("rejects empty changedLines array", () => {
    const result = VerifyCodeSchema.safeParse({
      filePath: "/src/index.ts",
      claimedBehavior: "fixes a bug",
      changedLines: [],
    });
    assert.ok(!result.success, "should reject empty changedLines");
  });

  it("rejects empty filePath", () => {
    const result = VerifyCodeSchema.safeParse({
      filePath: "",
      claimedBehavior: "fixes a bug",
      changedLines: [{ from: 1, to: 5 }],
    });
    assert.ok(!result.success, "should reject empty filePath");
  });

  it("rejects extra fields (.strict())", () => {
    const result = VerifyCodeSchema.safeParse({
      filePath: "/src/index.ts",
      claimedBehavior: "fixes a bug",
      changedLines: [{ from: 1, to: 5 }],
      confidence: 0.9,
    });
    assert.ok(!result.success, "should reject extra fields");
  });
});
