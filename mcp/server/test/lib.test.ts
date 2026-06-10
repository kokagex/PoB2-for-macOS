import { describe, it, expect } from "vitest";
import { z } from "zod";
import { diffTopline, resolveXml, compareInputShape } from "../src/lib.js";

describe("diffTopline", () => {
  it("computes delta and pct per metric", () => {
    const cmp = diffTopline({ TotalDPS: 100 }, { TotalDPS: 150 });
    expect(cmp.TotalDPS).toEqual({ a: 100, b: 150, delta: 50, pct: 50 });
  });

  it("includes keys present in only one side instead of dropping them", () => {
    const cmp = diffTopline({ OnlyA: 1 }, { OnlyB: 2 });
    expect(cmp.OnlyA).toEqual({ a: 1, b: null, delta: null, pct: null });
    expect(cmp.OnlyB).toEqual({ a: null, b: 2, delta: null, pct: null });
  });

  it("pct is null when the baseline is 0", () => {
    const cmp = diffTopline({ CritChance: 0 }, { CritChance: 5 });
    expect(cmp.CritChance.delta).toBe(5);
    expect(cmp.CritChance.pct).toBeNull();
  });
});

describe("resolveXml", () => {
  it("returns buildXml verbatim when given", () => {
    expect(resolveXml(undefined, "<Build/>")).toBe("<Build/>");
  });

  it("throws a readable error naming the path when the file is unreadable", () => {
    expect(() => resolveXml("/no/such/build.xml")).toThrow(/\/no\/such\/build\.xml/);
    expect(() => resolveXml("/no/such/build.xml")).toThrow(/absolute path/);
  });

  it("throws when neither buildPath nor buildXml is given", () => {
    expect(() => resolveXml()).toThrow(/buildPath or buildXml/);
  });
});

describe("calc_compare input schema", () => {
  it("rejects a call without patchB (omitting it silently returned a zero diff)", () => {
    const schema = z.object(compareInputShape);
    expect(schema.safeParse({ buildXml: "<x/>" }).success).toBe(false);
    expect(
      schema.safeParse({ buildXml: "<x/>", patchB: { skillName: "Eye of Winter" } })
        .success,
    ).toBe(true);
  });
});
