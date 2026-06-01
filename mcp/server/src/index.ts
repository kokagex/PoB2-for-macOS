import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFileSync } from "node:fs";
import { Worker } from "./worker.js";

// repoRoot = three levels up from dist/index.js  (mcp/server/dist -> repo root)
const repoRoot = new URL("../../../", import.meta.url).pathname;
const worker = new Worker(repoRoot);

const server = new McpServer({ name: "pob2-damage-calc", version: "0.1.0" });

server.tool(
  "calc_topline",
  "Compute top-line DPS for a Path of Building 2 build using the real PoB calc " +
    "engine (headless). Provide the build as a file path (buildPath) or raw XML " +
    "(buildXml). Optional patch applies before calc: { config, enemyLevel, treeURL }.",
  {
    buildPath: z.string().optional(),
    buildXml: z.string().optional(),
    patch: z
      .object({
        config: z.record(z.unknown()).optional(),
        enemyLevel: z.number().optional(),
        treeURL: z.string().optional(),
      })
      .optional(),
  },
  async ({ buildPath, buildXml, patch }) => {
    if (!buildPath && !buildXml) {
      return {
        isError: true,
        content: [{ type: "text", text: "Provide buildPath or buildXml." }],
      };
    }
    const xml = buildXml ?? readFileSync(buildPath!, "utf8");
    const out = await worker.calc({ buildXml: xml, patch });
    return { content: [{ type: "text", text: JSON.stringify(out, null, 2) }] };
  },
);

await server.connect(new StdioServerTransport());
