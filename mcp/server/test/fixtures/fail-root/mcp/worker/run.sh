#!/bin/sh
# Simulates the real worker dying at boot (e.g. luarocks/luajit missing).
echo "luarocks: command not found" >&2
exit 1
