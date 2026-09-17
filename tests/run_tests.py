#!/usr/bin/env python3
"""Run the offline conversion tests.

Needs `lupa` (Lua 5.1): `uv run --with lupa python3 tests/run_tests.py`

The item scripts, the Gunworks framework modules and the Guns of Marz registries are read
from the installed game and workshop folders, so the tests exercise the real data.
"""
import glob
import os
import re
import sys

import lupa.lua51 as lua51

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WORKSHOP = os.path.expanduser("~/Library/Application Support/Steam/steamapps/workshop/content/108600")
GAME = os.path.expanduser(
    "~/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app/Contents/Java/media")
MVG = WORKSHOP + "/3773834525/mods/MarzVanillaGuns/42.18/media"
GOM = WORKSHOP + "/3722134990/mods/GunsOfMarz/42.16/media"
SWMG = WORKSHOP + "/3722064198/mods/Gunworks_gang_framework/42.13/media"
MOD = ROOT + "/Contents/mods/VWP2GoM/42/media/lua"

VANILLA_AMMO_KEYS = {
    "base:bullets_9mm": "Base.Bullets9mm",
    "base:bullets_45": "Base.Bullets45",
    "base:bullets_44": "Base.Bullets44",
    "base:bullets_38": "Base.Bullets38",
    "base:bullets_357": "Base.Bullets357",
    "base:bullets_556": "Base.556Bullets",
    "base:bullets_308": "Base.308Bullets",
    "base:bullets_3030": "Base.3030Bullets",
    "base:shotgun_shells": "Base.ShotgunShells",
    "mvgi:bullets_762": "Base.762Bullets",
}


def parse(files):
    items = {}
    for path in files:
        text = open(path, encoding="utf-8", errors="ignore").read()
        text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
        module = re.search(r"module\s+(\w+)", text)
        module = module.group(1) if module else "?"
        for match in re.finditer(r"^\s*item\s+([\w.\-&]+)\s*\{", text, flags=re.M):
            i, depth = match.end(), 1
            while depth and i < len(text):
                depth += (text[i] == "{") - (text[i] == "}")
                i += 1
            props = items.setdefault(module + "." + match.group(1), {})
            for line in text[match.end():i - 1].split("\n"):
                line = line.split("//")[0].strip().rstrip(",")
                if "=" in line:
                    key, value = line.split("=", 1)
                    key = key.strip().lower()
                    if key == "modelweaponpart":
                        continue
                    props[key] = value.strip()
    return items


def txt(root):
    return sorted(glob.glob(root + "/scripts/**/*.txt", recursive=True))


def main():
    vanilla = parse(sorted(glob.glob(GAME + "/scripts/**/*.txt", recursive=True)))
    scripts = {}
    for full_type, props in vanilla.items():
        if re.search(r"Bullets|Shells|Box|Carton|Clip|Scope|RedDot|Laser|GunLight|Choke|RecoilPad|AmmoStrap|Tritium",
                     full_type) or props.get("itemtype") in ("base:weapon", "base:container"):
            scripts[full_type] = props
    for full_type, props in parse(txt(MVG)).items():
        merged = dict(vanilla.get(full_type, {}))
        merged.update(props)
        merged.pop("oncreate", None)
        scripts[full_type] = merged
    scripts.update(parse(txt(GOM)))
    scripts.update(parse(txt(SWMG)))

    ammo_keys = dict(VANILLA_AMMO_KEYS)
    for path in [SWMG + "/registries.lua", GOM + "/registries.lua"]:
        for ident, key in re.findall(r'AmmoType\.register\("([^"]+)",\s*"([^"]+)"\)', open(path).read()):
            ammo_keys[ident.lower()] = key

    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.SCRIPTS = lua.table_from({k: lua.table_from(v) for k, v in scripts.items()})
    g.AMMO_KEYS = lua.table_from(ammo_keys)

    roots = [MOD + "/shared", MOD + "/server", SWMG + "/lua/shared", GOM + "/lua/shared", HERE]
    g.SEARCH_ROOTS = lua.table_from(roots)
    lua.execute("""
        table.insert(package.loaders, 2, function(name)
            for _, root in ipairs(SEARCH_ROOTS) do
                local path = root .. "/" .. name .. ".lua"
                local f = io.open(path, "r")
                if f then
                    f:close()
                    return assert(loadfile(path))
                end
            end
            return "\\n\\tno file in search roots for " .. name
        end)
    """)
    lua.execute(open(HERE + "/fake_pz.lua").read())
    for path in [SWMG + "/registries.lua", GOM + "/registries.lua"]:
        lua.execute(open(path).read())
    lua.execute(open(HERE + "/test_convert.lua").read())
    failures = lua.eval("TEST_FAILURES")
    log = lua.eval("LOG")
    if "-v" in sys.argv:
        for i in range(1, len(log) + 1):
            print("  log:", log[i])
    sys.exit(1 if failures and failures > 0 else 0)


main()
