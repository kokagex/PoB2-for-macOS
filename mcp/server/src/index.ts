import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFileSync } from "node:fs";
import { Worker, type CalcRequest, type Patch } from "./worker.js";

// repoRoot = three levels up from dist/index.js  (mcp/server/dist -> repo root)
const repoRoot = new URL("../../../", import.meta.url).pathname;
const worker = new Worker(repoRoot);

const patchSchema = z
  .object({
    config: z.record(z.unknown()).optional(),
    enemyLevel: z.number().optional(),
    treeURL: z.string().optional(),
    // Selects the main skill by gem name (case-insensitive exact match against
    // the build's socket groups; first matching group wins). Unknown names are
    // a hard worker error listing the gems present — never silently ignored.
    skillName: z.string().optional(),
  })
  .optional();

const buildSource = {
  buildPath: z.string().optional(),
  buildXml: z.string().optional(),
};

// Resolve buildPath|buildXml to raw XML, throwing a tool error if neither given.
function resolveXml(buildPath?: string, buildXml?: string): string {
  if (buildXml) return buildXml;
  if (buildPath) return readFileSync(buildPath, "utf8");
  throw new Error("Provide buildPath or buildXml.");
}

function jsonResult(obj: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(obj, null, 2) }] };
}

const server = new McpServer({ name: "pob2-damage-calc", version: "0.1.0" });

server.tool(
  "calc_topline",
  "Compute top-line DPS for a Path of Building 2 build using the real PoB calc " +
    "engine (headless). Provide buildPath or buildXml. Optional patch applies " +
    "before calc: { config, enemyLevel, treeURL, skillName }. skillName selects " +
    "which skill the DPS is computed for (gem name, e.g. 'Eye of Winter'); " +
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
    "where the levers are. Provide buildPath or buildXml; optional patch " +
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
    "as-is), patchB is the variant; each accepts { config, enemyLevel, treeURL, " +
    "skillName }. Returns each top-line metric as { a, b, delta, pct }.",
  {
    ...buildSource,
    patchA: patchSchema,
    patchB: patchSchema,
  },
  async ({ buildPath, buildXml, patchA, patchB }) => {
    const xml = resolveXml(buildPath, buildXml);
    const [a, b] = await Promise.all([
      worker.calc({ buildXml: xml, patch: patchA as Patch | undefined }),
      worker.calc({ buildXml: xml, patch: patchB as Patch | undefined }),
    ]);
    const cmp: Record<string, { a: number; b: number; delta: number; pct: number | null }> = {};
    for (const key of Object.keys(a) as Array<keyof typeof a>) {
      const av = a[key] as number;
      const bv = b[key] as number;
      cmp[key as string] = {
        a: av,
        b: bv,
        delta: bv - av,
        pct: av !== 0 ? ((bv - av) / av) * 100 : null,
      };
    }
    return jsonResult(cmp);
  },
);

server.tool(
  "export_build",
  "Serialise a (optionally patched) PoB2 build to a Path of Building import code " +
    "(base64), so the user can paste it into the PoB GUI. Provide buildPath or " +
    "buildXml; optional patch is applied before export.",
  { ...buildSource, patch: patchSchema },
  async ({ buildPath, buildXml, patch }) => {
    const xml = resolveXml(buildPath, buildXml);
    const { code } = await worker.exportCode({ buildXml: xml, patch } as CalcRequest);
    return jsonResult({ code });
  },
);

await server.connect(new StdioServerTransport());
