#!/usr/bin/env bash
# Integration smoke + regression guard for the headless calc worker:
#   1. baseline TotalDPS matches the recorded golden (within 1%)
#   2. a config patch (buffAdrenaline: +100% inc damage, +25% cast speed) actually
#      moves TotalDPS  -> guards against the silent no-op patch bug
#   3. a following baseline call reverts  -> guards against state leak
# (GUI cross-check is a separate manual gate; see mcp/spike/GOLDEN.md.)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GOLDEN="$ROOT/mcp/spike/GOLDEN.md"
BUILD_PATH="$(grep 'build file:' "$GOLDEN" | sed 's/.*build file: //')"
BASELINE="$(grep 'TotalDPS:' "$GOLDEN" | head -1 | sed 's/.*TotalDPS:[[:space:]]*//; s/[[:space:]].*//')"

XML="$(python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1]).read()))' "$BUILD_PATH")"
OUT="$(printf '{"buildXml":%s}\n{"buildXml":%s,"patch":{"config":{"buffAdrenaline":true}}}\n{"buildXml":%s}\n' "$XML" "$XML" "$XML" \
  | "$ROOT/mcp/worker/run.sh" 2>/dev/null | grep -o '"TotalDPS":[0-9.]*' | sed 's/"TotalDPS"://')"

BASE1="$(echo "$OUT" | sed -n '1p')"
PATCHED="$(echo "$OUT" | sed -n '2p')"
BASE2="$(echo "$OUT" | sed -n '3p')"
echo "base=$BASE1  patched(buffAdrenaline)=$PATCHED  base-again=$BASE2  golden=$BASELINE"

awk -v base="$BASE1" -v patched="$PATCHED" -v base2="$BASE2" -v golden="$BASELINE" 'BEGIN{
  if (base=="" || patched=="" || base2=="") { print "MISSING value"; exit 1 }
  d=(base>golden)?(base-golden):(golden-base);
  if (golden==0 || d/golden>0.01) { print "FAIL: baseline != golden"; exit 1 }
  if (patched <= base*1.10) { print "FAIL: patch had no effect (silent no-op)"; exit 1 }
  if (base2 != base) { print "FAIL: state leak (base-again != base)"; exit 1 }
  print "PASS: golden match + patch effective + no leak"
}'
