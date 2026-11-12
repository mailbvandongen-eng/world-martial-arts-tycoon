#!/bin/sh
# Runs every offline check. From the project root:  sh tools/test.sh
set -e
python3 tools/check.py
lua5.4 tests/run.lua | tail -2
lua5.4 tests/data_safety.lua | tail -1
lua5.4 tests/audit_geometry.lua | tail -1
python3 tools/build_rbxlx.py
