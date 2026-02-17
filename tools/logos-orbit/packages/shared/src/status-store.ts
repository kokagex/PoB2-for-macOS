import { readFile, writeFile, mkdir, open, unlink } from "node:fs/promises";
import { join } from "node:path";
import { LogosStatusSchema, createEmptyStatus } from "./schema.js";
import type { LogosStatus } from "./schema.js";

type Owner = "integrity" | "chronos" | "nomos";

const LOCK_RETRIES = 3;
const LOCK_DELAY_MS = 100;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export class StatusStore {
  private statusPath: string;
  private lockPath: string;

  constructor(dataDir: string) {
    this.statusPath = join(dataDir, "status.json");
    this.lockPath = join(dataDir, ".status.lock");
  }

  /** Read status.json, creating an initial empty status if it does not exist. */
  async read(): Promise<LogosStatus> {
    try {
      const raw = await readFile(this.statusPath, "utf-8");
      return LogosStatusSchema.parse(JSON.parse(raw));
    } catch (err: unknown) {
      if (isNodeError(err) && err.code === "ENOENT") {
        const empty = createEmptyStatus();
        await mkdir(join(this.statusPath, ".."), { recursive: true });
        await writeFile(this.statusPath, JSON.stringify(empty, null, 2));
        return empty;
      }
      throw err;
    }
  }

  /**
   * Atomically update status.json with ownership enforcement.
   *
   * - `owner` can only modify its own section (integrity / chronos / nomos).
   * - The `orbit` section is writable by any server.
   * - All other sections must remain unchanged or an error is thrown.
   */
  async write(
    owner: Owner,
    updater: (current: LogosStatus) => LogosStatus
  ): Promise<LogosStatus> {
    await this.acquireLock();
    try {
      const current = await this.read();
      const updated = updater(current);

      // Validate the result against the schema
      LogosStatusSchema.parse(updated);

      // Ownership enforcement: non-owner sections must be identical
      const sections = ["integrity", "chronos", "nomos"] as const;
      for (const section of sections) {
        if (section !== owner) {
          if (
            JSON.stringify(current[section]) !==
            JSON.stringify(updated[section])
          ) {
            throw new Error(
              `ownership violation: ${owner} cannot modify ${section} section`
            );
          }
        }
      }

      await writeFile(this.statusPath, JSON.stringify(updated, null, 2));
      return updated;
    } finally {
      await this.releaseLock();
    }
  }

  // ── File locking ─────────────────────────────────────────────────────

  private async acquireLock(): Promise<void> {
    for (let attempt = 0; attempt < LOCK_RETRIES; attempt++) {
      try {
        // wx flag: create exclusively, fail if exists
        const fh = await open(this.lockPath, "wx");
        await fh.close();
        return;
      } catch (err: unknown) {
        if (isNodeError(err) && err.code === "EEXIST") {
          if (attempt < LOCK_RETRIES - 1) {
            await sleep(LOCK_DELAY_MS);
            continue;
          }
          throw new Error("Could not acquire status lock after retries");
        }
        throw err;
      }
    }
  }

  private async releaseLock(): Promise<void> {
    try {
      await unlink(this.lockPath);
    } catch {
      // lock file already removed — acceptable
    }
  }
}

function isNodeError(err: unknown): err is NodeJS.ErrnoException {
  return err instanceof Error && "code" in err;
}
