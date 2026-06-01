#!/usr/bin/env bash
# Launch the headless PoB calc worker.
#   * resolves the repo root from this script's location
#   * puts luarocks 5.1 libs (lua-utf8) on LUA_PATH/LUA_CPATH
#   * runs with cwd = src/ and CI=1 (skip ModCache)
# Speaks the worker JSON protocol on stdin/stdout (see server.lua).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
eval "$(luarocks --lua-version 5.1 path)"
cd "$ROOT/src"
exec env CI=1 luajit ../mcp/worker/server.lua
