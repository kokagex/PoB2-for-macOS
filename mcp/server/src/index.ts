import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { Worker, type CalcRequest, type Patch } from "./worker.js";
import {
  buildSource,
  compareInputShape,
  DEFENCE_KEYS,
  diffTopline,
  patchSchema,
  resolveXml,
} from "./lib.js";

// repoRoot = three levels up from dist/index.js  (mcp/server/dist -> repo root)
const repoRoot = new URL("../../../", import.meta.url).pathname;
const worker = new Worker(repoRoot);

function jsonResult(obj: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(obj, null, 2) }] };
}

const server = new McpServer({ name: "PoB2Advisor", version: "0.3.0" });

server.tool(
  "calc_topline",
  "Compute top-line DPS for a Path of Building 2 build using the real PoB calc " +
    "engine (headless). Provide buildPath (absolute) or buildXml. Optional patch " +
    "applies before calc: { config, enemyLevel, treeURL, skillName }. skillName " +
    "selects which skill the DPS is computed for (gem name, e.g. 'Eye of Winter'); " +
    "without it the build's saved main skill is used.",
  { ...buildSource, patch: patchSchema },
  async ({ buildPath, buildXml, patch }) => {
    const xml = resolveXml(buildPath, buildXml);
    return jsonResult(await worker.calc({ buildXml: xml, patch }));
  },
);

server.tool(
  "calc_breakdown",
  "Detailed DPS breakdown (crit, speed, hit chance, per-damage-type hit averages, " +
    "DoT, costs) for a PoB2 build — use to explain why a number is what it is and " +
    "where the levers are. Provide buildPath (absolute) or buildXml; optional patch " +
    "{ config, enemyLevel, treeURL, skillName } — skillName picks the skill to analyse.",
  { ...buildSource, patch: patchSchema },
  async ({ buildPath, buildXml, patch }) => {
    const xml = resolveXml(buildPath, buildXml);
    return jsonResult(await worker.breakdown({ buildXml: xml, patch }));
  },
);

server.tool(
  "calc_compare",
  "Compare two variants of a PoB2 build and report the per-metric delta — answers " +
    "'how much does this change help?'. patchA is the baseline (omit for the build " +
    "as-is); patchB is the variant and is REQUIRED. Each accepts { config, " +
    "enemyLevel, treeURL, skillName, items, gems, allocNodes, deallocNodes }. " +
    "metrics picks the report: 'offence' (default, DPS top-line), 'defence' " +
    "(EHP-first: EHP, life/ES, resists, max hits, block), 'full' (everything). " +
    "Returns each metric as { a, b, delta, pct }.",
  {
    ...compareInputShape,
    metrics: z.enum(["offence", "defence", "full"]).optional(),
  },
  async ({ buildPath, buildXml, patchA, patchB, metrics }) => {
    const xml = resolveXml(buildPath, buildXml);
    const mode = metrics ?? "offence";
    const run =
      mode === "offence"
        ? (patch?: Patch) => worker.calc({ buildXml: xml, patch })
        : (patch?: Patch) => worker.breakdown({ buildXml: xml, patch });
    const [a, b] = await Promise.all([
      run(patchA as Patch | undefined),
      run(patchB as Patch),
    ]);
    return jsonResult(diffTopline(a, b, mode === "defence" ? DEFENCE_KEYS : undefined));
  },
);

server.tool(
  "export_build",
  "Serialise a (optionally patched) PoB2 build to a Path of Building import code " +
    "(base64), so the user can paste it into the PoB GUI. Provide buildPath " +
    "(absolute) or buildXml; optional patch is applied before export.",
  { ...buildSource, patch: patchSchema },
  async ({ buildPath, buildXml, patch }) => {
    const xml = resolveXml(buildPath, buildXml);
    const { code } = await worker.exportCode({ buildXml: xml, patch } as CalcRequest);
    return jsonResult({ code });
  },
);

const limit = z
  .number()
  .optional()
  .describe("Max results to return (default 20); `total` reports the uncapped count");

server.tool(
  "build_info",
  "Structural summary of a PoB2 build: character (class/ascendancy/level), " +
    "equipped items per slot, skill socket groups with gems, allocated " +
    "passives (keystones + notables), and config. Read this before giving " +
    "build advice. Optional patch is applied first, so you can also inspect " +
    "what a variant would look like.",
  { ...buildSource, patch: patchSchema },
  async ({ buildPath, buildXml, patch }) => {
    const xml = resolveXml(buildPath, buildXml);
    return jsonResult(await worker.info({ buildXml: xml, patch }));
  },
);

server.tool(
  "data_gems",
  "Search the PoE2 skill/support gem database (no build needed). List mode: " +
    "search (name/tag substring), gemType ('skill'|'support'), limit. Detail " +
    "mode: name (exact, case-insensitive) returns requirements, description, " +
    "granted effects and per-level cost summary.",
  {
    search: z.string().optional().describe("Substring match on gem name or tags"),
    gemType: z.enum(["skill", "support"]).optional(),
    name: z.string().optional().describe("Exact gem name for full detail"),
    limit,
  },
  async ({ search, gemType, name, limit }) =>
    jsonResult(await worker.query("data_gems", { search, gemType, name, limit })),
);

server.tool(
  "data_uniques",
  "Search the PoE2 unique item database (no build needed). List mode: search " +
    "(name/base substring), textSearch (substring anywhere in the item text, " +
    "e.g. a mod), type (slot category like 'body', 'ring' — response lists " +
    "valid types), limit. Detail mode: name (exact) returns implicits, mods " +
    "and the raw item text, which can be passed directly to patch.items to " +
    "equip the unique in a calc.",
  {
    search: z.string().optional().describe("Substring match on item name or base"),
    textSearch: z
      .string()
      .optional()
      .describe("Substring match anywhere in the raw item text (mods included)"),
    type: z.string().optional().describe("Slot category, e.g. 'body', 'ring'"),
    name: z.string().optional().describe("Exact unique name for full detail + raw text"),
    limit,
  },
  async ({ search, textSearch, type, name, limit }) =>
    jsonResult(
      await worker.query("data_uniques", { search, textSearch, type, name, limit }),
    ),
);

server.tool(
  "data_passives",
  "Search the PoE2 passive tree (no build needed). Filters: " +
    "search (node name or stat text substring), type ('Notable'|'Keystone'|" +
    "'Normal'|'Socket'), ascendancy (name substring; omit to include all " +
    "nodes), version (tree version like '0_4'; default latest — unknown " +
    "versions error listing the valid set). Returns id/name/type/ascendancy/" +
    "stats per node — ids feed patch.allocNodes/deallocNodes.",
  {
    search: z
      .string()
      .optional()
      .describe("Substring match on node name or stat lines"),
    type: z.enum(["Notable", "Keystone", "Normal", "Socket"]).optional(),
    ascendancy: z
      .string()
      .optional()
      .describe("Ascendancy name substring, e.g. 'Chronomancer'"),
    version: z
      .string()
      .optional()
      .describe("Tree version, e.g. '0_4' (default: latest)"),
    limit,
  },
  async ({ search, type, ascendancy, version, limit }) =>
    jsonResult(
      await worker.query("data_passives", {
        search,
        type,
        ascendancy,
        version,
        limit,
      }),
    ),
);

server.tool(
  "data_itembases",
  "Search PoE2 item bases (no build needed). Filters: search (name " +
    "substring), type (e.g. 'Body Armour' — response lists valid types), " +
    "subType. Returns name/type/subType/reqLevel plus armour or weapon stats.",
  {
    search: z.string().optional().describe("Substring match on base name"),
    type: z.string().optional().describe("Item type, e.g. 'Body Armour'"),
    subType: z.string().optional().describe("Sub-type, e.g. 'Armour', 'Radius'"),
    limit,
  },
  async ({ search, type, subType, limit }) =>
    jsonResult(
      await worker.query("data_itembases", { search, type, subType, limit }),
    ),
);

await server.connect(new StdioServerTransport());
