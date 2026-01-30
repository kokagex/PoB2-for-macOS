#!/bin/bash
#
# Path of Building 2 for macOS - Launch Script
#

cd "$(dirname "$0")"

echo "==================================="
echo "  Path of Building 2 for macOS"
echo "==================================="
echo ""
echo "Starting application..."
echo "Press Ctrl+C or close the window to exit"
echo ""

luajit pob2_launch.lua

echo ""
echo "Application closed"
