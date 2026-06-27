import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { createInterface, type Interface } from "node:readline";

// type alias (not interface) so it satisfies Record<string, number> structurally.
// Keys are always present (the worker defaults missing ones to 0), so they stay
// `number` (not `number | undefined`) and the Record<string, number> constraint
// diffTopline relies on still holds.
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
  // Minion/summon builds: the player keys above are ~0 and the real DPS lives
  // here (mirrors PoB's <MinionStat>). EffectiveDPS = player CombinedDPS +
  // minion CombinedDPS (CalcsTab.lua:693) — the headline number for either
  // build type. On a pure-player build every Minion* key is 0 and
  // EffectiveDPS == CombinedDPS.
  EffectiveDPS: number;
  MinionCombinedDPS: number;
  MinionTotalDPS: number;
  MinionAverageDamage: number;
  MinionSpeed: number;
  MinionCritChance: number;
  MinionCritMultiplier: number;
};

export interface ItemPatch {
  slot: string;
  raw: string;
}

export interface GemPatch {
  name: string;
  group?: number | string;
  level?: number;
  quality?: number;
  enabled?: boolean;
  remove?: boolean;
}

export interface Patch {
  config?: Record<string, unknown>;
  enemyLevel?: number;
  treeURL?: string;
  skillName?: string;
  items?: ItemPatch[];
  gems?: GemPatch[];
  allocNodes?: (string | number)[];
  deallocNodes?: (string | number)[];
}

export interface CalcRequest {
  op?: "calc" | "breakdown" | "export" | "info";
  buildXml: string;
  patch?: Patch;
}

// Build-independent game-data lookups served by worker/query.lua.
export type QueryOp =
  | "data_gems"
  | "data_uniques"
  | "data_passives"
  | "data_itembases";

export interface QueryRequest {
  op: QueryOp;
  args?: Record<string, unknown>;
}

interface Pending {
  resolve: (line: string) => void;
  reject: (err: Error) => void;
}

// Spawns the persistent luajit worker (boots PoB once) and serializes requests
// over its stdin/stdout JSON-line protocol. If the worker dies unexpectedly
// (e.g. an external `pkill`), the next send() lazily respawns it; only
// dispose() shuts it down for good.
export class Worker {
  private proc!: ChildProcessWithoutNullStreams;
  private rl!: Interface;
  private queue: Pending[] = [];
  private ready!: Promise<void>;
  // True while a worker process is booting or live. Flipped to false on an
  // unexpected exit so the next send() respawns a fresh process.
  private alive = false;
  private disposed = false;

  constructor(private readonly repoRoot: string) {
    this.spawn();
  }

  // (Re)spawn the worker process and wire up its ready handshake, line
  // protocol and exit handling. Resets the per-process queue and stderr tail.
  private spawn() {
    this.queue = [];
    this.alive = true;
    const stderrTail: string[] = [];

    const proc = spawn(`${this.repoRoot}mcp/worker/run.sh`, [], {
      env: { ...process.env },
    });
    this.proc = proc;

    let signalReady!: () => void;
    let failReady!: (err: Error) => void;
    this.ready = new Promise<void>((resolve, reject) => {
      signalReady = resolve;
      failReady = reject;
    });
    // Observe the rejection here so an unawaited ready never becomes an
    // unhandled rejection; send() still surfaces it by awaiting ready.
    this.ready.catch(() => {});

    // Keep the tail of stderr so a boot failure is diagnosable.
    proc.stderr.on("data", (chunk: Buffer) => {
      stderrTail.push(
        ...chunk.toString().split("\n").filter((l) => l.trim() !== ""),
      );
      if (stderrTail.length > 20) {
        stderrTail.splice(0, stderrTail.length - 20);
      }
    });

    // Tear down this process: reject ready and everything in flight. Ignored
    // if a newer process has already replaced this one (stale late event).
    const fail = (cause: string) => {
      if (this.proc !== proc) return;
      this.alive = false;
      const tail = stderrTail.length
        ? `\nworker stderr:\n${stderrTail.join("\n")}`
        : "";
      const err = new Error(`${cause}${tail}`);
      failReady(err);
      for (const { reject } of this.queue.splice(0)) reject(err);
    };
    proc.on("error", (err) => fail(`worker spawn failed: ${err}`));
    // An exit we did not request via dispose() is treated as transient: reject
    // ready + in-flight and mark not-alive so the next send() respawns. A
    // dispose()-driven exit is final and left alone.
    proc.on("close", (code, signal) => {
      if (this.disposed) return;
      fail(`worker exited (code ${code ?? signal})`);
    });
    // A write after the worker died raises EPIPE; the send() write callback and
    // close handler already reject the affected requests, so don't crash here.
    proc.stdin.on("error", () => {});

    this.rl = createInterface({ input: proc.stdout });
    this.rl.on("line", (line) => {
      if (this.proc !== proc) return; // ignore lines from a replaced process
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
  // Lazily respawns the worker if a previous one exited unexpectedly.
  async send(req: CalcRequest | QueryRequest): Promise<unknown> {
    if (this.disposed) throw new Error("worker disposed");
    if (!this.alive) this.spawn();
    await this.ready;
    const line = await new Promise<string>((resolve, reject) => {
      const pending: Pending = { resolve, reject };
      this.queue.push(pending);
      this.proc.stdin.write(JSON.stringify(req) + "\n", (err) => {
        if (!err) return;
        // The pipe was already gone (worker died between ready and write).
        // Drop this request and reject; the close handler flips alive=false so
        // the next send() respawns a fresh worker.
        const i = this.queue.indexOf(pending);
        if (i !== -1) this.queue.splice(i, 1);
        reject(err);
      });
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

  info(req: CalcRequest): Promise<Record<string, unknown>> {
    return this.send({ ...req, op: "info" }) as Promise<
      Record<string, unknown>
    >;
  }

  query(op: QueryOp, args?: Record<string, unknown>): Promise<unknown> {
    return this.send({ op, args });
  }

  dispose() {
    this.disposed = true;
    this.proc.kill();
  }
}
