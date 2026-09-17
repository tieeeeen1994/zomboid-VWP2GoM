# VWP2GoM - Vanilla Weapons Plus to Guns of Marz

Moves an existing Build 42 save from **Vanilla Weapons Plus - Gunworks Edition**
(`MarzVanillaGuns`) to **Guns of Marz** (`GunsOfMarz`) without losing anything. It converts every
gun, magazine, attachment, round, box and carton, including ones in places you have not visited
yet.

## What it converts

- **Guns** become their Guns of Marz counterpart, for example the M9 to the M92FS, the M4 to the
  M4A1 and the AK-47 to the AK47. Guns with no counterpart become the Guns of Marz gun with the
  closest stats:
  - Glock 17 → M92FS
  - .44 Desert Eagle → S&W 629
  - SR-25 → PSG1
  - sawn-off pump → Remington 870
  - JS-556 → M16A3
  - JS5 → MP5

  Vanilla revolvers, which Vanilla Weapons Plus never changed, reroll to a random Guns of Marz
  handgun of the same caliber: Python, Rhino, MP412 or Detective .38 for .357/.38, and the S&W
  629 for .44.

  The full list is in [docs/mapping.md](docs/mapping.md).
- **The gun keeps its state:**
  - rounds in the magazine and in the chamber, including which ammo they are
  - jams, spent shells and fire mode
  - condition (as the same share of its maximum), repairs, custom name and favourite
  - where it was: hands, back, holster or hotbar slot, container, or the floor
  - other mods' data stored on the gun
- **Attachments are refitted** as the Guns of Marz part that does the same job, with any rail or
  muzzle mount it needs. A part that cannot fit the new gun is put next to the gun instead.
- **Magazines** become the matching Guns of Marz magazine with their rounds.
- **Ammo** (loose rounds, boxes and cartons, for every caliber) becomes Guns of Marz ammo. Round
  counts match exactly. .44 boxes and cartons are repacked, because a Guns of Marz .44 box holds
  25 rounds rather than 20.

**Nothing is thrown away.** Rounds that no longer fit, a magazine a revolver cannot take, or an
attachment with nowhere to go are placed beside the converted gun.

## The two mods

| Mod | Enable when |
|---|---|
| **VWP2GoM** | For the migration, and for as long as unconverted areas may remain |
| **VWP2GoM Placeholders** | Only once Vanilla Weapons Plus is disabled, **in the same load** |

Without a definition, the game deletes an item from the save the moment it loads. The
placeholders keep every Vanilla Weapons Plus item in existence until VWP2GoM gets to it. They
cannot be active alongside Vanilla Weapons Plus; the mod manager enforces that.

## How to migrate

1. **Back up the save.** Copy the whole folder under `Zomboid/Saves/`.
2. *(Optional, safest)* Load once with **Vanilla Weapons Plus + Guns of Marz + VWP2GoM**
   enabled. Your inventory and every area that loads is converted using Vanilla Weapons Plus's
   real item definitions. Save and quit.
3. In the mod manager: disable **Vanilla Weapons Plus**, and enable **Guns of Marz**,
   **VWP2GoM** and **VWP2GoM Placeholders**. Load the save.
   - Do not launch with `-debug` for this load. In debug mode the game treats a size mismatch in
     a saved item as fatal.
4. Check `Zomboid/Lua/VWP2GoM.log`. Every conversion is one line. Any line starting with
   `FAILED` left that item unchanged; it is retried the next time that area loads.
5. **Keep both VWP2GoM mods enabled.** Areas you have not visited still hold the old items and are
   converted when they first load. Removing the placeholders deletes those items.

### Multiplayer

- Install both mods on the server and on every client.
- The conversion runs on the server. Players on the server see the converted items in their
  inventory, hands, back and hotbar without relogging.
- Players who log in later are converted when they join, and every in-game minute as a fallback.
- Items in areas nobody has loaded are converted when the server first loads that area, before it
  sends the area to anyone.
- Test on a server with two clients before migrating a live server: one client holding and
  wearing old guns, the other standing nearby to check that guns on backs and in hands update for
  both.

## Guns of Marz's vanilla replacement

If the Guns of Marz sandbox options that replace vanilla guns, attachments or ammo are on, Guns of
Marz also swaps vanilla items for random new ones, and it would do so to items loaded from your
save. While VWP2GoM is enabled, that only happens to **newly generated loot**. Your existing items
are converted by the fixed mapping instead.

## Test before trusting it with your save

The conversion was checked offline against the real item scripts and the Gunworks framework (see
[docs/implementation.md](docs/implementation.md)), but not in the game. On a copy of your save,
before the real migration:

- A Glock with a silencer, laser and loaded magazine in your hands
- An AK-47 with a 75-round drum on your back
- A loose Assault Rifle Silencer and a 7.62x39 box on the floor
- A double barrel in a car trunk
- A .44 carton in a crate in an area you have not loaded since

Then run steps 3 and 4 and check each item, the log, and that the guns fire and reload.

## Documentation

- [docs/research.md](docs/research.md): how Build 42 saves and loads items, read from the game's
  code
- [docs/mapping.md](docs/mapping.md): every item, and what it becomes and why
- [docs/implementation.md](docs/implementation.md): how the migration works
