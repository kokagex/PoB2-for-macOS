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

describe("patch.gems", () => {
  it("adds a support gem to the main socket group", async () => {
    const supports = (await worker.query("data_gems", {
      gemType: "support",
      limit: 1,
    })) as ListResult;
    const gemName = supports.results[0].name as string;
    const info = (await worker.info({
      buildXml,
      patch: { gems: [{ name: gemName }] },
    })) as Record<string, any>;
    const main = info.skills.find((g: any) => g.isMain);
    expect(main.gems.map((g: any) => g.name)).toContain(gemName);
  }, 60_000);

  it("sets level and quality of an existing gem", async () => {
    const base = (await worker.info({ buildXml })) as Record<string, any>;
    const mainGem = base.skills.find((g: any) => g.isMain).gems[0];
    const info = (await worker.info({
      buildXml,
      patch: { gems: [{ name: mainGem.name, level: 1, quality: 13 }] },
    })) as Record<string, any>;
    const patched = info.skills
      .find((g: any) => g.isMain)
      .gems.find((g: any) => g.name === mainGem.name);
    expect(patched.level).toBe(1);
    expect(patched.quality).toBe(13);
  }, 60_000);

  it("removes an existing gem from its group", async () => {
    const base = (await worker.info({ buildXml })) as Record<string, any>;
    const mainGroup = base.skills.find((g: any) => g.isMain);
    const victim = mainGroup.gems[mainGroup.gems.length - 1].name;
    const info = (await worker.info({
      buildXml,
      patch: { gems: [{ name: victim, group: mainGroup.index, remove: true }] },
    })) as Record<string, any>;
    const patched = info.skills.find((g: any) => g.index === mainGroup.index);
    expect(patched.gems.map((g: any) => g.name)).not.toContain(victim);
  }, 60_000);

  it("adding an unknown gem name is a hard error", async () => {
    await expect(
      worker.info({ buildXml, patch: { gems: [{ name: "No Such Gem" }] } }),
    ).rejects.toThrow(/"No Such Gem" not found/);
  }, 60_000);

  it("removing a gem that is not in the group is a hard error", async () => {
    const supports = (await worker.query("data_gems", {
      gemType: "support",
      limit: 1,
    })) as ListResult;
    const gemName = supports.results[0].name as string;
    await expect(
      worker.info({
        buildXml,
        patch: { gems: [{ name: gemName, remove: true }] },
      }),
    ).rejects.toThrow(/not in socket group/);
  }, 60_000);

  it("out-of-range group index is a hard error", async () => {
    await expect(
      worker.info({
        buildXml,
        patch: { gems: [{ name: "x", group: 999 }] },
      }),
    ).rejects.toThrow(/group 999/);
  }, 60_000);
});

describe("patch.items into jewel sockets", () => {
  it("build_info lists allocated jewel sockets", async () => {
    const info = (await worker.info({ buildXml })) as Record<string, any>;
    expect(info.passives.sockets.length).toBeGreaterThan(0);
    expect(typeof info.passives.sockets[0]).toBe("number");
  }, 60_000);

  it("equips a unique jewel into an allocated tree socket", async () => {
    const base = (await worker.info({ buildXml })) as Record<string, any>;
    const socketId = base.passives.sockets[0];
    const list = (await worker.query("data_uniques", {
      type: "jewel",
      limit: 1,
    })) as ListResult;
    const detail = (await worker.query("data_uniques", {
      name: list.results[0].name as string,
    })) as Record<string, unknown>;
    const info = (await worker.info({
      buildXml,
      patch: {
        items: [{ slot: `Jewel ${socketId}`, raw: detail.raw as string }],
      },
    })) as Record<string, any>;
    const slot = info.items.find((i: any) => i.slot === `Jewel ${socketId}`);
    expect(slot.name).toContain(list.results[0].name as string);
  }, 60_000);

  it("equipping into an unallocated socket is a hard error", async () => {
    const base = (await worker.info({ buildXml })) as Record<string, any>;
    const allocated = new Set(base.passives.sockets);
    const all = (await worker.query("data_passives", {
      type: "Socket",
      limit: 200,
    })) as ListResult;
    const free = all.results.find(
      (n) => !allocated.has(n.id) && !n.ascendancy,
    )!;
    const list = (await worker.query("data_uniques", {
      type: "jewel",
      limit: 1,
    })) as ListResult;
    const detail = (await worker.query("data_uniques", {
      name: list.results[0].name as string,
    })) as Record<string, unknown>;
    await expect(
      worker.info({
        buildXml,
        patch: {
          items: [{ slot: `Jewel ${free.id}`, raw: detail.raw as string }],
        },
      }),
    ).rejects.toThrow(/not allocated/);
  }, 60_000);
});

describe("data_passives version", () => {
  it("queries an older tree version and reports it", async () => {
    const out = (await worker.query("data_passives", {
      type: "Keystone",
      version: "0_4",
      limit: 5,
    })) as ListResult & { version?: string };
    expect(out.total).toBeGreaterThan(0);
    expect(out.version).toBe("0_4");
  }, 120_000);

  it("defaults to the latest tree version", async () => {
    const out = (await worker.query("data_passives", {
      type: "Keystone",
      limit: 1,
    })) as ListResult & { version?: string };
    expect(out.version).toBe("0_5");
  }, 60_000);

  it("unknown version is a hard error listing valid versions", async () => {
    await expect(
      worker.query("data_passives", { version: "9_9" }),
    ).rejects.toThrow(/0_5/);
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
