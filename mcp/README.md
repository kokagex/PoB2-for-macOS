# PoB2Advisor MCP

Headless Path of Building 2 for chat build consultation: real-engine DPS calc
plus read access to the full game database (gems, uniques, item bases, passive
tree). A long-lived `luajit` worker boots the real PoB calc engine once, then
answers requests; a thin TypeScript MCP server exposes them as tools. **No PoB
calc code is modified** — only headless host stubs in `src/HeadlessWrapper.lua`.

## Layout
- `worker/`  — luajit worker (boots PoB, JSON-line protocol on stdin/stdout)
  - `run.sh`     launcher: sets luarocks paths (lua-utf8), cwd=src/, CI=1
  - `boot.lua`   headless engine bootstrap
  - `calc.lua`   loadBuild / applyPatch / readTopline / readInfo / handle
  - `query.lua`  build-independent game-data queries (data_* ops)
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

## Calc tools
All take a build via `buildPath` or `buildXml`, plus an optional `patch`:

    { config?: {key: value}, enemyLevel?: number, treeURL?: string,
      skillName?: string,
      items?: [{ slot, raw }],            // equip raw PoB item text
      gems?: [{ name, group?, level?, quality?, enabled?, remove? }],
      allocNodes?: [name | id, ...],      // incremental tree edits;
      deallocNodes?: [name | id, ...] }   // alloc pays the travel path

`treeURL` replaces the whole passive tree; `allocNodes`/`deallocNodes` edit it
incrementally (exact node name, case-insensitive, or numeric id — ambiguous
names error with the candidate ids). `items[].raw` accepts the `raw` field
from `data_uniques` detail verbatim; `items[].slot` also accepts tree jewel
sockets as `Jewel <nodeId>` (the socket node must be allocated — `build_info`
lists allocated socket ids under `passives.sockets`). `gems` edits socket
groups: a name already in the target group is modified (level/quality/enabled)
or removed; an absent name is added (exact match against the gem database).
`group` is a 1-based index or a gem name in the group; default is the main
group. All resolution failures are hard errors, never silently ignored.

- `calc_topline(...)` → top-line DPS (`FullDPS, TotalDPS, CombinedDPS,
  AverageDamage, BleedDPS, IgniteDPS, PoisonDPS, CritChance, Speed`).
- `calc_breakdown(...)` → richer set: crit (chance/multi/effect), speed, hit
  chance, per-damage-type hit averages, DoT, costs, defence/EHP — for
  explaining "why this number" and finding levers.
- `calc_compare({ ..., patchA?, patchB, metrics? })` → per-metric
  `{ a, b, delta, pct }` ("how much does this change help?"). `patchA`
  omitted = build as-is. `metrics`: `offence` (default, DPS top-line),
  `defence` (EHP-first: EHP, life/ES, resists, max hits, block), `full`.
- `build_info(...)` → structural summary: character, items per slot, socket
  groups with gems, keystones/notables, config. Patch applies first, so it
  also previews variants.
- `export_build(...)` → PoB import code (base64 `eNr…`) to paste into the GUI.
  Round-trip verified: regenerated code reloads to an identical DPS.

## Data tools (no build needed)
List modes return `{ total, returned, results }` (default limit 20) so a
capped list is never mistaken for the full set; detail lookups by exact name
hard-error when nothing matches.

- `data_gems({ search?, gemType?, name?, limit? })` — gem database; detail
  (`name`) returns requirements, description, granted effects, per-level costs.
- `data_uniques({ search?, textSearch?, type?, name?, limit? })` — unique
  database; `textSearch` greps mod text; detail returns implicits/mods plus
  `raw`, ready for `patch.items`.
- `data_passives({ search?, type?, ascendancy?, version?, limit? })` —
  passive tree; `version` selects the tree version (e.g. `0_4`, default
  latest; unknown versions error listing the valid set); `search` matches
  names and stat lines; returns ids for `patch.allocNodes`.
- `data_itembases({ search?, type?, subType?, limit? })` — item bases with
  armour/weapon stats.

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
- PoE1 残存データの照会 (翻訳ルール同様 PoE2 のみ対象)
