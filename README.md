# VWP2GoM

Converts a save that uses **Vanilla Weapons Plus - Gunworks Edition** into one that uses **Guns of
Marz**. Guns, magazines, attachments, bayonets and ammo in the save become their Guns of Marz
equivalents.

Vanilla Weapons Plus reworks the vanilla firearms, so this includes the vanilla guns, magazines,
rounds, ammo boxes and attachments (M9, M1911, M16A2, shotgun shells, 4x scopes, ...), not only the
items Vanilla Weapons Plus adds.

> **Warning:** Items that only exist in Vanilla Weapons Plus (Glock 17, M4, AK-47, 75-round
> magazines, 7.62x39mm rounds, ...) are deleted from a save the first time it loads with neither
> **Vanilla Weapons Plus - Gunworks Edition** nor **VWP2GoM Placeholders** enabled. Once the game
> saves, they cannot be recovered.

## Before you start

Subscribe to these on the Steam Workshop:

| Name in the mod list | Mod ID | Workshop ID |
|---|---|---|
| Gunworks-gang | `SWMG` | 3722064198 |
| Guns of Marz | `GunsOfMarz` | 3722134990 |
| VWP2GoM - Vanilla Weapons Plus to Guns of Marz | `VWP2GoM` | 3803058865 |
| VWP2GoM Placeholders | `VWP2GoM_Placeholders` | 3803058865 |

The Guns of Marz Workshop item also contains **Guns of Marz (Old Version)** (mod ID `MarzGuns`).
Don't enable that one.

Stay subscribed to Vanilla Weapons Plus (mod ID `MarzVanillaGuns`, Workshop ID 3773834525) until
you have finished, so you can still load your backup if you need to.

## Single player

1. Quit the game.
2. Back up the save: copy its folder from `Zomboid/Saves/<game mode>/<save name>/` (for example
   `Zomboid/Saves/Apocalypse/MySave/`) to somewhere outside `Zomboid`.
3. Start the game without the `-debug` launch option. In debug mode VWP2GoM closes the game
   before the world loads, so nothing is lost, but nothing is converted either.
4. On the main menu click **LOAD**.
5. Select the save, click **MORE...**, then click **Choose Mods...**.
6. Disable **Vanilla Weapons Plus - Gunworks Edition**.
7. Enable **Gunworks-gang**, **Guns of Marz**, **VWP2GoM - Vanilla Weapons Plus to Guns of Marz**
   and **VWP2GoM Placeholders**. VWP2GoM Placeholders is marked incompatible with Vanilla Weapons
   Plus, so the two can't be enabled together.
8. Click **ACCEPT**, then **PLAY**.
9. After the game has loaded, open `Zomboid/Lua/VWP2GoM.log` and search it for `FAILED` (see
   [The log](#the-log)). Do this before you load the save again, because each load starts a new
   log.
10. Keep all four mods enabled for this save from now on.

## Dedicated server

1. Stop the server.
2. Back up the world: copy `Zomboid/Saves/Multiplayer/<server name>/` to somewhere outside
   `Zomboid`. It includes `players.db`, which holds every player's inventory.
3. Open `Zomboid/Server/<server name>.ini`.
4. Edit the `Mods=` line:
   - Remove `MarzVanillaGuns`.
   - Add `SWMG`, `GunsOfMarz`, `VWP2GoM` and `VWP2GoM_Placeholders` if they're not already
     there.
   - Separate IDs with `;`. A leading `\` on an ID is allowed, so `\SWMG` and `SWMG` work the
     same.

   ```
   Mods=SWMG;GunsOfMarz;VWP2GoM;VWP2GoM_Placeholders
   ```
5. Edit the `WorkshopItems=` line:
   - Remove `3773834525` (Vanilla Weapons Plus).
   - Add `3722064198`, `3722134990` and `3803058865`.
   - Separate IDs with `;`.

   ```
   WorkshopItems=3722064198;3722134990;3803058865
   ```
6. Start the server without `-debug`. In debug mode VWP2GoM shuts the server down before the
   world loads. Players download the new mods automatically when they join.
7. Open `Zomboid/Lua/VWP2GoM.log` on the server machine and search it for `FAILED`. Do this
   before restarting the server, because each start begins a new log.
8. Keep all four mods in the server's mod list from now on.

The conversion runs only on the server; clients just need the mods installed. If you host from
the main menu with **HOST** instead of running a dedicated server, follow the same steps. The
settings file is `Zomboid/Server/servertest.ini` unless you named the server something else.

## When items are converted

VWP2GoM converts items when the game loads them:

| Where | Converted when |
|---|---|
| A player's inventory, including bags, hands, back, holsters and hotbar | The save loads or the player joins, then again every in-game minute |
| Containers, floors and corpses | The area they are in loads |
| Vehicles | The vehicle loads |
| Newly generated loot | The container is filled |

Bags inside bags are converted up to 8 levels deep.

Areas nobody has visited since the switch still hold the old items. VWP2GoM Placeholders stops the
Vanilla Weapons Plus-only items being deleted until they are converted. VWP2GoM Placeholders
requires VWP2GoM, so disabling either mod turns off the placeholders. If you do, those items are
deleted the next time their area loads, and the vanilla ones are no longer converted.

## What each item becomes

| Item | Becomes |
|---|---|
| Gun with a Guns of Marz version | That version: M9 → M92FS, M1911 → M1911, M16A2 → M16A2, M4 → M4A1, AK-47 → AK47, M14 → M14, MP5 → MP5, JS-2000 → Mossberg 590, MSR788 → Remington 700, and so on |
| Gun that Guns of Marz doesn't have | The Guns of Marz gun with the closest stats: Glock 17 → M92FS, .44 Desert Eagle → S&W 629, SR-25 → PSG1, sawn-off pump shotgun → Remington 870, JS-556 → M16A3, JS5 → MP5 |
| Vanilla revolver | A random Guns of Marz revolver that fires the same round: the Patrol Revolver (.357) and SN38 Revolver (.38) become a Python, Rhino, MP-412 or Detective .38; the Magnum (.44) becomes an S&W 629 |
| Magazine | The matching Guns of Marz magazine, with the same rounds in it. If the new gun can't take that magazine, it gets the largest magazine it can take, and the matching magazine is placed beside it |
| Attachment on a gun | The Guns of Marz attachment that does the same job, mounted with any rail or mount it needs |
| Loose attachment or bayonet | The Guns of Marz attachment or bayonet that does the same job |
| Rounds | The Gunworks round of the same caliber. Shotgun shells become buckshot |
| Boxes and cartons | The matching Guns of Marz box or carton. Guns of Marz packs .44 boxes differently, so .44 boxes and cartons become .44 boxes plus loose rounds with the same total |

A converted gun keeps:

- the rounds in its magazine and chamber, in the same order
- jams, spent casings and its fire mode, if the new gun has that mode
- its condition, scaled to the new gun's maximum, and its repair count
- blood, folded stock, deployed bipod and fixed bayonet
- its custom name and favourite mark
- its location: hands, back, holster, hotbar slot, bag, container, vehicle, corpse or floor

Anything that no longer fits is placed next to the gun, in the same container or on the same
spot on the floor, rather than deleted:

- rounds beyond the new magazine's capacity, or of a caliber it can't take
- a magazine the new gun can't use, with any surplus rounds in it
- an attachment that has no mount on the new gun, converted to its Guns of Marz version
- attachments from other mods that VWP2GoM doesn't convert

The full list is in [docs/mapping.md](docs/mapping.md), and the code that decides it is
[VWP2GoM_Map.lua](Contents/mods/VWP2GoM/42/media/lua/shared/VWP2GoM/VWP2GoM_Map.lua).

## The log

`Zomboid/Lua/VWP2GoM.log` is cleared each time a world loads. Its first line names the world and
says whether it is single player or a server. After that VWP2GoM writes one line for each item it
converts. The same lines also appear in the game's console log (`Zomboid/console.txt`, or
`Zomboid/server-console.txt` on a dedicated server), starting with `[VWP2GoM]`.

```
Base.PistolGlock [cond 7/10, ammo 12+1, mag] -> MarzGuns.M92FS [cond 7/10, ammo 12+1, mag] | none on Player at 10862,9412,0
```

That line reads: a Glock at condition 7 of 10, with 12 rounds in its magazine and 1 in the
chamber, became an M92FS with the same, in the inventory of the player standing at those
coordinates. Anything placed next to the new item is listed after it, following a `+`, for example
`-> MarzGuns.M92FS [...] + SWMG.9x19_Bullet, SWMG.9x19_Bullet | ...`.

The part after `|` says where the item was:

| Location text | Meaning |
|---|---|
| `<container> on <object> at x,y,z` | In a container belonging to a player, corpse or world object at those coordinates. A player's main inventory shows as `none on Player at x,y,z` |
| `<container> in <bag> / <where the bag is>` | Inside a bag, followed by where that bag is |
| `floor at x,y,z` | Lying on the floor |

Other lines:

| Line starts with | Meaning |
|---|---|
| `FAILED, left unchanged` | That item was not converted. VWP2GoM tries it again the next time that area loads, and every in-game minute for items in a player's inventory |
| `FAILED while placing` | The new item was made but could not be put where the old one was |
| `STOPPED` | Debug mode was on and the game was closed before the world loaded. Restart without `-debug` |
| `Guns of Marz or Gunworks is not loaded` | Nothing was converted. Check that Gunworks-gang and Guns of Marz (not the Old Version) are enabled |

If the same item keeps failing, report the line along with `Zomboid/console.txt`.

On later loads the log only lists items that were converted in that session, so a short or empty
log is normal once your surroundings are converted.

## FAQ

**Can I disable VWP2GoM once everything looks converted?**
Only if nobody will ever load an area that hasn't been visited since the switch. On a save you
keep playing, leave both VWP2GoM mods enabled.

**Why are new guns I find random?**
Guns of Marz has three sandbox options: **Enable Vanilla Weapon Replacement**, **Enable Vanilla
Ammo Replacement** and **Enable Vanilla Attachments Replacement**. When one is on, Guns of Marz
replaces the vanilla items of that kind in newly generated loot with random Guns of Marz ones.
VWP2GoM leaves that loot to Guns of Marz. It converts everything else, including new vanilla items
when the matching option is off, using its fixed table.

**Why did the vanilla rounds I just crafted turn into Gunworks rounds?**
While VWP2GoM is enabled, it keeps converting vanilla guns, magazines, rounds and attachments in
your inventory, checking every in-game minute.

## For developers

- [docs/research.md](docs/research.md): how Build 42 saves, loads and syncs items
- [docs/mapping.md](docs/mapping.md): what every item becomes and why
- [docs/implementation.md](docs/implementation.md): how the converter works
- `uv run --with lupa python3 tests/run_tests.py`: offline tests. The runner reads the installed
  mods from the macOS Steam paths in its `WORKSHOP` and `GAME` constants; change those on other
  systems.
