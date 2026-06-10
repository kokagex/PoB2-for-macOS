import { describe, it, expect } from "vitest";
import { Worker } from "../src/worker.js";

// A repoRoot whose mcp/worker/run.sh prints to stderr and exits 1 immediately.
const failRoot = new URL("./fixtures/fail-root/", import.meta.url).pathname;

describe("worker startup failure", () => {
  it(
    "rejects send() instead of hanging when the worker exits at boot",
    async () => {
      const w = new Worker(failRoot);
      await expect(w.send({ buildXml: "<x/>" })).rejects.toThrow(
        /worker exited/,
      );
      w.dispose();
    },
    5_000,
  );

  it(
    "includes the worker's stderr in the failure for diagnosis",
    async () => {
      const w = new Worker(failRoot);
      await expect(w.send({ buildXml: "<x/>" })).rejects.toThrow(
        /luarocks: command not found/,
      );
      w.dispose();
    },
    5_000,
  );
});
