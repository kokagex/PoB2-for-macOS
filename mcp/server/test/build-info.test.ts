import { describe, it, expect, afterAll } from "vitest";
import { Worker } from "../src/worker.js";
import { readFileSync } from "node:fs";

// repo root = two levels up from mcp/server/
const repoRoot = new URL("../../../", import.meta.url).pathname;

// Top-tier reference build (the user's "sample" ideal: Disciple of Varashta /
// Navira summon, ~1.3M minion DPS). Snapshotted into fixtures/ so the radius
// surface has a Time-Lost Sapphire build to assert against without depending on
// a live PoB build file (which the GUI can overwrite -- see GOLDEN.md).
const toptierXml = readFileSync(
  `${repoRoot}mcp/server/test/fixtures/golden_toptier_build.xml`,
  "utf8",
);
// Current build snapshot (plain Sapphire jewels, no radius conversion).
const currentXml = readFileSync(
  `${repoRoot}mcp/server/test/fixtures/golden_minion_build.xml`,
  "utf8",
);

const worker = new Worker(repoRoot);
afterAll(() => worker.dispose());

type JewelSocket = {
  socket: number;
  slot: string;
  jewel: string;
  base: string;
  radius?: string;
  notableCount: number;
  totalAllocInRadius: number;
  totalInRadius: number;
  notables: string[];
};
type ItemInfo = {
  slot: string;
  name: string;
  mods: { kind: string; text: string }[];
};
type BuildInfo = {
  items: ItemInfo[];
  spectres: string[];
  passives: { jewelSockets: JewelSocket[] };
};

describe("build_info: jewel-socket radius surface", () => {
  // THE structural fix: a radius jewel (Time-Lost Sapphire) grants its
  // "Notable Passive Skills in Radius also grant ..." mods to every ALLOCATED
  // notable in its radius, so notableCount (allocated-only) is the multiplier.
  // The engine's nodesInRadius is geometric (all nodes physically in range), so
  // it MUST be allocation-filtered -- otherwise two trees with the same socket
  // geometry report the same count and the tree's role stays invisible (the
  // exact lever that was missed: same jewels + current tree drops minion DPS
  // -26.5%). notableCount (allocated) must be strictly below the geometric
  // totalInRadius, proving the filter is live.
  it(
    "surfaces the ALLOCATED notables in each Time-Lost socket's radius (top-tier build)",
    async () => {
      const info = (await worker.info({
        buildXml: toptierXml,
      })) as unknown as BuildInfo;
      const sockets = info.passives.jewelSockets;
      expect(Array.isArray(sockets)).toBe(true);

      const timeLost = sockets.filter((s) => s.base === "Time-Lost Sapphire");
      // sample has two Time-Lost Sapphires (Brood Creed + Eagle Vessel)
      expect(timeLost.length).toBe(2);
      for (const s of timeLost) {
        expect(s.radius).toBe("Very Large");
        expect(s.notableCount).toBeGreaterThan(0);
        expect(s.notables.length).toBe(s.notableCount);
        // allocation filter is live: allocated nodes << geometric nodes in
        // radius. If the filter regressed to geometric this would be ~equal.
        expect(s.totalAllocInRadius).toBeLessThan(s.totalInRadius);
        expect(s.notableCount).toBeLessThanOrEqual(s.totalAllocInRadius);
      }

      // Exact allocated-notable oracle for this fixture (the decisive guard
      // against reverting to a geometric count, which would jump to ~20 each).
      // Re-baseline on an upstream tree-data sync, like the DPS goldens.
      const bySocket = Object.fromEntries(timeLost.map((s) => [s.socket, s]));
      expect(bySocket[21984].notableCount).toBe(12);
      expect(bySocket[61419].notableCount).toBe(4);
    },
    60_000,
  );

  // The mirror assertion: the current build's plain Sapphires are NOT radius
  // jewels (radius null) and convert nothing (notableCount 0). This is exactly
  // what made the tree's role invisible before the surface existed.
  it(
    "shows plain Sapphire jewels convert nothing (current build, notableCount 0)",
    async () => {
      const info = (await worker.info({
        buildXml: currentXml,
      })) as unknown as BuildInfo;
      const sockets = info.passives.jewelSockets;
      const sapphires = sockets.filter((s) => s.base === "Sapphire");
      expect(sapphires.length).toBeGreaterThan(0);
      for (const s of sapphires) {
        // a non-radius jewel has no radius field (Lua nil -> JSON omits it)
        expect(s.radius).toBeUndefined();
        expect(s.notableCount).toBe(0);
      }
    },
    60_000,
  );
});

describe("build_info: spectres surface (upstream v0.22.0)", () => {
  // Upstream v0.22.0 added spectre support; the chosen spectres live in
  // build.spectreList and are surfaced so advice on a spectre build can see
  // which spectres are in play. Neither golden fixture uses spectres, so the
  // guard here is shape-only: the key exists and is an empty list.
  it(
    "surfaces an empty spectre list on a non-spectre build",
    async () => {
      const info = (await worker.info({
        buildXml: toptierXml,
      })) as unknown as BuildInfo;
      expect(Array.isArray(info.spectres)).toBe(true);
      expect(info.spectres.length).toBe(0);
    },
    60_000,
  );
});

describe("build_info: per-item resolved mods", () => {
  // Items now carry their resolved mod text (rolled values baked in on a normal
  // load), so advice can see WHAT each piece grants without re-parsing the XML
  // (the ModRange-stripping re-parse is what under-rolled jewels earlier).
  it(
    "lists each item's resolved mod lines",
    async () => {
      const info = (await worker.info({
        buildXml: toptierXml,
      })) as unknown as BuildInfo;
      const broodCreed = info.items.find((i) => i.name.includes("Brood Creed"));
      expect(broodCreed).toBeDefined();
      const texts = broodCreed!.mods.map((m) => m.text);
      // the core Time-Lost mod, with its rolled per-notable value, must be visible
      expect(
        texts.some((t) =>
          /Notable Passive Skills in Radius also grant Minions have \d+% increased Critical Damage Bonus/.test(
            t,
          ),
        ),
      ).toBe(true);
      // mods are tagged by kind (explicit/implicit/rune/enchant)
      expect(broodCreed!.mods.every((m) => typeof m.kind === "string")).toBe(
        true,
      );
    },
    60_000,
  );
});
