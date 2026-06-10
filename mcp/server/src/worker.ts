import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { createInterface, type Interface } from "node:readline";

// type alias (not interface) so it satisfies Record<string, number> structurally
export type Topline = {
  FullDPS: number;
  TotalDPS: number;
  CombinedDPS: number;
  AverageDamage: number;
  BleedDPS: number;
  IgniteDPS: number;
  PoisonDPS: number;
  CritChance: number;
  Speed: number;
};

export interface Patch {
  config?: Record<string, unknown>;
  enemyLevel?: number;
  treeURL?: string;
  skillName?: string;
}

export interface CalcRequest {
  op?: "calc" | "breakdown" | "export";
  buildXml: string;
  patch?: Patch;
}

interface Pending {
  resolve: (line: string) => void;
  reject: (err: Error) => void;
}

// Spawns the persistent luajit worker (boots PoB once) and serializes requests
// over its stdin/stdout JSON-line protocol. One in-flight request at a time.
export class Worker {
  private proc: ChildProcessWithoutNullStreams;
  private rl: Interface;
  private queue: Pending[] = [];
  private ready: Promise<void>;
  private stderrTail: string[] = [];
  private died: Error | null = null;
  private disposed = false;

  constructor(repoRoot: string) {
    this.proc = spawn(`${repoRoot}mcp/worker/run.sh`, [], {
      env: { ...process.env },
    });

    let signalReady!: () => void;
    let failReady!: (err: Error) => void;
    this.ready = new Promise<void>((resolve, reject) => {
      signalReady = resolve;
      failReady = reject;
    });
    // Observe the rejection here so an unawaited ready never becomes an
    // unhandled rejection; send() still sees it via the `died` check.
    this.ready.catch(() => {});

    // Keep the tail of stderr so a boot failure is diagnosable.
    this.proc.stderr.on("data", (chunk: Buffer) => {
      this.stderrTail.push(
        ...chunk.toString().split("\n").filter((l) => l.trim() !== ""),
      );
      if (this.stderrTail.length > 20) {
        this.stderrTail.splice(0, this.stderrTail.length - 20);
      }
    });

    const fail = (cause: string) => {
      const tail = this.stderrTail.length
        ? `\nworker stderr:\n${this.stderrTail.join("\n")}`
        : "";
      this.died = new Error(`${cause}${tail}`);
      failReady(this.died);
      for (const { reject } of this.queue.splice(0)) reject(this.died);
    };
    this.proc.on("error", (err) => fail(`worker spawn failed: ${err}`));
    // The worker is persistent: any exit before dispose() is fatal, so reject
    // ready and everything in flight instead of leaving callers hanging.
    this.proc.on("close", (code, signal) => {
      if (!this.disposed) fail(`worker exited (code ${code ?? signal})`);
    });
    // A write after the worker died raises EPIPE; the close handler already
    // rejects the in-flight request, so just keep it from crashing the server.
    this.proc.stdin.on("error", () => {});

    this.rl = createInterface({ input: this.proc.stdout });
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
      this.queue.shift()?.resolve(line);
    });
  }

  // Generic single request/response. Returns the worker's `output` payload.
  async send(req: CalcRequest): Promise<unknown> {
    await this.ready;
    if (this.died) throw this.died;
    const line = await new Promise<string>((resolve, reject) => {
      this.queue.push({ resolve, reject });
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
    this.disposed = true;
    this.proc.kill();
  }
}
