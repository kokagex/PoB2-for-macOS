# Headless calc — validation golden

Regression baseline for the headless calc worker and MCP server tests.

- build file: mcp/server/test/fixtures/golden_build.xml
- class: Sorceress / Chronomancer (Chrono_RotA snapshot)
- date: 2026-06-07

The build XML is snapshotted INTO the repo (fixtures/). Earlier goldens pointed
at the user's live PoB build folder, and the referenced file got overwritten by
a different build in the GUI, silently invalidating the baseline (discovered
2026-06-07). Tests must never depend on files PoB itself rewrites.

## Headless-measured baseline (regression guard)
Produced by `mcp/worker/server.lua` (no patch). Saved main skill group is 5
(Orb of Storms):

- TotalDPS:      5138.74456875   <- primary oracle (hit DPS)

## patch.skillName golden
Selecting the main skill by gem name (case-insensitive). Cross-checked exactly
(diff = 0) against the sed workaround that rewrote mainSocketGroup in the XML:

- skillName "Eye of Winter" -> TotalDPS: 458.86838961039

Re-baselined 2026-06-19 after the upstream 0.5.2 data sync (v0.18.0 → v0.21.0):
0.5.2 reworked the Biting Frost / Ice Bite cold support gems (SkillConsumesFreeze
/ SupportedByBitingFrost skill types), which lowered this build's Eye of Winter
hit DPS from 576.5486741573 → 458.86838961039 (-20.4%). Confirmed a faithful data
change, NOT a calc-merge defect: reverting the calc-layer sync (CalcOffence /
CalcActiveSkill et al.) left the value at 458.15 (the calc merge moves it only
0.16%), and the synced data files (act_int / sup_int / SkillStatMap) match
upstream v0.21.0 byte-for-byte. The primary oracle (Orb of Storms 5138.74) stayed
within 1%, so it is left as-is.

Unknown names must be a hard worker error ("not found in build" + gem list),
never silently ignored — that silent ignore was the original calc bug.

## Minion-DPS golden (added 2026-06-27)
Minion/summon builds put ~0 in the player DPS keys and the real damage in the
minion sub-table (mainOutput.Minion), which PoB saves as <MinionStat>. The
worker now surfaces it via Minion* keys + EffectiveDPS (= player CombinedDPS +
minion CombinedDPS, mirroring CalcsTab.lua:693).

- fixture: mcp/server/test/fixtures/golden_minion_build.xml
  (Chrono_RotA snapshot, saved main group = Navira / Water Djinn summon)
- MinionCombinedDPS: 151802.31538745  <- minion-build regression oracle
- player CombinedDPS == 0, EffectiveDPS == MinionCombinedDPS for this build

On a pure-player build (golden_build.xml, Orb of Storms) every Minion* key is 0
and EffectiveDPS collapses to the player CombinedDPS — verified by the
"leaves a pure-player build unchanged" test, so the change is non-breaking.

## build_info observation surfaces (added 2026-06-27)
build_info (calc.lua readInfo) gained two surfaces so advice can see the levers
that piecewise item lists hide — added after a top-tier minion build's ~8.5x DPS
edge was traced to its passive tree and a confident "tree isn't the lever"
conclusion turned out wrong (the tree IS decisive: reverting only the tree on the
real build dropped minion DPS −26.5%, crit 61→46).

- **passives.jewelSockets**: per allocated jewel socket, `{ socket, slot, jewel,
  base, radius, notableCount, totalAllocInRadius, totalInRadius, notables[] }`.
  radius jewels (Time-Lost Sapphire) grant "Notable Passive Skills in Radius also
  grant ..." to every ALLOCATED notable in radius, so notableCount (allocated-only)
  is the multiplier. The engine's `spec.nodes[socketId].nodesInRadius[item
  .jewelRadiusIndex]` (populated at build load; no re-parse) is GEOMETRIC — every
  node physically in range — so it is filtered by `spec.allocNodes`. This filter
  is load-bearing: without it two trees with the same socket geometry report the
  same count and the tree's role is invisible (the bug that made "tree isn't the
  lever" look true). totalInRadius = geometric upper bound; totalAllocInRadius =
  allocated nodes in radius. Non-radius jewels have no `radius` field, count 0.
- **items[].mods**: each item's resolved mod lines `{ kind, text }` (kind =
  enchant/implicit/explicit/rune). On a normal load `modLine.line` already carries
  the rolled value, so the text is the reliable signal (the stored ModRange scalar
  is uniformly 0.5 metadata on game-copied items and is NOT surfaced).

- fixture: mcp/server/test/fixtures/golden_toptier_build.xml
  (the user's "sample" ideal — Disciple of Varashta / Navira summon, ~1.3M minion
  DPS, two Time-Lost Sapphires). Tested in test/build-info.test.ts:
  - the two Time-Lost sockets show radius "Very Large" and allocated notableCount
    21984 → 12, 61419 → 4 (re-baseline on an upstream tree-data sync, like the DPS
    goldens), each strictly below its geometric totalInRadius (filter is live).
  - swapping in the current tree (same jewels) drops these to 3 + 2 = 5 allocated
    notables — the surfaced form of the −26.5% / crit 61→46 tree lever.
  - the current build's (golden_minion_build.xml) plain Sapphires show no radius,
    notableCount 0 — the differential that explains the crit gap, made legible.

---

## History: 2026-06-01 golden (Lich_FotV) — INVALIDATED

Original golden was the user's live `Lich_FotV.xml` (Witch / Abyssal Lich, main
skill Ice Nova): TotalDPS(old) 25062.573899264, AverageDamage(old)
14001.437932549, CritChance(old) 56.52, Speed(old) 1.79, FullDPS(old) 0.

Two oracles from that round remain valid as one-time confirmations of the
engine glue (the conclusions hold even though the build file is gone):

- **GUI cross-check (anti-hallucination) — CONFIRMED 2026-06-01**: headless
  matched the PoB GUI sidebar to displayed precision (Hit DPS 25,062.6 /
  Average Hit 14,001.4 / Crit 56.52% / Cast Speed 1.79). GUI headline
  "ヒットDPS" == headless TotalDPS. FullDPS=0 was faithful (GUI showed no Full
  DPS line; no skill flagged "include in Full DPS").
- **export_build round-trip — CONFIRMED IN REAL PoB GUI 2026-06-01**: the
  export code imported cleanly with identical numbers. The "older tree version
  (0_4)" warning was a property of the original build, not a round-trip defect.

The file at `~/Library/Application Support/Path of Building/Builds/Lich_FotV.xml`
was overwritten in the GUI with the Chronomancer build sometime before
2026-06-06 18:58 (identical bytes to Chrono_RotA.xml); the original Lich build
XML is not recoverable from disk.
