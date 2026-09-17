#!/usr/bin/env python3
"""Generate the VWP2GoM_Placeholders item scripts from the installed mods.

Usage: python3 tools/gen_placeholders.py

Reads the MarzVanillaGuns scripts, merges them over the vanilla scripts the way the game
does, and writes one placeholder per MarzVanillaGuns item. Mod-only items get a full
placeholder. Items vanilla also defines only get the values MarzVanillaGuns changed that
affect how a saved item loads. See docs/implementation.md.
"""
import glob
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WORKSHOP = os.path.expanduser("~/Library/Application Support/Steam/steamapps/workshop/content/108600")
VANILLA = os.path.expanduser(
    "~/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app/Contents/Java/media/scripts")
MVG = WORKSHOP + "/3773834525/mods/MarzVanillaGuns/42.18/media"
OUT = ROOT + "/Contents/mods/VWP2GoM_Placeholders/42/media/scripts/zz_VWP2GoM_Placeholders.txt"

LOAD_KEYS = [
    "ItemType", "PartType", "MagazineType", "ConditionMax", "MaxAmmo", "ClipSize", "AmmoType",
    "HaveChamber", "FireMode", "FireModePossibilities", "AttachmentType", "CanStack",
    "WeaponReloadType", "ManuallyRemoveSpentRounds", "RackAfterShoot", "InsertAllBulletsReload",
    "Ranged", "SubCategory", "IsAimedFirearm", "Categories", "TwoHandWeapon",
    "RequiresEquippedBothHands", "HeadConditionMax", "HeadCondition", "Sharpness", "UseDelta",
    "Count", "MountOn",
]
IDENTITY_KEYS = ["DisplayCategory", "Weight"]

AMMO_TYPE_REPLACEMENTS = {
    "mvgi:bullets_762": "swmg:bullet_762x39",
}

ICON_ANALOG = {
    "PistolGlock": "Pistol", "Pistolm93r": "Pistol",
    "AssaultRifleA3": "AssaultRifle", "AssaultRifleM4": "AssaultRifle",
    "AssaultRifleAK47": "AssaultRifle", "AC556": "AssaultRifle",
    "MP5_SMG": "AssaultRifle", "MP5SD_SMG": "AssaultRifle", "JS5_smg": "AssaultRifle",
    "SR25_Rifle": "AssaultRifle2", "Side_By_Side": "DoubleBarrelShotgun",
    "9mmClip_25": "9mmClip", "9mmClip_30": "9mmClip", "9mmClip_40": "9mmClip",
    "9mmClip_100": "9mmClip", "JS5_Clip": "9mmClip",
    "556Clip_20": "556Clip", "556Clip_75": "556Clip", "762Clip_30": "556Clip",
    "762Clip_75": "556Clip", "JS14_Clip_30": "JS14_Clip",
    "308Clip_10": "M14Clip", "308Clip_20": "M14Clip",
    "762Bullets": "556Bullets", "762Box": "556Box", "762Carton": "556Carton",
    "Pistol_Silencer": "Laser", "Heavy_Pistol_Silencer": "Laser", "AR_Silencer": "Laser",
    "556Muzzle": "ChokeTubeFull", "762Muzzle": "ChokeTubeFull",
    "Side_By_Side_Barrel_Close": "ChokeTubeFull", "Side_By_Side_Barrel_Open": "ChokeTubeFull",
    "Side_By_Side_Barrel_Sawnoff_Close": "ChokeTubeFull",
    "Side_By_Side_Barrel_Sawnoff_Open": "ChokeTubeFull",
    "OpenBolt": "ChokeTubeFull", "CloseBolt": "ChokeTubeFull",
    "JS5_Stock_Folded": "RecoilPad", "JS5_Stock_Deployed": "RecoilPad",
    "M9_Bayonet": "KitchenKnife", "M9_Bayonet_Attachment": "KitchenKnife",
    "Attack_Bayonet": "KitchenKnife", "GenericFakeItem": "ChokeTubeFull",
}

ICON_FALLBACK = {
    "KitchenKnife": "Knife_FairbairnSykes",
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
                    props[key.strip().lower()] = value.strip()
    return items


def get(props, key):
    return props.get(key.lower())


def same(a, b):
    return (a or "").strip().lower() == (b or "").strip().lower()


def main():
    vanilla = parse(sorted(glob.glob(VANILLA + "/**/*.txt", recursive=True)))
    mvg_raw = parse(sorted(glob.glob(MVG + "/scripts/**/*.txt", recursive=True)))
    names = json.load(open(MVG + "/lua/shared/Translate/EN/ItemName.json"))

    blocks = []
    report = {"full": [], "override": [], "unchanged": []}
    for full_type in sorted(mvg_raw):
        if not full_type.startswith("Base."):
            continue
        short = full_type.split(".", 1)[1]
        merged = dict(vanilla.get(full_type, {}))
        merged.update(mvg_raw[full_type])
        lines = []
        if full_type in vanilla:
            for key in LOAD_KEYS:
                if key == "Categories":
                    continue
                value = get(merged, key)
                if value is not None and not same(value, get(vanilla[full_type], key)):
                    lines.append((key, value))
            if not lines:
                report["unchanged"].append(full_type)
                continue
            report["override"].append(full_type)
        else:
            display = names.get(full_type, short).split(",")[0]
            lines.append(("DisplayName", display + " (VWP2GoM)"))
            for key in IDENTITY_KEYS:
                value = get(merged, key)
                if value is not None:
                    lines.append((key, value))
            analog = ICON_ANALOG.get(short, "")
            icon = get(vanilla.get("Base." + analog, {}), "Icon") or ICON_FALLBACK.get(analog)
            if not icon:
                raise SystemExit("no icon for " + full_type)
            lines.append(("Icon", icon))
            for key in LOAD_KEYS:
                value = get(merged, key)
                if value is not None:
                    lines.append((key, value))
            report["full"].append(full_type)
        fixed = []
        for key, value in lines:
            if key == "AmmoType":
                value = AMMO_TYPE_REPLACEMENTS.get(value.lower(), value)
            if key == "Categories" and full_type in vanilla:
                continue
            if "," in value or "=" in value or not value:
                raise SystemExit("unsafe value for %s %s: %r" % (full_type, key, value))
            fixed.append((key, value))
        width = max(len(k) for k, _ in fixed)
        body = "\n".join("        %s = %s," % (k.ljust(width), v) for k, v in fixed)
        blocks.append("    item %s\n    {\n%s\n    }" % (short, body))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write("module Base\n{\n" + "\n\n".join(blocks) + "\n}\n")
    print("wrote", OUT)
    for k, v in report.items():
        print(k, len(v), " ".join(x.split(".", 1)[1] for x in v))


main()
