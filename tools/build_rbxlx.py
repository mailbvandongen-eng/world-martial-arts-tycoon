#!/usr/bin/env python3
"""Builds build/WorldMartialArtsTycoon.rbxlx from the Rojo project, without Rojo.

Follows Rojo's conventions for the parts this project uses:
  folder            -> Folder
  Name.server.lua   -> Script
  Name.client.lua   -> LocalScript
  Name.lua          -> ModuleScript
plus the services and a few properties from default.project.json.
The result opens directly in Roblox Studio (File > Open from File).
"""
import json
import os
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "build")

_ref = [0]


def ref():
    _ref[0] += 1
    return f"RBX{_ref[0]:08X}"


def prop_xml(name, value):
    if isinstance(value, bool):
        return f'<bool name="{name}">{"true" if value else "false"}</bool>'
    if isinstance(value, (int, float)):
        return f'<float name="{name}">{value}</float>'
    return f'<string name="{name}">{escape(str(value))}</string>'


SKIP_PROPS = {"Technology"}  # enums: set in Studio (see docs/SETUP.md)


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def script_item(path, name, cls):
    with open(path, encoding="utf-8") as fh:
        source = fh.read()
    return (f'<Item class="{cls}" referent="{ref()}"><Properties>'
            f'<string name="Name">{escape(name)}</string>'
            f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
            f"</Properties></Item>")


def dir_items(path):
    out = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            out.append(f'<Item class="Folder" referent="{ref()}"><Properties><string name="Name">{escape(entry)}</string></Properties>'
                       + "".join(dir_items(full)) + "</Item>")
        elif entry.endswith(".server.lua"):
            out.append(script_item(full, entry[:-len(".server.lua")], "Script"))
        elif entry.endswith(".client.lua"):
            out.append(script_item(full, entry[:-len(".client.lua")], "LocalScript"))
        elif entry.endswith(".lua"):
            out.append(script_item(full, entry[:-len(".lua")], "ModuleScript"))
    return out


def node_xml(name, node):
    cls = node.get("$className")
    children = []
    if "$path" in node:
        p = os.path.join(ROOT, node["$path"])
        if cls is None:
            cls = "Folder"
        children.extend(dir_items(p))
    props = [f'<string name="Name">{escape(name)}</string>']
    for k, v in node.get("$properties", {}).items():
        if k not in SKIP_PROPS:
            props.append(prop_xml(k, v))
    for k, v in node.items():
        if not k.startswith("$"):
            children.append(node_xml(k, v))
    return f'<Item class="{cls}" referent="{ref()}"><Properties>' + "".join(props) + "</Properties>" + "".join(children) + "</Item>"


def main():
    with open(os.path.join(ROOT, "default.project.json"), encoding="utf-8") as fh:
        project = json.load(fh)
    tree = project["tree"]
    items = [node_xml(k, v) for k, v in tree.items() if not k.startswith("$")]
    doc = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
           '<Meta name="ExplicitAutoJoints">true</Meta>' + "".join(items) + "</roblox>")
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, project["name"] + ".rbxlx")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(doc)
    # validate: well-formed XML and every script made it in
    root = ET.parse(out).getroot()
    scripts = [i for i in root.iter("Item") if i.get("class") in ("Script", "LocalScript", "ModuleScript")]
    expected = sum(1 for b, _, fs in os.walk(os.path.join(ROOT, "src")) for f in fs if f.endswith(".lua"))
    if len(scripts) != expected:
        print(f"error: {len(scripts)} scripts in place, {expected} source files", file=sys.stderr)
        sys.exit(1)
    for s in scripts:
        src = s.find("Properties/ProtectedString").text or ""
        if not src.strip():
            print("error: empty script " + s.find("Properties/string").text, file=sys.stderr)
            sys.exit(1)
    print(f"wrote {os.path.relpath(out, ROOT)} ({len(scripts)} scripts, {os.path.getsize(out) // 1024} KB)")


if __name__ == "__main__":
    main()
