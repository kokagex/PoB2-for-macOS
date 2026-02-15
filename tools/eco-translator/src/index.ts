#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { FetchPageSchema, fetchPage } from "./tools/fetch-page.js";
import { ListSectionsSchema, listSections } from "./tools/list-sections.js";
import { GetSectionSchema, getSection } from "./tools/get-section.js";
import { SaveTranslationSchema, saveTranslation } from "./tools/save-translation.js";
import { GlossaryLookupSchema, glossaryLookup } from "./tools/glossary-lookup.js";
import { GlossaryAddSchema, glossaryAdd } from "./tools/glossary-add.js";
import { GetStatusSchema, getStatus } from "./tools/get-status.js";
import { AskUserSchema, askUser } from "./tools/ask-user.js";

const server = new McpServer({
  name: "eco-translator-mcp",
  version: "1.0.0",
});

server.tool("eco_fetch_page", "Fetch a web page via Jina AI and split into sections for translation", FetchPageSchema.shape, fetchPage);
server.tool("eco_list_sections", "List all sections and their translation status", ListSectionsSchema.shape, listSections);
server.tool("eco_get_section", "Get one section's source content with relevant glossary terms", GetSectionSchema.shape, getSection);
server.tool("eco_save_translation", "Save translated content for a section and update progress", SaveTranslationSchema.shape, saveTranslation);
server.tool("eco_glossary_lookup", "Search the shared glossary for term translations", GlossaryLookupSchema.shape, glossaryLookup);
server.tool("eco_glossary_add", "Add new terms to the shared glossary", GlossaryAddSchema.shape, glossaryAdd);
server.tool("eco_get_status", "Get project translation progress and next recommended section", GetStatusSchema.shape, getStatus);
server.tool("eco_ask_user", "Ask user a question when translation confidence is low (stops autonomous translation)", AskUserSchema.shape, askUser);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("eco-translator-mcp server running via stdio");
}

main().catch((error) => {
  console.error("Server error:", error);
  process.exit(1);
});
