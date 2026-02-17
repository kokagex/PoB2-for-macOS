import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { estimateTokens } from "./token-counter.js";

describe("estimateTokens", () => {
  it("counts ASCII text as chars/4", () => {
    // 100 ASCII chars ≈ 25 tokens
    const text = "a".repeat(100);
    assert.ok(estimateTokens(text) >= 20 && estimateTokens(text) <= 30);
  });

  it("counts CJK text as chars/1.5", () => {
    // 100 CJK chars ≈ 67 tokens
    const text = "あ".repeat(100);
    assert.ok(estimateTokens(text) >= 55 && estimateTokens(text) <= 80);
  });

  it("returns 0 for empty string", () => {
    assert.equal(estimateTokens(""), 0);
  });
});
