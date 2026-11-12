#!/usr/bin/env python3
"""Publishes the place to Roblox with the Open Cloud Place Publishing API.

    python3 tools/publish.py <universeId> <placeId> [--saved]

Reads the API key from /root/.roblox-api-key (never from the command line or
the repo). Builds the place first. --saved uploads as a saved version only
(not live in servers); default publishes. Publishing does NOT change the
experience's privacy: a new experience stays private until set public.
"""
import os
import subprocess
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.environ.get("ROBLOX_API_KEY_FILE", "/root/.roblox-api-key")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2 or not all(a.isdigit() for a in args):
        sys.exit("usage: publish.py <universeId> <placeId> [--saved]")
    universe, place = args
    version_type = "Saved" if "--saved" in sys.argv else "Published"
    with open(KEY_FILE, encoding="utf-8") as fh:
        key = fh.read().strip()
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "build_rbxlx.py")], check=True)
    with open(os.path.join(ROOT, "build", "WorldMartialArtsTycoon.rbxlx"), "rb") as fh:
        body = fh.read()
    url = f"https://apis.roblox.com/universes/v1/{universe}/places/{place}/versions?versionType={version_type}"
    req = urllib.request.Request(url, data=body, method="POST", headers={"x-api-key": key, "Content-Type": "application/xml"})
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            print(resp.status, resp.read().decode())
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read().decode()}")
    print(f"https://www.roblox.com/games/{place}")


if __name__ == "__main__":
    main()
