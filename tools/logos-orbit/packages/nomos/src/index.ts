/**
 * Nomos MCP Server — Rule generation and specification tattooing.
 *
 * Tools:
 * - record_failure: Record a failure for later rule generation
 * - generate_rule: Generate a rule from a recorded failure
 * - tattoo_spec: Queue a specification tattoo (never writes directly)
 */

import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StatusStore } from "@logos-orbit/shared";
import { RecordFailureSchema, recordFailure } from "./tools/record_failure.js";
import { GenerateRuleSchema, generateRule } from "./tools/generate_rule.js";
import { TattooSpecSchema, tattooSpec } from "./tools/tattoo_spec.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const dataDir = join(__dirname, "../../..", "data");
const rulesDir = join(dataDir, "rules");
const store = new StatusStore(dataDir);

const server = new McpServer({
  name: "logos-nomos",
  version: "1.0.0",
});

// ── record_failure ──────────────────────────────────────────────────────

server.tool(
  "record_failure",
  "Record a failure analysis for later rule generation. Returns a failureId for use with generate_rule.",
  RecordFailureSchema.shape,
  async (args) => {
    try {
      const parsed = RecordFailureSchema.parse(args);
      const result = await recordFailure(parsed, store);
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (err) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: err instanceof Error ? err.message : String(err),
            }),
          },
        ],
        isError: true,
      };
    }
  }
);

// ── generate_rule ───────────────────────────────────────────────────────

server.tool(
  "generate_rule",
  "Generate a rule from a recorded failure. Requires a recent failure (within 5 min). Deduplicates by condition hash (C-N4).",
  GenerateRuleSchema.shape,
  async (args) => {
    try {
      const parsed = GenerateRuleSchema.parse(args);
      const result = await generateRule(parsed, store, rulesDir);
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (err) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: err instanceof Error ? err.message : String(err),
            }),
          },
        ],
        isError: true,
      };
    }
  }
);

// ── tattoo_spec ─────────────────────────────────────────────────────────

server.tool(
  "tattoo_spec",
  "Queue a specification tattoo for later application. NEVER writes to target files directly (C-N5). Requires justification.",
  TattooSpecSchema.shape,
  async (args) => {
    try {
      const parsed = TattooSpecSchema.parse(args);
      const result = await tattooSpec(parsed, store);
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (err) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: err instanceof Error ? err.message : String(err),
            }),
          },
        ],
        isError: true,
      };
    }
  }
);

// ── Bootstrap ───────────────────────────────────────────────────────────

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
