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

- skillName "Eye of Winter" -> TotalDPS: 576.5486741573

Unknown names must be a hard worker error ("not found in build" + gem list),
never silently ignored — that silent ignore was the original calc bug.

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
