#!/usr/bin/env bash
# Integration smoke + regression guard for the headless calc worker.
# Loads the golden build through the worker and asserts TotalDPS matches the
# recorded baseline within 1%. (GUI cross-check is a separate manual gate; see
# mcp/spike/GOLDEN.md.)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GOLDEN="$ROOT/mcp/spike/GOLDEN.md"
BUILD_PATH="$(grep 'build file:' "$GOLDEN" | sed 's/.*build file: //')"
BASELINE="$(grep 'TotalDPS:' "$GOLDEN" | head -1 | sed 's/.*TotalDPS:[[:space:]]*//; s/[[:space:]].*//')"

XML="$(python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1]).read()))' "$BUILD_PATH")"
RESP="$(printf '{"buildXml":%s}\n' "$XML" | "$ROOT/mcp/worker/run.sh" 2>/dev/null | tail -1)"
echo "worker response: $RESP"

TOTAL="$(printf '%s' "$RESP" | sed -n 's/.*"TotalDPS":\([0-9.eE+-]*\).*/\1/p')"
echo "headless TotalDPS=$TOTAL  baseline=$BASELINE"

awk -v a="$TOTAL" -v b="$BASELINE" 'BEGIN{
  if (a == "" || b == "") { print "MISSING value"; exit 1 }
  d = (a>b)?(a-b):(b-a);
  if (b == 0 || d/b > 0.01) { print "MISMATCH > 1%"; exit 1 }
  print "MATCH within 1%"
}'
