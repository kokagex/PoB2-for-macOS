#!/usr/bin/env bash
# 起動 smoke テスト: dist アプリを起動し、起動〜ビルド読み込みで Lua エラーが
# 出ていないかログで機械検知する。
#
# 背景 (2026-06-10): DropDownControl の修正が constructor 初期化順と衝突し、
# 起動時に "attempt to compare number with nil" のエラーダイアログが出たが、
# ユニットテスト(111件)は全パスでログの目視確認漏れで見逃した。
# 実行時にしか発火しない UI 層のエラーはこの smoke テストが最後の網。
#
# 使い方: bash scripts/smoke-test.sh [待ち秒数 (default 20)]
# 終了コード: 0 = エラーなし / 1 = Lua エラー検知 / 2 = 起動失敗
set -uo pipefail

WAIT="${1:-20}"
LOG="$HOME/Library/Logs/pob2macos/passive_tree_app.log"
APP="dist/PathOfBuilding.app"
MARKER="--- smoke-test $(date +%s) ---"

if [[ ! -d "$APP" ]]; then
  echo "ERROR: $APP がない (先に scripts/build-app.sh --release を実行)" >&2
  exit 2
fi

# 既存プロセスを落としてから起動
pkill -f "pob2_launch.lua" 2>/dev/null && sleep 1
echo "$MARKER" >> "$LOG"
open "$APP"
echo "==> 起動して ${WAIT}s 待機..."
sleep "$WAIT"

if ! pgrep -f "pob2_launch.lua" > /dev/null; then
  echo "FAIL: アプリプロセスが ${WAIT}s 以内に終了した (クラッシュの可能性)" >&2
  exit 2
fi

# マーカー以降のログから Lua エラーの兆候を検知
ERRORS=$(awk -v m="$MARKER" 'index($0, m){found=1; next} found' "$LOG" \
  | grep -aE "FULL ERROR MESSAGE|stack traceback|attempt to |ERROR: Failed" || true)

pkill -f "pob2_launch.lua" 2>/dev/null

if [[ -n "$ERRORS" ]]; then
  echo "FAIL: 起動ログに Lua エラーを検知:" >&2
  echo "$ERRORS" | head -10 >&2
  exit 1
fi

echo "OK: 起動〜${WAIT}s で Lua エラーなし"
