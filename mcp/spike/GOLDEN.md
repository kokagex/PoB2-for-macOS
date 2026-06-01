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

## GUI cross-check (anti-hallucination oracle)
> PENDING user confirmation. Open Lich_FotV in PathOfBuilding.app and record the
> sidebar values. Headless must match within 1%.

- GUI Total DPS: <pending>
- GUI Full DPS:  <pending>
