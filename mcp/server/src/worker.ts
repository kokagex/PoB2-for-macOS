import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { createInterface, type Interface } from "node:readline";

export interface Topline {
  FullDPS: number;
  TotalDPS: number;
  CombinedDPS: number;
  AverageDamage: number;
  BleedDPS: number;
  IgniteDPS: number;
  PoisonDPS: number;
  CritChance: number;
  Speed: number;
}

export interface Patch {
  config?: Record<string, unknown>;
  enemyLevel?: number;
  treeURL?: string;
}

export interface CalcRequest {
  op?: "calc" | "breakdown" | "export";
  buildXml: string;
  patch?: Patch;
}

// Spawns the persistent luajit worker (boots PoB once) and serializes requests
// over its stdin/stdout JSON-line protocol. One in-flight request at a time.
export class Worker {
  private proc: ChildProcessWithoutNullStreams;
  private rl: Interface;
  private queue: Array<(line: string) => void> = [];
  private ready: Promise<void>;

  constructor(repoRoot: string) {
    this.proc = spawn(`${repoRoot}mcp/worker/run.sh`, [], {
      env: { ...process.env },
    });
    this.proc.on("error", (err) => {
      const reject = this.queue.shift();
      if (reject) reject(JSON.stringify({ ok: false, error: String(err) }));
    });
    this.rl = createInterface({ input: this.proc.stdout });
    let signalReady!: () => void;
    this.ready = new Promise((r) => (signalReady = r));
    this.rl.on("line", (line) => {
      let obj: { ready?: boolean };
      try {
        obj = JSON.parse(line);
      } catch {
        return; // ignore any stray non-protocol line
      }
      if (obj.ready) {
        signalReady();
        return;
      }
      const resolve = this.queue.shift();
      if (resolve) resolve(line);
    });
  }

  // Generic single request/response. Returns the worker's `output` payload.
  async send(req: CalcRequest): Promise<unknown> {
    await this.ready;
    const line = await new Promise<string>((resolve) => {
      this.queue.push(resolve);
      this.proc.stdin.write(JSON.stringify(req) + "\n");
    });
    const obj = JSON.parse(line) as
      | { ok: true; output: unknown }
      | { ok: false; error: string };
    if (!obj.ok) throw new Error(`worker error: ${obj.error}`);
    return obj.output;
  }

  calc(req: CalcRequest): Promise<Topline> {
    return this.send({ ...req, op: "calc" }) as Promise<Topline>;
  }

  breakdown(req: CalcRequest): Promise<Record<string, number>> {
    return this.send({ ...req, op: "breakdown" }) as Promise<
      Record<string, number>
    >;
  }

  exportCode(req: CalcRequest): Promise<{ code: string }> {
    return this.send({ ...req, op: "export" }) as Promise<{ code: string }>;
  }

  dispose() {
    this.proc.kill();
  }
}
