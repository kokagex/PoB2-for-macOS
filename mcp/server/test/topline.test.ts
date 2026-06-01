import { describe, it, expect, afterAll } from "vitest";
import { Worker } from "../src/worker.js";
import { readFileSync } from "node:fs";

// repo root = two levels up from mcp/server/
const repoRoot = new URL("../../../", import.meta.url).pathname;
const golden = readFileSync(`${repoRoot}mcp/spike/GOLDEN.md`, "utf8");
const buildPath = /build file: (.+)/.exec(golden)![1].trim();
const baseline = parseFloat(/TotalDPS:\s*([\d.]+)/.exec(golden)![1]);
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
