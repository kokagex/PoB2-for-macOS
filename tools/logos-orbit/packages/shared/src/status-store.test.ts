import { describe, it, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { StatusStore } from "./status-store.js";
import { LogosStatusSchema } from "./schema.js";

let dataDir: string;

beforeEach(async () => {
  dataDir = await mkdtemp(join(tmpdir(), "logos-test-"));
});

describe("StatusStore", () => {
  it("initializes with empty status on first read", async () => {
    const store = new StatusStore(dataDir);
    const status = await store.read();
    const result = LogosStatusSchema.safeParse(status);
    assert.equal(result.success, true);
    assert.equal(status.integrity.score, 1.0);
    assert.deepEqual(status.integrity.penalties, []);
  });

  it("allows integrity to write its own section", async () => {
    const store = new StatusStore(dataDir);
    const updated = await store.write("integrity", (current) => ({
      ...current,
      integrity: {
        ...current.integrity,
        score: 0.75,
      },
    }));
    assert.equal(updated.integrity.score, 0.75);
  });

  it("rejects integrity writing to chronos section", async () => {
    const store = new StatusStore(dataDir);
    await assert.rejects(
      () =>
        store.write("integrity", (current) => ({
          ...current,
          chronos: {
            ...current.chronos,
            lastCheck: "2099-01-01T00:00:00.000Z",
          },
        })),
      (err: Error) => {
        assert.match(err.message, /ownership violation/);
        return true;
      }
    );
  });

  it("rejects chronos writing to nomos section", async () => {
    const store = new StatusStore(dataDir);
    await assert.rejects(
      () =>
        store.write("chronos", (current) => ({
          ...current,
          nomos: {
            ...current.nomos,
            totalRulesGenerated: 999,
          },
        })),
      (err: Error) => {
        assert.match(err.message, /ownership violation/);
        return true;
      }
    );
  });

  it("allows any server to write orbit section", async () => {
    const store = new StatusStore(dataDir);

    for (const owner of ["integrity", "chronos", "nomos"] as const) {
      const updated = await store.write(owner, (current) => ({
        ...current,
        orbit: {
          ...current.orbit,
          lastSync: new Date().toISOString(),
        },
      }));
      assert.ok(updated.orbit.lastSync);
    }
  });

  it("persists across StatusStore instances", async () => {
    const store1 = new StatusStore(dataDir);
    await store1.write("integrity", (current) => ({
      ...current,
      integrity: {
        ...current.integrity,
        score: 0.42,
      },
    }));

    const store2 = new StatusStore(dataDir);
    const status = await store2.read();
    assert.equal(status.integrity.score, 0.42);
  });
});
