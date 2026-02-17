import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StatusStore } from "@logos-orbit/shared";
import {
  VerifyReasoningSchema,
  verifyReasoning,
} from "./tools/verify_reasoning.js";
import { VerifyCodeSchema, verifyCode } from "./tools/verify_code.js";
import { getIntegrityStatus } from "./tools/get_integrity_status.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const dataDir = join(__dirname, "../../..", "data");
const store = new StatusStore(dataDir);

const server = new McpServer({
  name: "logos-integrity",
  version: "1.0.0",
});

server.tool(
  "verify_reasoning",
  "Verify the logical integrity of a chain of reasoning. Detects contradictions, concept leaps, circular reasoning, and ungrounded assumptions. Returns confidence score and verdict.",
  VerifyReasoningSchema.shape,
  async (args) => {
    try {
      const parsed = VerifyReasoningSchema.parse(args);
      const result = await verifyReasoning(parsed, store);
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

server.tool(
  "verify_code",
  "Verify that code changes match the claimed behavior. Checks file existence, line bounds, and token overlap between claim and actual code.",
  VerifyCodeSchema.shape,
  async (args) => {
    try {
      const parsed = VerifyCodeSchema.parse(args);
      const result = await verifyCode(parsed, store);
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

server.tool(
  "get_integrity_status",
  "Get the current integrity status including verification count, confidence, contradictions, and decay status.",
  {},
  async () => {
    try {
      const result = await getIntegrityStatus(store);
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

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
