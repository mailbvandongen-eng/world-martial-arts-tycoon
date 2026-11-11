#!/usr/bin/env python3
"""Static checks for the Roblox source tree (no Roblox Studio needed).

1. Every .lua file parses (luac5.4 -p). The code base is written in the
   common subset of Luau and Lua 5.4, so a parse error is a real error.
2. No Lua-5.4-only syntax that Luau rejects (goto, labels, bitwise ops, <const>).
3. Every require(...) resolves to an existing ModuleScript (Rojo layout).
4. Remote names, server actions, UI panels, Notify kinds, prop keys and
   materials referenced anywhere actually exist.

Run from the project root:  python3 tools/check.py
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
errors = []


def err(msg):
    errors.append(msg)


def lua_files():
    for base, _, files in os.walk(SRC):
        for f in sorted(files):
            if f.endswith(".lua"):
                yield os.path.join(base, f)


def read(p):
    with open(p, encoding="utf-8") as fh:
        return fh.read()


def strip_comments_strings(code):
    # remove long comments, line comments and string literals (rough but good enough)
    code = re.sub(r"--\[(=*)\[.*?\]\1\]", "", code, flags=re.S)
    code = re.sub(r"--[^\n]*", "", code)
    code = re.sub(r'"(\\.|[^"\\])*"', '""', code)
    code = re.sub(r"'(\\.|[^'\\])*'", "''", code)
    return code


# ---------------------------------------------------------------- 1 + 2
for path in lua_files():
    rel = os.path.relpath(path, ROOT)
    r = subprocess.run(["luac5.4", "-p", path], capture_output=True, text=True)
    if r.returncode != 0:
        err(f"syntax: {r.stderr.strip()}")
    code = strip_comments_strings(read(path))
    for pattern, what in [
        (r"\bgoto\b", "goto"),
        (r"::\w+::", "label"),
        (r"<const>|<close>", "attribute"),
        (r"[^<>=~]<<|>>[^=]", "bit shift"),
        (r"[\w\)\]]\s*&\s*[\w\(]", "bitwise and"),
        (r"[\w\)\]]\s*\|\s*[\w\(]", "bitwise or"),
        (r"[\w\)\]]\s*~\s*[\w\(]", "bitwise xor"),
    ]:
        m = re.search(pattern, code)
        if m:
            err(f"{rel}: Lua 5.4-only syntax not supported by Luau ({what}): ...{m.group(0)}...")

# ---------------------------------------------------------------- 3 requires
# Instance tree from the Rojo project: ReplicatedStorage.Shared = src/shared, ...
MOUNTS = {
    ("ReplicatedStorage", "Shared"): os.path.join(SRC, "shared"),
    ("ServerScriptService", "Server"): os.path.join(SRC, "server"),
    ("StarterPlayerScripts", "Client"): os.path.join(SRC, "client"),
}


def instance_of_file(path):
    """Directory node for the script's own instance location: returns (dir, name)."""
    d, f = os.path.split(path)
    name = f[: -len(".lua")]
    for suffix in (".server", ".client"):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
    return d, name


def child(node, name):
    """node = filesystem path of a folder or a module file. Returns child path or None."""
    if node is None or not os.path.isdir(node):
        return None
    d = os.path.join(node, name)
    if os.path.isdir(d):
        return d
    for ext in (".lua", ".server.lua", ".client.lua"):
        f = os.path.join(node, name + ext)
        if os.path.isfile(f):
            return f
    return None


def resolve_chain(base, chain):
    node = base
    for part in chain:
        if part == "Parent":
            if node is None:
                return None
            node = os.path.dirname(node) if not node.endswith(".lua") else os.path.dirname(node)
            continue
        node = child(node, part)
        if node is None:
            return None
    return node


ASSIGN = re.compile(r"local\s+(\w+)\s*=\s*([\w\.:\(\)\"]+)\s*$", re.M)
REQUIRE = re.compile(r"require\(([\w\.]+)\)")


def parse_path_expr(expr, env, script_node):
    """Returns a filesystem node for an instance path expression, or None."""
    expr = expr.replace(':WaitForChild("', ".").replace('")', "")
    parts = expr.split(".")
    head, rest = parts[0], parts[1:]
    if head == "script":
        node = script_node
    elif head in env:
        node = env[head]
    elif head == "ReplicatedStorage" and rest and rest[0] == "Shared":
        node = MOUNTS[("ReplicatedStorage", "Shared")]
        rest = rest[1:]
    else:
        return "unknown"
    if node == "unknown":
        return "unknown"
    return resolve_chain(node, rest)


for path in lua_files():
    rel = os.path.relpath(path, ROOT)
    code = read(path)
    d, name = instance_of_file(path)
    # the script instance itself: a file node; script.Parent = its folder
    script_node = path
    env = {"ReplicatedStorage": "unknown"}
    for m in ASSIGN.finditer(code):
        var, expr = m.group(1), m.group(2)
        if expr.startswith("script") or expr.startswith("ReplicatedStorage") or expr.split(".")[0] in env:
            if expr.startswith("ReplicatedStorage:WaitForChild(\"Shared\")") or expr == "ReplicatedStorage.Shared":
                env[var] = MOUNTS[("ReplicatedStorage", "Shared")]
            elif "require" not in expr and "GetService" not in expr:
                node = parse_path_expr(expr, env, script_node)
                if node is not None and node != "unknown":
                    env[var] = node
    for m in REQUIRE.finditer(code):
        expr = m.group(1)
        if expr == "target":  # harness-style dynamic requires
            continue
        node = parse_path_expr(expr, env, script_node)
        if node == "unknown":
            continue
        if node is None:
            err(f"{rel}: require({expr}) does not resolve")
        elif os.path.isdir(node) and not os.path.isfile(os.path.join(node, "init.lua")):
            err(f"{rel}: require({expr}) points at a folder")

# ---------------------------------------------------------------- 4 names
all_code = {os.path.relpath(p, ROOT): read(p) for p in lua_files()}
joined = "\n".join(all_code.values())

remotes_src = all_code["src/shared/Modules/Remotes.lua"]
remote_names = set(re.findall(r'"(\w+)"', re.search(r"Remotes.FUNCTIONS = \{(.*?)\}", remotes_src).group(1)))
remote_names |= set(re.findall(r'"(\w+)"', re.search(r"Remotes.EVENTS = \{(.*?)\}", remotes_src).group(1)))
for rel, code in all_code.items():
    for name in re.findall(r'Remotes\.get\("(\w+)"\)', code):
        if name not in remote_names:
            err(f"{rel}: unknown remote {name}")

actions_src = all_code["src/server/Services/ActionService.lua"]
actions = set(re.findall(r"^handlers\.(\w+)\s*=", actions_src, re.M))
for rel, code in all_code.items():
    if rel.startswith("src/client"):
        for name in re.findall(r'(?:State\.call|ui\.act|UI\.act)\("(\w+)"', code):
            if name not in actions:
                err(f"{rel}: client calls unknown server action '{name}'")

panels = {f[:-4].lower() for f in os.listdir(os.path.join(SRC, "client/UI/Panels")) if f.endswith(".lua")}
for rel, code in all_code.items():
    for name in re.findall(r'(?:ui|UI)\.open\("(\w+)"', code):
        if name not in panels:
            err(f"{rel}: opens unknown panel '{name}'")
    for name in re.findall(r'ui\.open\(b\[3\]\)', code):
        pass
hud = all_code["src/client/UI/HUD.lua"]
for name in re.findall(r'\{ "[^"]+", "[^"]+", "(\w+)" \}', hud):
    if name not in panels:
        err(f"HUD.lua: button opens unknown panel '{name}'")

effects = all_code["src/client/Controllers/EffectsController.lua"]
notify_handlers = set(re.findall(r"^handlers\.(\w+)\s*=", effects, re.M))
for rel, code in all_code.items():
    if rel.startswith("src/server"):
        for kind in re.findall(r'notify(?:All)?\((?:player|target|[a-zA-Z]+)?,?\s*"(\w+)"', code):
            if kind not in notify_handlers:
                err(f"{rel}: Notify kind '{kind}' has no client handler")

props_src = all_code["src/server/World/Props.lua"]
prop_keys = set(re.findall(r"^defs\.(\w+)\s*=", props_src, re.M)) | set(re.findall(r'^defs\["(\w+)"\]', props_src, re.M))


def check_prop(key, where):
    if key not in prop_keys:
        err(f"{where}: unknown prop '{key}'")


for rel, code in all_code.items():
    for key in re.findall(r'Props\.build\("(\w+)"', code):
        check_prop(key, rel)
for m in re.finditer(r"equipment = \{([^}]*)\}", joined):
    for key in re.findall(r'"(\w+)"', m.group(1)):
        check_prop(key, "room equipment")
for m in re.finditer(r"props = \{([^}]*)\}", all_code["src/shared/Config/Cities.lua"]):
    for key in re.findall(r'"(\w+)"', m.group(1)):
        check_prop(key, "city props")
for key in re.findall(r'model = "(\w+)"', all_code["src/shared/Config/Cosmetics.lua"]):
    check_prop(key, "cosmetic deco")

MATERIALS = {"Plastic", "SmoothPlastic", "Neon", "Wood", "WoodPlanks", "Marble", "Basalt", "Slate", "CrackedLava", "Concrete",
             "Limestone", "Granite", "Pavement", "Brick", "Pebble", "Cobblestone", "Rock", "Sandstone", "CorrodedMetal",
             "DiamondPlate", "Foil", "Metal", "Grass", "LeafyGrass", "Sand", "Fabric", "Snow", "Mud", "Ground", "Asphalt",
             "Salt", "Ice", "Glacier", "Glass", "ForceField", "Air", "Water", "Cardboard", "Carpet", "CeramicTiles",
             "ClayRoofTiles", "RoofShingles", "Leather", "Plaster", "Rubber"}
for m in re.findall(r'(?:wallMaterial|groundMaterial) = "(\w+)"', joined):
    if m not in MATERIALS:
        err(f"unknown material {m}")
for rel, code in all_code.items():
    for m in re.findall(r"Enum\.Material\.(\w+)", code):
        if m not in MATERIALS:
            err(f"{rel}: unknown Enum.Material.{m}")

# ---------------------------------------------------------------- report
if errors:
    print(f"{len(errors)} problem(s):")
    for e in errors:
        print("  - " + e)
    sys.exit(1)
print(f"static checks passed ({len(all_code)} files, {len(actions)} actions, {len(panels)} panels, {len(prop_keys)} props)")
