import { describe, it, expect, afterAll } from "vitest";
import { Worker } from "../src/worker.js";
import { readFileSync } from "node:fs";

const repoRoot = new URL("../../../", import.meta.url).pathname;
const golden = readFileSync(`${repoRoot}mcp/spike/GOLDEN.md`, "utf8");
const buildPath = repoRoot + /build file: (.+)/.exec(golden)![1].trim();
const buildXml = readFileSync(buildPath, "utf8");

const worker = new Worker(repoRoot);
afterAll(() => worker.dispose());

type ListResult = {
  total: number;
  returned: number;
  results: Record<string, unknown>[];
  types?: string[];
};

describe("data_gems", () => {
  it("list mode filters by gemType and caps with total", async () => {
    const out = (await worker.query("data_gems", {
      gemType: "support",
      limit: 5,
    })) as ListResult;
    expect(out.total).toBeGreaterThan(50);
    expect(out.returned).toBe(5);
    expect(out.results.every((g) => g.type === "support")).toBe(true);
  }, 60_000);

  it("detail mode returns levels for a known skill gem", async () => {
    const out = (await worker.query("data_gems", {
      name: "eye of winter",
    })) as Record<string, unknown>;
    expect(out.name).toBe("Eye of Winter");
    expect(out.type).toBe("skill");
    expect((out.levels as unknown[]).length).toBeGreaterThan(0);
  }, 60_000);

  it("unknown gem name is a hard error", async () => {
    await expect(
      worker.query("data_gems", { name: "NoSuchGem" }),
    ).rejects.toThrow(/"NoSuchGem" not found/);
  }, 60_000);
});

describe("data_uniques", () => {
  it("list mode returns names+bases and the valid type list", async () => {
    const out = (await worker.query("data_uniques", { limit: 10 })) as ListResult;
    expect(out.total).toBeGreaterThan(100);
    expect(out.types).toContain("body");
    expect(out.results[0]).toHaveProperty("name");
    expect(out.results[0]).toHaveProperty("base");
  }, 60_000);

  it("detail mode returns mods and raw text usable by patch.items", async () => {
    const list = (await worker.query("data_uniques", {
      type: "body",
      limit: 1,
    })) as ListResult;
    const name = list.results[0].name as string;
    const detail = (await worker.query("data_uniques", { name })) as Record<
      string,
      unknown
    >;
    expect(detail.type).toBe("body");
    expect((detail.mods as string[]).length).toBeGreaterThan(0);
    expect(detail.raw as string).toContain(name);
  }, 60_000);
});

describe("data_passives", () => {
  it("finds keystones with stats", async () => {
    const out = (await worker.query("data_passives", {
      type: "Keystone",
      limit: 50,
    })) as ListResult;
    expect(out.total).toBeGreaterThan(5);
    const node = out.results[0];
    expect(typeof node.id).toBe("number");
    expect((node.stats as string[]).length).toBeGreaterThan(0);
  }, 60_000);

  it("stat-text search matches node stat lines", async () => {
    const out = (await worker.query("data_passives", {
      search: "cast speed",
      limit: 5,
    })) as ListResult;
    expect(out.total).toBeGreaterThan(0);
  }, 60_000);
});

describe("data_itembases", () => {
  it("filters by type and reports armour stats", async () => {
    const out = (await worker.query("data_itembases", {
      type: "Body Armour",
      limit: 5,
    })) as ListResult;
    expect(out.total).toBeGreaterThan(10);
    expect(out.types).toContain("Body Armour");
    expect(out.results.every((b) => b.type === "Body Armour")).toBe(true);
  }, 60_000);
});

describe("build_info", () => {
  it("summarises character, items, skills and passives", async () => {
    const info = (await worker.info({ buildXml })) as Record<string, any>;
    expect(info.character.class).toBeTruthy();
    expect(info.items.length).toBeGreaterThan(0);
    expect(info.skills.length).toBeGreaterThan(0);
    const main = info.skills.find((g: any) => g.isMain);
    expect(main.gems.length).toBeGreaterThan(0);
    expect(info.passives.allocated).toBeGreaterThan(0);
    expect(info.passives.notables.length).toBeGreaterThan(0);
  }, 60_000);
});

describe("patch.allocNodes / deallocNodes", () => {
  it("deallocating a notable shrinks the allocated count", async () => {
    const base = (await worker.info({ buildXml })) as Record<string, any>;
    const notable = base.passives.notables[0];
    const patched = (await worker.info({
      buildXml,
      patch: { deallocNodes: [notable] },
    })) as Record<string, any>;
    expect(patched.passives.allocated).toBeLessThan(base.passives.allocated);
    expect(patched.passives.notables).not.toContain(notable);
  }, 60_000);

  it("dealloc+realloc round-trips a notable back into the tree", async () => {
    const base = (await worker.info({ buildXml })) as Record<string, any>;
    const notable = base.passives.notables[0];
    const patched = (await worker.info({
      buildXml,
      patch: { deallocNodes: [notable], allocNodes: [notable] },
    })) as Record<string, any>;
    expect(patched.passives.notables).toContain(notable);
  }, 60_000);

  it("unknown node refs are hard errors", async () => {
    await expect(
      worker.info({ buildXml, patch: { allocNodes: ["No Such Node"] } }),
    ).rejects.toThrow(/"No Such Node" not found/);
  }, 60_000);

  it("allocating an already-allocated node is a hard error", async () => {
    const base = (await worker.info({ buildXml })) as Record<string, any>;
    const notable = base.passives.notables[0];
    await expect(
      worker.info({ buildXml, patch: { allocNodes: [notable] } }),
    ).rejects.toThrow(/already allocated/);
  }, 60_000);
});

describe("patch.items", () => {
  it("equips a unique from data_uniques raw text into a slot", async () => {
    const list = (await worker.query("data_uniques", {
      type: "body",
      limit: 1,
    })) as ListResult;
    const name = list.results[0].name as string;
    const detail = (await worker.query("data_uniques", { name })) as Record<
      string,
      unknown
    >;
    const info = (await worker.info({
      buildXml,
      patch: { items: [{ slot: "Body Armour", raw: detail.raw as string }] },
    })) as Record<string, any>;
    const slot = info.items.find((i: any) => i.slot === "Body Armour");
    expect(slot.name).toContain(name);
    expect(slot.rarity).toBe("UNIQUE");
  }, 60_000);

  it("unknown slot is a hard error listing the slots", async () => {
    await expect(
      worker.info({
        buildXml,
        patch: { items: [{ slot: "NoSuchSlot", raw: "x\ny" }] },
      }),
    ).rejects.toThrow(/slot "NoSuchSlot" not found/);
  }, 60_000);
});
