/**
 * Chronos MCP Server — Action recording and drift monitoring.
 *
 * Tools:
 * - record_action: Record an agent action, monitor entropy and stutter
 * - check_drift: Analyze current drift state
 * - hard_stop: Trigger, check, or release a hard stop
 */

import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StatusStore } from "@logos-orbit/shared";
import { RecordActionSchema, recordAction } from "./tools/record_action.js";
import { CheckDriftSchema, checkDrift } from "./tools/check_drift.js";
import {
  HardStopRawSchema,
  HardStopSchema,
  hardStop,
} from "./tools/hard_stop.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const dataDir = join(__dirname, "../../..", "data");
const store = new StatusStore(dataDir);

const server = new McpServer({
  name: "logos-chronos",
  version: "1.0.0",
});

// ── record_action ────────────────────────────────────────────────────────

server.tool(
  "record_action",
  "Record an agent action and monitor for drift. Tracks action types, detects stutter patterns, and calculates entropy. Triggers HARD_STOP if entropy exceeds threshold.",
  RecordActionSchema.shape,
  async (args) => {
    try {
      const parsed = RecordActionSchema.parse(args);
      const result = await recordAction(parsed, store);
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

// ── check_drift ──────────────────────────────────────────────────────────

server.tool(
  "check_drift",
  "Analyze current drift state: entropy, action distribution, stutter patterns, rationale contradictions, and recommendation.",
  CheckDriftSchema.shape,
  async (args) => {
    try {
      const parsed = CheckDriftSchema.parse(args);
      const result = await checkDrift(parsed, store);
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

// ── hard_stop ────────────────────────────────────────────────────────────

server.tool(
  "hard_stop",
  "Trigger, check, or release a hard stop. Trigger halts the system. Release requires userApproval string (C-C5).",
  HardStopRawSchema.shape,
  async (args) => {
    try {
      // Validate with full schema (includes refine checks)
      const parsed = HardStopSchema.parse(args);
      const result = await hardStop(parsed, store);
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

// ── Bootstrap ────────────────────────────────────────────────────────────

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
