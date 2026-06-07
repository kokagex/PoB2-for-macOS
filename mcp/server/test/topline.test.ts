import { describe, it, expect, afterAll } from "vitest";
import { Worker } from "../src/worker.js";
import { readFileSync } from "node:fs";

// repo root = two levels up from mcp/server/
const repoRoot = new URL("../../../", import.meta.url).pathname;
const golden = readFileSync(`${repoRoot}mcp/spike/GOLDEN.md`, "utf8");
// build file is repo-relative: the golden XML is snapshotted into fixtures/ so
// the baseline can't be invalidated by the user saving over a live PoB build.
const buildPath = repoRoot + /build file: (.+)/.exec(golden)![1].trim();
const baseline = parseFloat(/TotalDPS:\s*([\d.]+)/.exec(golden)![1]);
const skillNameBaseline = parseFloat(
  /skillName "Eye of Winter" -> TotalDPS:\s*([\d.]+)/.exec(golden)![1],
);
const buildXml = readFileSync(buildPath, "utf8");

const worker = new Worker(repoRoot);

afterAll(() => worker.dispose());

describe("Worker.calc", () => {
  it(
    "returns TotalDPS within 1% of the recorded baseline",
    async () => {
      const out = await worker.calc({ buildXml });
      expect(out.TotalDPS).toBeGreaterThan(0);
      expect(Math.abs(out.TotalDPS - baseline) / baseline).toBeLessThan(0.01);
    },
    60_000, // first call boots the engine (slow)
  );
});

describe("patch.skillName", () => {
  // The golden build's saved main group is Orb of Storms; selecting Eye of
  // Winter by name must switch groups and reproduce the recorded value exactly
  // (it was cross-checked diff=0 against rewriting mainSocketGroup in the XML).
  it(
    "selecting a non-main skill by name (case-insensitive) switches the calc to it",
    async () => {
      const out = await worker.calc({
        buildXml,
        patch: { skillName: "eye of winter" },
      });
      expect(out.TotalDPS).toBeCloseTo(skillNameBaseline, 6);
    },
    60_000,
  );

  // Regression guard for the original bug: an unrecognised skillName must be a
  // hard error, never silently ignored (which would return the saved skill's
  // numbers and look plausible).
  it(
    "unknown skillName is a hard error listing the gems present",
    async () => {
      await expect(
        worker.calc({ buildXml, patch: { skillName: "NoSuchSkill" } }),
      ).rejects.toThrow(/skillName "NoSuchSkill" not found in build/);
    },
    60_000,
  );
});
