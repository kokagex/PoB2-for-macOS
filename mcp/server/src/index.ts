import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { Worker, type CalcRequest, type Patch } from "./worker.js";
import {
  buildSource,
  compareInputShape,
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

const server = new McpServer({ name: "pob2-damage-calc", version: "0.1.0" });

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
    "enemyLevel, treeURL, skillName }. Returns each metric as { a, b, delta, pct }.",
  compareInputShape,
  async ({ buildPath, buildXml, patchA, patchB }) => {
    const xml = resolveXml(buildPath, buildXml);
    const [a, b] = await Promise.all([
      worker.calc({ buildXml: xml, patch: patchA as Patch | undefined }),
      worker.calc({ buildXml: xml, patch: patchB as Patch }),
    ]);
    return jsonResult(diffTopline(a, b));
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

await server.connect(new StdioServerTransport());
