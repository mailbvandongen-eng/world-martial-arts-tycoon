#!/bin/sh
# Runs every offline check. From the project root:  sh tools/test.sh
set -e
python3 tools/check.py
lua5.4 tests/run.lua | tail -2
python3 tools/build_rbxlx.py
