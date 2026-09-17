# VWP2GoM

Converts a save that uses **Vanilla Weapons Plus - Gunworks Edition** into one that uses **Guns of
Marz**. All the Vanilla Weapons Plus guns, magazines, attachments and ammo in the save become their
Guns of Marz equivalents.

> **Warning:** Vanilla Weapons Plus items are deleted from a save the first time it loads with
> neither **Vanilla Weapons Plus - Gunworks Edition** nor **VWP2GoM Placeholders** enabled. Once
> the game saves, they cannot be recovered.

## Before you start

Subscribe to these on the Steam Workshop:

| Name in the mod list | Mod ID | Workshop ID |
|---|---|---|
| Gunworks-gang | `SWMG` | 3722064198 |
| Guns of Marz | `GunsOfMarz` | 3722134990 |
| VWP2GoM - Vanilla Weapons Plus to Guns of Marz | `VWP2GoM` | *(this item)* |
| VWP2GoM Placeholders | `VWP2GoM_Placeholders` | *(this item)* |

The Guns of Marz Workshop item also contains **Guns of Marz (Old Version)**. Don't enable that
one.

## Single player

1. Quit the game.
2. Back up the save: copy its folder from `Zomboid/Saves/<game mode>/<save name>/` (for example
   `Zomboid/Saves/Apocalypse/MySave/`) to somewhere outside `Zomboid`.
3. Start the game without the `-debug` launch option.
4. On the main menu click **LOAD**.
5. Select the save, click **MORE...**, then click **Choose Mods...**.
6. Disable **Vanilla Weapons Plus - Gunworks Edition**.
7. Enable **Gunworks-gang**, **Guns of Marz**, **VWP2GoM - Vanilla Weapons Plus to Guns of Marz**
   and **VWP2GoM Placeholders**.
8. Click **ACCEPT**, then **PLAY**.
9. After the game has loaded, open `Zomboid/Lua/VWP2GoM.log` and search it for `FAILED` (see
   [The log](#the-log)).
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
   - Add `3722064198`, `3722134990` and this item's Workshop ID.
   - Separate IDs with `;`.
6. Start the server. Players download the new mods automatically when they join.
7. Open `Zomboid/Lua/VWP2GoM.log` on the server machine and search it for `FAILED`.
8. Keep all four mods in the server's mod list from now on.

## Why the mods must stay enabled

VWP2GoM converts items when the game loads them:

| Where | Converted when |
|---|---|
| Your inventory | You load the save or join the server |
| Everything else in the world | That area first loads |

Areas nobody has visited since the switch still hold Vanilla Weapons Plus items. VWP2GoM
Placeholders stops those items being deleted until they are converted. If you disable either
VWP2GoM mod, they are lost the next time those areas load.

## What each item becomes

| Item | Becomes |
|---|---|
| Vanilla Weapons Plus gun | The Guns of Marz version: M9 → M92FS, M4 → M4A1, AK-47 → AK47, MP5 → MP5, and so on |
| Gun that Guns of Marz doesn't have | The Guns of Marz gun with the closest stats: Glock 17 → M92FS, .44 Desert Eagle → S&W 629, SR-25 → PSG1, sawn-off pump shotgun → Remington 870, JS-556 → M16A3, JS5 → MP5 |
| Vanilla revolver | A random Guns of Marz revolver of the same caliber |
| Magazine | The matching Guns of Marz magazine, with the same rounds in it |
| Attachment | The Guns of Marz attachment that does the same job, mounted with any rail it needs |
| Rounds, boxes, cartons | Guns of Marz rounds, boxes and cartons with the same total number of rounds |

A converted gun keeps:

- the rounds in its magazine and chamber
- its condition and repair count
- its custom name and favourite mark
- its location: hands, back, holster, hotbar slot, bag, container, vehicle or floor

If something no longer fits the new gun, it is placed next to the gun rather than deleted:
- rounds beyond the new magazine's capacity
- a magazine the new gun can't use
- an attachment that has no mount on the new gun

## The log

VWP2GoM writes one line to `Zomboid/Lua/VWP2GoM.log` for each item it converts:

```
Base.PistolGlock [cond 7/10, ammo 12+1, mag] -> MarzGuns.M92FS [cond 7/10, ammo 12+1, mag] | none on Player
```

That line reads: a Glock at condition 7 of 10, with 12 rounds in its magazine and 1 in the
chamber, became an M92FS with the same, in the player's inventory.

A line starting with `FAILED` means that item was left unchanged. VWP2GoM tries it again the next
time that area loads or that player joins. If the same item keeps failing, report the line along
with `Zomboid/console.txt`.

## FAQ

**Can I disable VWP2GoM once everything looks converted?**
Only if nobody will ever load an area that hasn't been visited since the switch. On a save you
keep playing, leave both VWP2GoM mods enabled.

**Why are new guns I find random?**
Guns of Marz's sandbox options replace newly spawned vanilla weapons with random Guns of Marz ones.
VWP2GoM leaves new loot to Guns of Marz and only converts items that were already in the save.
