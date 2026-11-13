#!/usr/bin/env python3
"""Uploads assets/audio/*.wav as Audio to the owner's Roblox account with the
Open Cloud Assets API and writes the ids into src/shared/Config/Audio.lua.

    python3 tools/upload_audio.py [name ...]     (default: all with id 0)

Needs the API key in /root/.roblox-api-key (assets read + write).
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "src", "shared", "Config", "Audio.lua")
KEY_FILE = os.environ.get("ROBLOX_API_KEY_FILE", "/root/.roblox-api-key")
CREATOR_USER_ID = "11982556231"  # Visunit66


def request(method, url, key, body=None, content_type=None):
    headers = {"x-api-key": key}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        raise SystemExit(f"HTTP {e.code} for {url}: {e.read().decode()}")


def upload(name, key):
    path = os.path.join(ROOT, "assets", "audio", name + ".wav")
    meta = {
        "assetType": "Audio",
        "displayName": "WMAT " + name.replace("_", " "),
        "description": "World Martial Arts Tycoon sound effect (original, generated).",
        "creationContext": {"creator": {"userId": CREATOR_USER_ID}},
    }
    boundary = uuid.uuid4().hex
    with open(path, "rb") as fh:
        data = fh.read()
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n".encode()
        + json.dumps(meta).encode()
        + f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.wav\"\r\nContent-Type: audio/wav\r\n\r\n".encode()
        + data
        + f"\r\n--{boundary}--\r\n".encode()
    )
    op = request("POST", "https://apis.roblox.com/assets/v1/assets", key, body, f"multipart/form-data; boundary={boundary}")
    op_path = op.get("path") or ("operations/" + op.get("operationId", ""))
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", "https://apis.roblox.com/assets/v1/" + op_path, key)
    asset_id = (op.get("response") or {}).get("assetId")
    if not asset_id:
        raise SystemExit(f"upload of {name} did not finish: {op}")
    return int(asset_id)


def main():
    with open(KEY_FILE, encoding="utf-8") as fh:
        key = fh.read().strip()
    with open(CONFIG, encoding="utf-8") as fh:
        config = fh.read()
    ids = dict((k, int(v)) for k, v in re.findall(r"^\t(\w+) = \{ id = (\d+),", config, re.M))
    names = sys.argv[1:] or [n for n, v in ids.items() if v == 0]
    for name in names:
        asset_id = upload(name, key)
        config = re.sub(rf"^(\t{name} = \{{ id = )\d+,", rf"\g<1>{asset_id},", config, flags=re.M)
        with open(CONFIG, "w", encoding="utf-8") as fh:
            fh.write(config)
        print(f"{name}: {asset_id}", flush=True)


if __name__ == "__main__":
    main()
