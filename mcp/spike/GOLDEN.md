# Headless calc — validation golden

Build used for the feasibility spike and the regression smoke test.

- build file: /Users/kokage/Library/Application Support/Path of Building/Builds/Lich_FotV.xml
- class: Witch / Abyssal Lich
- date: 2026-06-01

## Headless-measured baseline (regression guard)
Produced by `mcp/worker/server.lua` (no patch):

- TotalDPS:      25062.573899264   <- primary oracle (hit DPS)
- CombinedDPS:   25062.573899264
- AverageDamage: 14001.437932549
- CritChance:    56.52
- Speed:         1.79
- FullDPS:       0   <- depends on per-skill "include in Full DPS" flags; 0 here

## GUI cross-check (anti-hallucination oracle) — CONFIRMED 2026-06-01
Read from the PoB GUI sidebar (main skill: アイスノヴァ / Ice Nova). Headless
matches the GUI to displayed precision -- the tool is correct, not just
reproducible.

| metric        | GUI        | headless         | verdict |
|---------------|------------|------------------|---------|
| Hit DPS       | 25,062.6   | 25062.573899264  | match   |
| Average Hit   | 14,001.4   | 14001.437932549  | match   |
| Crit Chance   | 56.52%     | 56.52            | match   |
| Cast Speed    | 1.79       | 1.79             | match   |
| Full DPS      | (not shown)| 0                | faithful: GUI shows no Full DPS line (no skill flagged "include in Full DPS") |

Note: the GUI headline figure is "ヒットDPS" (Hit DPS) == headless TotalDPS.
FullDPS=0 is faithful here, not a bug.
