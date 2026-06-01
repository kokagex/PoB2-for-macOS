# PoB2 Damage Calc MCP — Slice 1 (Headless Calc Worker) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove headless PoB calc works on this macOS port, then expose a single `calc_topline` MCP tool that loads a build, applies a minimal patch (config + full-tree replace), and returns DPS — validated against the GUI.

**Architecture:** A long-lived `luajit` worker process boots the PoB engine once (`HeadlessWrapper.lua`), then serves one-JSON-request-per-line over stdin/stdout: load build XML → apply patch → `build.calcsTab:BuildOutput()` → emit selected output keys. A thin TypeScript MCP server (stdio transport) spawns and talks to that worker, exposing `calc_topline`. No PoB calc code is modified.

**Tech Stack:** LuaJIT 5.1 (`/usr/local/bin/luajit`), `runtime/lua/dkjson.lua` (JSON), busted (Lua unit tests), Node.js + `@modelcontextprotocol/sdk` + TypeScript (MCP server), `tsx`/`vitest` (TS tests).

**Spec:** `docs/specs/2026-06-01-pob2-damage-calc-mcp.spec.html`

**Out of scope for Slice 1 (→ Slice 2 plan):** `calc_breakdown`, `calc_compare`, `export_build`, gem/item patching, name→id resolution for arbitrary nodes. Slice 1 patch supports only: config `input` keys, `enemyLevel`, and full passive-tree replacement via a PoB tree spec URL.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `mcp/worker/json.lua` | Thin wrapper around `runtime/lua/dkjson.lua`; `encode`/`decode`. |
| `mcp/worker/calc.lua` | Engine glue: `loadBuild(xml)`, `applyPatch(build, patch)`, `readTopline(build)`. Pure-ish, unit-testable parts isolated. |
| `mcp/worker/server.lua` | Long-lived loop: boots engine via HeadlessWrapper, reads JSON lines from stdin, dispatches to `calc.lua`, writes JSON lines to stdout. |
| `mcp/spike/spike.lua` | Phase 0 throwaway: load a build file, print `FullDPS`. Deleted after Task 5. |
| `mcp/server/src/worker.ts` | TS child-process wrapper: spawn `server.lua`, send request, await one response line. |
| `mcp/server/src/index.ts` | MCP server (stdio) exposing `calc_topline`. |
| `test/unit/test_calc_readout.lua` | busted unit test for `readTopline` against a fake build table. |
| `test/integration/smoke_eow.sh` | Integration smoke: run `server.lua`, assert `FullDPS` matches GUI golden. |
| `mcp/server/test/topline.test.ts` | TS test: call `calc_topline` handler, assert it returns the worker's DPS. |

Engine invocation note: `HeadlessWrapper.lua` ends by `dofile("Launch.lua")` and assumes **cwd = `src/`**. All worker entry points therefore `dofile` it relative to `src/` (see Task 3 for the exact bootstrap).

---

## Phase 0 — Feasibility Spike (GATE)

> This phase is a throwaway discovery. **Do not write "validated" anywhere until Task 5 passes.** If a step fails, the spike's job is to surface *why* (init crash, missing data, wrong cwd) — fix the invocation, not the architecture.

### Task 1: Pick a real build file and record its GUI FullDPS

**Files:**
- Create: `mcp/spike/GOLDEN.md`

- [ ] **Step 1: List available builds**

Run:
```bash
ls -1 "$HOME/Library/Application Support/Path of Building/Builds/"
```
Expected: at least one `.xml` (e.g. `Lich_FotV.xml`). Choose the chronomancer EoW build if present; otherwise pick any and note it.

- [ ] **Step 2: Open that build in the PoB GUI and read FullDPS**

Open `PathOfBuilding.app`, load the chosen build, read the **Full DPS** value shown in the sidebar. Record the exact number.

- [ ] **Step 3: Write the golden record**

Create `mcp/spike/GOLDEN.md`:
```markdown
# Spike golden
- build file: <absolute path to the .xml you chose>
- GUI FullDPS: <exact number from GUI>
- date: 2026-06-01
```

- [ ] **Step 4: Commit**

```bash
git add mcp/spike/GOLDEN.md
git commit -m "spike: record GUI FullDPS golden for headless calc validation"
```

### Task 2: Minimal headless DPS print

**Files:**
- Create: `mcp/spike/spike.lua`

- [ ] **Step 1: Write the spike script**

Create `mcp/spike/spike.lua`:
```lua
-- Run with cwd = repo-root/src :  luajit ../mcp/spike/spike.lua <buildXmlPath>
-- HeadlessWrapper boots the engine and defines loadBuildFromXML / build as globals.
local buildPath = assert(arg[1], "usage: spike.lua <buildXmlPath>")

dofile("HeadlessWrapper.lua")  -- cwd must be src/

local f = assert(io.open(buildPath, "r"))
local xml = f:read("*a"); f:close()

loadBuildFromXML(xml, "spike")
build.calcsTab:BuildOutput()
local out = build.calcsTab.mainOutput

print("FullDPS=" .. tostring(out.FullDPS))
print("TotalDPS=" .. tostring(out.TotalDPS))
print("CombinedDPS=" .. tostring(out.CombinedDPS))
```

- [ ] **Step 2: Run the spike**

Run (note the cwd is `src/`):
```bash
cd src && CI=1 luajit ../mcp/spike/spike.lua "$(grep 'build file' ../mcp/spike/GOLDEN.md | sed 's/.*: //')"; cd ..
```
Expected: prints `FullDPS=<number>`. If it errors, read the error:
- `attempt to index ... 'main'` / promptMsg printed → engine failed init; check cwd is `src/`, check `/tmp/pob_init_error.txt`.
- `Failed to load image ... webp` lines are harmless in headless; ignore.
- nil `FullDPS` → the build's main socket group/skill isn't selected; the build file should already have one (it came from GUI).

- [ ] **Step 3: Do NOT commit the spike yet** (kept until Task 5 confirms the number).

### Task 3: Lock the engine bootstrap into a reusable helper

**Files:**
- Create: `mcp/worker/boot.lua`

- [ ] **Step 1: Write the bootstrap helper**

Create `mcp/worker/boot.lua`:
```lua
-- Boots the PoB engine headless and returns nothing; defines globals
-- (loadBuildFromXML, build, mainObject) exactly as HeadlessWrapper does.
-- Caller MUST chdir into src/ before requiring this (HeadlessWrapper uses
-- relative dofile("Launch.lua")). We assert that precondition.
local probe = io.open("HeadlessWrapper.lua", "r")
assert(probe, "boot.lua: cwd must be the PoB src/ directory")
probe:close()

os.setenv = os.setenv  -- noop guard for clarity
if not os.getenv("CI") then
  -- ModCache skip is keyed on CI; force it so first boot needs no prebuilt cache.
  -- (HeadlessWrapper reads os.getenv("CI") into continuousIntegrationMode.)
end

dofile("HeadlessWrapper.lua")
assert(_G.build, "boot.lua: engine boot failed (build global is nil)")
```

- [ ] **Step 2: Smoke-run the bootstrap**

Run:
```bash
cd src && CI=1 luajit -e 'dofile("../mcp/worker/boot.lua"); print("boot ok, build=", tostring(build))'; cd ..
```
Expected: `boot ok, build= table: 0x...`. If `build` is nil, the spike (Task 2) already exposed the reason — fix init before continuing.

- [ ] **Step 3: Commit**

```bash
git add mcp/worker/boot.lua
git commit -m "feat(worker): headless engine bootstrap helper"
```

---

## Phase 1 — Worker JSON request/response loop

### Task 4: JSON wrapper + topline reader (unit-tested)

**Files:**
- Create: `mcp/worker/json.lua`
- Create: `mcp/worker/calc.lua`
- Test: `test/unit/test_calc_readout.lua`

- [ ] **Step 1: Write the failing unit test**

Create `test/unit/test_calc_readout.lua`:
```lua
-- busted: tests readTopline shape against a fake build (no engine needed)
package.path = package.path .. ";./mcp/worker/?.lua"
local calc = require("calc")

describe("calc.readTopline", function()
  it("extracts the v1 output keys from mainOutput", function()
    local fakeBuild = {
      calcsTab = {
        mainOutput = {
          FullDPS = 1234.5, TotalDPS = 1000, CombinedDPS = 1100,
          AverageDamage = 50, BleedDPS = 0, IgniteDPS = 200, PoisonDPS = 0,
          CritChance = 75, Speed = 4.2,
        }
      }
    }
    local t = calc.readTopline(fakeBuild)
    assert.are.equal(1234.5, t.FullDPS)
    assert.are.equal(200, t.IgniteDPS)
    assert.are.equal(75, t.CritChance)
    assert.are.equal(4.2, t.Speed)
  end)

  it("returns 0 (not nil) for missing keys", function()
    local t = calc.readTopline({ calcsTab = { mainOutput = {} } })
    assert.are.equal(0, t.FullDPS)
  end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```bash
eval "$(luarocks --lua-version 5.1 path)"; busted test/unit/test_calc_readout.lua --verbose
```
Expected: FAIL — `module 'calc' not found`.

- [ ] **Step 3: Write `json.lua`**

Create `mcp/worker/json.lua`:
```lua
-- Wrapper over the bundled dkjson. Worker boots with cwd=src/, so dkjson is at
-- ../runtime/lua/dkjson.lua relative to that; also works if already on package.path.
local ok, dk = pcall(require, "dkjson")
if not ok then
  dk = dofile("../runtime/lua/dkjson.lua")
end
local M = {}
function M.encode(t) return dk.encode(t, { indent = false }) end
function M.decode(s) return dk.decode(s) end
return M
```

- [ ] **Step 4: Write `calc.lua` with `readTopline`**

Create `mcp/worker/calc.lua`:
```lua
local M = {}

local TOPLINE_KEYS = {
  "FullDPS", "TotalDPS", "CombinedDPS", "AverageDamage",
  "BleedDPS", "IgniteDPS", "PoisonDPS", "CritChance", "Speed",
}

-- Pull the v1 output keys; missing keys default to 0 (never nil).
function M.readTopline(build)
  local out = build.calcsTab.mainOutput or {}
  local t = {}
  for _, k in ipairs(TOPLINE_KEYS) do
    t[k] = out[k] or 0
  end
  return t
end

return M
```

- [ ] **Step 5: Run the test to verify it passes**

Run:
```bash
eval "$(luarocks --lua-version 5.1 path)"; busted test/unit/test_calc_readout.lua --verbose
```
Expected: PASS (2 successes).

- [ ] **Step 6: Commit**

```bash
git add mcp/worker/json.lua mcp/worker/calc.lua test/unit/test_calc_readout.lua
git commit -m "feat(worker): json wrapper + readTopline output extractor (unit-tested)"
```

### Task 5: `loadBuild` + `applyPatch` + GUI-validated spike close

**Files:**
- Modify: `mcp/worker/calc.lua`
- Create: `test/integration/smoke_eow.sh`

- [ ] **Step 1: Add `loadBuild` and `applyPatch` to `calc.lua`**

Append to `mcp/worker/calc.lua` (above `return M`):
```lua
-- Loads a build from XML, fully resetting build-level state (engine/data stays warm).
function M.loadBuild(xml)
  loadBuildFromXML(xml, "mcp")
  return _G.build
end

-- Slice 1 patch: config input keys, enemyLevel, full passive-tree replace.
-- patch = { config = {k=v,...}, enemyLevel = N, treeURL = "https://..." }
function M.applyPatch(build, patch)
  if not patch then return end
  if patch.treeURL and patch.treeURL ~= "" then
    -- PoB imports a tree URL as a complete node set (no pathing problem).
    build.treeTab:LoadURL(patch.treeURL)
  end
  if patch.config then
    for k, v in pairs(patch.config) do
      build.configTab.input[k] = v
    end
  end
  if patch.enemyLevel then
    build.configTab.input.enemyLevel = patch.enemyLevel
  end
  build.buildFlag = true
end

-- Full request handler: load → patch → recalc → topline.
function M.handle(req)
  local build = M.loadBuild(req.buildXml)
  M.applyPatch(build, req.patch)
  build.calcsTab:BuildOutput()
  return M.readTopline(build)
end
```

> Verify during this task that `build.treeTab.LoadURL` and `build.configTab.input` are the correct member names on the loaded build object; if the spike showed different names, fix here. (`build.treeTab` is the passive tree tab; `build.configTab.input` holds config values per ConfigTab.lua:39.)

- [ ] **Step 2: Write the integration smoke test**

Create `test/integration/smoke_eow.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_PATH="$(grep 'build file' "$ROOT/mcp/spike/GOLDEN.md" | sed 's/.*: //')"
GOLDEN="$(grep 'GUI FullDPS' "$ROOT/mcp/spike/GOLDEN.md" | sed 's/.*: //')"

# One-shot request through the worker.
REQ=$(CI=1 luajit -e '
  local json = dofile("'"$ROOT"'/mcp/worker/json.lua")
  io.write(json.encode({ buildXml = "PLACEHOLDER" }))' 2>/dev/null || true)

# Build the JSON request with the real XML, then pipe to the worker.
RESP="$(cd "$ROOT/src" && CI=1 luajit -e '
  dofile("../mcp/worker/boot.lua")
  package.path = package.path .. ";../mcp/worker/?.lua"
  local json = require("json"); local calc = require("calc")
  local f = assert(io.open(arg[1])); local xml = f:read("*a"); f:close()
  local res = calc.handle({ buildXml = xml })
  io.write(json.encode(res))
' "$BUILD_PATH")"

echo "worker response: $RESP"
FULL="$(printf '%s' "$RESP" | sed -n 's/.*"FullDPS":\([0-9.eE+-]*\).*/\1/p')"
echo "headless FullDPS=$FULL  GUI golden=$GOLDEN"

# Assert within 1% of the GUI golden.
awk -v a="$FULL" -v b="$GOLDEN" 'BEGIN{
  d = (a>b)?(a-b):(b-a);
  if (b==0 || d/b > 0.01) { print "MISMATCH > 1%"; exit 1 }
  print "MATCH within 1%"
}'
```

- [ ] **Step 3: Run the smoke test**

Run:
```bash
chmod +x test/integration/smoke_eow.sh && ./test/integration/smoke_eow.sh
```
Expected: `MATCH within 1%`. This is the **validation oracle** from the spec. If MISMATCH:
- Large gap → a config default differs (enemy level, conditions); inspect `build.configTab.input` vs the GUI config.
- nil/0 → main skill not selected on load; check `build.mainSocketGroup`.
Do not proceed until MATCH.

- [ ] **Step 4: Delete the spike, keep the golden**

```bash
git rm mcp/spike/spike.lua
git add mcp/worker/calc.lua test/integration/smoke_eow.sh
git commit -m "feat(worker): loadBuild+applyPatch+handle; GUI-validated smoke (spike closed)"
```

### Task 6: Persistent stdin/stdout server loop

**Files:**
- Create: `mcp/worker/server.lua`

- [ ] **Step 1: Write the server loop**

Create `mcp/worker/server.lua`:
```lua
-- Long-lived worker. Boots the engine once (expensive data load), then serves
-- one JSON request per input line, one JSON response per output line.
-- Run with cwd = src/ :  cd src && CI=1 luajit ../mcp/worker/server.lua
dofile("../mcp/worker/boot.lua")
package.path = package.path .. ";../mcp/worker/?.lua"
local json = require("json")
local calc = require("calc")

io.stdout:setvbuf("line")
-- Signal readiness so the parent knows data load finished.
io.write(json.encode({ ready = true }) .. "\n")

for line in io.lines() do
  if line ~= "" then
    local ok, result = pcall(function()
      local req = json.decode(line)
      return calc.handle(req)
    end)
    if ok then
      io.write(json.encode({ ok = true, output = result }) .. "\n")
    else
      io.write(json.encode({ ok = false, error = tostring(result) }) .. "\n")
    end
  end
end
```

- [ ] **Step 2: Manually verify the loop (state-leak check)**

Run (sends the same build twice; DPS must be identical → no global cache leak):
```bash
BUILD_PATH="$(grep 'build file' mcp/spike/GOLDEN.md | sed 's/.*: //')"
XML="$(python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1]).read()))' "$BUILD_PATH")"
printf '{"buildXml":%s}\n{"buildXml":%s}\n' "$XML" "$XML" | (cd src && CI=1 luajit ../mcp/worker/server.lua)
```
Expected: first line `{"ready":true}`, then two response lines with **identical** `FullDPS`. Differing values = state leak; fix `loadBuild` to fully reset before proceeding.

- [ ] **Step 3: Commit**

```bash
git add mcp/worker/server.lua
git commit -m "feat(worker): persistent stdin/stdout JSON server loop + leak check"
```

---

## Phase 2 — Thin TS MCP server (`calc_topline`)

### Task 7: Node project scaffold + worker child wrapper

**Files:**
- Create: `mcp/server/package.json`
- Create: `mcp/server/tsconfig.json`
- Create: `mcp/server/src/worker.ts`
- Test: `mcp/server/test/topline.test.ts`

- [ ] **Step 1: Scaffold the Node project**

Create `mcp/server/package.json`:
```json
{
  "name": "pob2-damage-calc-mcp",
  "version": "0.1.0",
  "type": "module",
  "bin": { "pob2-damage-calc-mcp": "dist/index.js" },
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "start": "tsx src/index.ts"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "typescript": "^5.5.0",
    "tsx": "^4.16.0",
    "vitest": "^2.0.0"
  }
}
```

Create `mcp/server/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "Bundler",
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

Run:
```bash
cd mcp/server && npm install && cd ../..
```
Expected: dependencies install without error.

- [ ] **Step 2: Write the failing TS test**

Create `mcp/server/test/topline.test.ts`:
```ts
import { describe, it, expect, afterAll } from "vitest";
import { Worker } from "../src/worker.js";
import { readFileSync } from "node:fs";

const repoRoot = new URL("../../../", import.meta.url).pathname;
const golden = readFileSync(`${repoRoot}mcp/spike/GOLDEN.md`, "utf8");
const buildPath = /build file: (.+)/.exec(golden)![1].trim();
const guiFullDPS = parseFloat(/GUI FullDPS: (.+)/.exec(golden)![1].trim());
const buildXml = readFileSync(buildPath, "utf8");

const worker = new Worker(repoRoot);

afterAll(() => worker.dispose());

describe("Worker.calc", () => {
  it("returns FullDPS within 1% of the GUI golden", async () => {
    const out = await worker.calc({ buildXml });
    expect(out.FullDPS).toBeGreaterThan(0);
    expect(Math.abs(out.FullDPS - guiFullDPS) / guiFullDPS).toBeLessThan(0.01);
  });
});
```

- [ ] **Step 3: Run it to verify it fails**

Run:
```bash
cd mcp/server && npx vitest run && cd ../..
```
Expected: FAIL — cannot find `../src/worker.js`.

- [ ] **Step 4: Write the worker child wrapper**

Create `mcp/server/src/worker.ts`:
```ts
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { createInterface, type Interface } from "node:readline";

export interface Topline {
  FullDPS: number; TotalDPS: number; CombinedDPS: number; AverageDamage: number;
  BleedDPS: number; IgniteDPS: number; PoisonDPS: number; CritChance: number; Speed: number;
}
export interface CalcRequest {
  buildXml: string;
  patch?: { config?: Record<string, unknown>; enemyLevel?: number; treeURL?: string };
}

// Spawns the persistent luajit worker (boots PoB once) and serializes requests.
export class Worker {
  private proc: ChildProcessWithoutNullStreams;
  private rl: Interface;
  private queue: Array<(line: string) => void> = [];
  private ready: Promise<void>;

  constructor(repoRoot: string) {
    this.proc = spawn("luajit", ["../mcp/worker/server.lua"], {
      cwd: `${repoRoot}src`,
      env: { ...process.env, CI: "1" },
    });
    this.rl = createInterface({ input: this.proc.stdout });
    let signalReady: () => void;
    this.ready = new Promise((r) => (signalReady = r));
    this.rl.on("line", (line) => {
      const obj = JSON.parse(line);
      if (obj.ready) { signalReady(); return; }
      const resolve = this.queue.shift();
      if (resolve) resolve(line);
    });
  }

  async calc(req: CalcRequest): Promise<Topline> {
    await this.ready;
    const line = await new Promise<string>((resolve) => {
      this.queue.push(resolve);
      this.proc.stdin.write(JSON.stringify(req) + "\n");
    });
    const obj = JSON.parse(line);
    if (!obj.ok) throw new Error(`worker error: ${obj.error}`);
    return obj.output as Topline;
  }

  dispose() { this.proc.kill(); }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run:
```bash
cd mcp/server && npx vitest run && cd ../..
```
Expected: PASS (FullDPS within 1%). First run is slow (engine boot).

- [ ] **Step 6: Commit**

```bash
git add mcp/server/package.json mcp/server/tsconfig.json mcp/server/src/worker.ts mcp/server/test/topline.test.ts mcp/server/package-lock.json
git commit -m "feat(mcp): node scaffold + luajit worker child wrapper (GUI-validated test)"
```

### Task 8: Expose `calc_topline` over MCP stdio

**Files:**
- Create: `mcp/server/src/index.ts`

- [ ] **Step 1: Write the MCP server**

Create `mcp/server/src/index.ts`:
```ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFileSync } from "node:fs";
import { Worker } from "./worker.js";

const repoRoot = new URL("../../../", import.meta.url).pathname;
const worker = new Worker(repoRoot);

const server = new McpServer({ name: "pob2-damage-calc", version: "0.1.0" });

server.tool(
  "calc_topline",
  "Compute top-line DPS for a PoB2 build. Provide the build as a file path (buildPath) " +
    "or raw XML (buildXml). Optional patch: { config, enemyLevel, treeURL }.",
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
    const xml = buildXml ?? readFileSync(buildPath!, "utf8");
    const out = await worker.calc({ buildXml: xml, patch });
    return { content: [{ type: "text", text: JSON.stringify(out, null, 2) }] };
  },
);

await server.connect(new StdioServerTransport());
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
cd mcp/server && npm run build && cd ../..
```
Expected: `tsc` exits 0, `dist/index.js` produced.

- [ ] **Step 3: Manual MCP smoke (optional but recommended)**

Run the inspector or a manual stdio handshake:
```bash
cd mcp/server && npx @modelcontextprotocol/inspector node dist/index.js
```
Expected: inspector lists `calc_topline`; calling it with `{ "buildPath": "<golden path>" }` returns the DPS JSON.

- [ ] **Step 4: Commit**

```bash
git add mcp/server/src/index.ts
git commit -m "feat(mcp): expose calc_topline over MCP stdio transport"
```

### Task 9: Register the MCP server + document usage

**Files:**
- Modify: `.mcp.json`
- Create: `mcp/README.md`

- [ ] **Step 1: Add the server to `.mcp.json`**

Add this entry under `mcpServers` in `.mcp.json` (read the file first; merge, don't overwrite siblings):
```json
"pob2-damage-calc": {
  "command": "node",
  "args": ["mcp/server/dist/index.js"]
}
```

- [ ] **Step 2: Write usage docs**

Create `mcp/README.md`:
```markdown
# PoB2 Damage Calc MCP (Slice 1)

Headless PoB DPS for chat build consultation. Boots the PoB engine once, serves
`calc_topline`.

## Build
    cd mcp/server && npm install && npm run build

## Tools
- `calc_topline({ buildPath | buildXml, patch? })` → top-line DPS JSON.
  - patch: `{ config?: {key:value}, enemyLevel?: number, treeURL?: string }`

## Tests
- Lua unit:    `eval "$(luarocks --lua-version 5.1 path)"; busted test/unit/test_calc_readout.lua`
- Integration: `./test/integration/smoke_eow.sh`  (validates headless == GUI golden)
- TS:          `cd mcp/server && npx vitest run`

Golden reference: `mcp/spike/GOLDEN.md`.
```

- [ ] **Step 3: Commit**

```bash
git add .mcp.json mcp/README.md
git commit -m "chore(mcp): register pob2-damage-calc server + usage docs"
```

---

## Self-Review (completed during authoring)

- **Spec coverage (Slice 1 subset):** purpose/round-trip premise → handled by reusing engine + GUI-golden validation; architecture (persistent worker + thin TS MCP) → Tasks 6–8; Step 0 spike + GUI oracle → Tasks 1–5; `calc_topline` → Task 8; patch (config/enemyLevel/tree-replace) → Task 5; output keys → Task 4. Deferred-and-noted: `calc_breakdown`/`calc_compare`/`export_build`, gem/item patch, name→id (Slice 2).
- **Placeholder scan:** none — every code step is complete. The one verification note (treeTab/configTab member names in Task 5) is an explicit during-task check, not a missing implementation.
- **Type consistency:** `Topline` keys (`FullDPS`…`Speed`) match `TOPLINE_KEYS` in `calc.lua`; `CalcRequest.patch` shape matches `applyPatch`'s `{config, enemyLevel, treeURL}`; worker response envelope `{ok, output|error}` matches `Worker.calc` parsing.

## Future plans (not in this file)
- **Slice 2:** `calc_breakdown` (6-stage + per-type multipliers), `calc_compare` (base+delta), `export_build` (`SaveDB("code")` round-trip), gem/item patching, name→id resolution.
