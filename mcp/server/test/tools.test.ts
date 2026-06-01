import { describe, it, expect, afterAll } from "vitest";
import { Worker } from "../src/worker.js";
import { readFileSync } from "node:fs";

const repoRoot = new URL("../../../", import.meta.url).pathname;
const golden = readFileSync(`${repoRoot}mcp/spike/GOLDEN.md`, "utf8");
const buildPath = /build file: (.+)/.exec(golden)![1].trim();
const buildXml = readFileSync(buildPath, "utf8");

const worker = new Worker(repoRoot);
afterAll(() => worker.dispose());

describe("Slice 2 worker ops", () => {
  it("breakdown returns crit/speed/per-type keys", async () => {
    const b = await worker.breakdown({ buildXml });
    expect(b.TotalDPS).toBeGreaterThan(0);
    expect(b.CritMultiplier).toBeGreaterThan(0);
    expect(b.ColdHitAverage).toBeGreaterThan(0); // Lich build deals cold damage
  }, 60_000);

  it("a config patch moves TotalDPS (compare-style delta)", async () => {
    const base = await worker.calc({ buildXml });
    const patched = await worker.calc({
      buildXml,
      patch: { config: { buffAdrenaline: true } },
    });
    expect(patched.TotalDPS).toBeGreaterThan(base.TotalDPS * 1.1);
  }, 60_000);

  it("export_build returns a PoB import code (zlib 'eNr' prefix)", async () => {
    const { code } = await worker.exportCode({ buildXml });
    expect(code.length).toBeGreaterThan(100);
    expect(code.startsWith("eNr")).toBe(true);
  }, 60_000);
});
