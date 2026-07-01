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

// Minion-build fixture (Chrono_RotA snapshot whose saved main group is the
// Navira / Water Djinn summon): player DPS is ~0 and the real damage lives in
// the minion sub-table. Snapshotted into fixtures/ for the same reason as the
// player golden — a live PoB build can be saved over and invalidate the number.
const minionBuildXml = readFileSync(
  `${repoRoot}mcp/server/test/fixtures/golden_minion_build.xml`,
  "utf8",
);
const MINION_COMBINED_DPS = 151802.31538745; // headless-measured baseline (Navira)

// Top-tier minion fixture (Varashta/Navira, two Time-Lost Sapphires): third
// oracle covering jewel conversion + minion crit, the paths a data sync moves
// first. The golden value lives in GOLDEN.md next to the other baselines.
const toptierBuildXml = readFileSync(
  `${repoRoot}mcp/server/test/fixtures/golden_toptier_build.xml`,
  "utf8",
);
const TOPTIER_EFFECTIVE_DPS = parseFloat(
  /toptier EffectiveDPS:\s*([\d.]+)/.exec(golden)![1],
);

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

describe("minion DPS surfacing", () => {
  // The fix: the worker used to read only player mainOutput, so a minion build
  // (player CombinedDPS ~0) reported ~0 DPS. It must now surface the minion
  // sub-table. EffectiveDPS = player CombinedDPS + minion CombinedDPS.
  it(
    "surfaces the minion's DPS for a minion build (player DPS is ~0)",
    async () => {
      const out = await worker.calc({ buildXml: minionBuildXml });
      // player-side hit DPS is ~0 on this summon build
      expect(out.CombinedDPS).toBe(0);
      // the real damage shows up under the Minion* keys
      expect(out.MinionCombinedDPS).toBeGreaterThan(0);
      expect(
        Math.abs(out.MinionCombinedDPS - MINION_COMBINED_DPS) /
          MINION_COMBINED_DPS,
      ).toBeLessThan(0.01);
      // EffectiveDPS folds player + minion, so it leads with the minion number
      expect(out.EffectiveDPS).toBeCloseTo(out.MinionCombinedDPS, 6);
      expect(out.MinionCritMultiplier).toBeGreaterThan(0);
    },
    60_000,
  );

  // Non-breaking guard for player builds: with no minion, every Minion* key is
  // 0 and EffectiveDPS collapses to the player CombinedDPS (no double counting).
  it(
    "leaves a pure-player build unchanged (EffectiveDPS == CombinedDPS, no minion)",
    async () => {
      const out = await worker.calc({ buildXml });
      expect(out.MinionCombinedDPS).toBe(0);
      expect(out.EffectiveDPS).toBeCloseTo(out.CombinedDPS, 6);
    },
    60_000,
  );
});

describe("toptier minion golden", () => {
  it(
    "reproduces the top-tier build's EffectiveDPS within 1%",
    async () => {
      const out = await worker.calc({ buildXml: toptierBuildXml });
      expect(out.EffectiveDPS).toBeGreaterThan(0);
      expect(
        Math.abs(out.EffectiveDPS - TOPTIER_EFFECTIVE_DPS) /
          TOPTIER_EFFECTIVE_DPS,
      ).toBeLessThan(0.01);
    },
    60_000,
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
