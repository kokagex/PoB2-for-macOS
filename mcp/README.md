# PoB2 Damage Calc MCP (Slice 1)

Headless Path of Building 2 DPS for chat build consultation. A long-lived
`luajit` worker boots the real PoB calc engine once, then answers calc requests;
a thin TypeScript MCP server exposes them as tools. **No PoB calc code is
modified** — only headless host stubs in `src/HeadlessWrapper.lua`.

## Layout
- `worker/`  — luajit worker (boots PoB, JSON-line protocol on stdin/stdout)
  - `run.sh`     launcher: sets luarocks paths (lua-utf8), cwd=src/, CI=1
  - `boot.lua`   headless engine bootstrap
  - `calc.lua`   loadBuild / applyPatch / readTopline / handle
  - `server.lua` request loop
  - `json.lua`   dkjson wrapper
- `server/`  — TypeScript MCP server (`@modelcontextprotocol/sdk`, stdio)
- `spike/GOLDEN.md` — validation golden (build + baseline DPS)

## Prerequisites
- `luajit` on PATH (`brew install luajit`)
- luarocks 5.1 with `luautf8`: `luarocks --lua-version 5.1 install luautf8`
- Node 18+

## Build
    cd mcp/server && npm install && npm run build

## Tools
All take a build via `buildPath` or `buildXml`, plus an optional `patch`:
`{ config?: {key: value}, enemyLevel?: number, treeURL?: string }`
(`treeURL` replaces the whole passive tree — a node set, no pathing issues).

- `calc_topline(...)` → top-line DPS (`FullDPS, TotalDPS, CombinedDPS,
  AverageDamage, BleedDPS, IgniteDPS, PoisonDPS, CritChance, Speed`).
- `calc_breakdown(...)` → richer set: crit (chance/multi/effect), speed, hit
  chance, per-damage-type hit averages, DoT, mana/life cost — for explaining
  "why this number" and finding levers.
- `calc_compare({ ..., patchA?, patchB })` → per-metric `{ a, b, delta, pct }`
  ("how much does this change help?"). `patchA` omitted = build as-is.
- `export_build(...)` → PoB import code (base64 `eNr…`) to paste into the GUI.
  Round-trip verified: regenerated code reloads to an identical DPS.

## Tests
- Lua unit:    `eval "$(luarocks --lua-version 5.1 path)"; busted test/unit/test_calc_readout.lua`
- Integration: `./test/integration/smoke_calc.sh`  (headless == recorded baseline)
- TS:          `cd mcp/server && npx vitest run`

## Notes
- `FullDPS` is 0 unless the build's skills are flagged "include in Full DPS";
  `TotalDPS` is the robust hit-DPS oracle.
- GUI cross-check (anti-hallucination) is a manual gate — see `spike/GOLDEN.md`.

## ⚠️ Upstream-synced file edit (re-apply after any `src/` sync)
Headless calc needs one edit to the upstream-synced `src/HeadlessWrapper.lua`
that an upstream re-sync will drop — re-apply it:
- **`ConPrintf`**: wrap `string.format` in `pcall` (the real C ConPrintf tolerates
  nil/mismatched args; the Lua stub crashes Init otherwise). Must live in
  HeadlessWrapper because it is defined there mid-load.

The `ResetViewport` no-op stub is pre-injected in `worker/boot.lua` (not in
HeadlessWrapper), so it survives syncs on its own.

## Out of scope (future)
- gem / item patching (currently patch = config + enemyLevel + full-tree replace)
- name→id resolution for individual passive nodes / gems / items
- defense / EHP (CalcDefence)
