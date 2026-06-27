import { describe, it, expect } from "vitest";
import { once } from "node:events";
import type { ChildProcess } from "node:child_process";
import { Worker } from "../src/worker.js";

// repoRoot = three levels up (mcp/server/test -> repo root), matching index.ts.
const repoRoot = new URL("../../../", import.meta.url).pathname;

// Reach the (private) child process so the test can simulate an external kill
// of *this* worker only — never `pkill`, which would also kill a running MCP
// server's worker.
const childOf = (w: Worker) =>
  (w as unknown as { proc: ChildProcess }).proc;

describe("worker respawn after unexpected death", () => {
  it(
    "respawns a fresh worker when the previous one is killed externally",
    async () => {
      const w = new Worker(repoRoot);

      // Warm up: boot the worker and capture its process id.
      const first = (await w.query("data_gems", {
        gemType: "support",
        limit: 1,
      })) as { returned: number };
      expect(first.returned).toBe(1);

      const proc1 = childOf(w);
      const pid1 = proc1.pid;

      // Simulate `pkill -f mcp/worker/server.lua` for this worker only.
      proc1.kill("SIGKILL");
      await once(proc1, "close");

      // The next request must transparently respawn a new worker and answer
      // instead of throwing the cached exit error forever.
      const second = (await w.query("data_gems", {
        gemType: "support",
        limit: 1,
      })) as { returned: number };
      expect(second.returned).toBe(1);

      const pid2 = childOf(w).pid;
      expect(pid2).not.toBe(pid1);

      w.dispose();
    },
    120_000,
  );
});
