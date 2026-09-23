# VWP2GoM implementation notes

How the migration works and why. The engine facts it relies on are in
[research.md](research.md), and the item-by-item decisions are in [mapping.md](mapping.md). The
Lua has almost no comments; the reasoning lives here.

## Two mods in one workshop item

| Mod id | What it holds | When it is enabled |
|---|---|---|
| `VWP2GoM` | The converter (Lua) | From the first migration load onward |
| `VWP2GoM_Placeholders` | Item scripts with the same full types as MarzVanillaGuns items | Only once MarzVanillaGuns is disabled, and in that same load |

**The placeholders cannot share a mod with the converter.**
- **With MarzVanillaGuns still enabled,** two definitions of one item merge (research.md, "Item
  scripts"). The placeholders would overwrite MarzVanillaGuns' icons, and firearm `Categories`
  would add up.
- **Without MarzVanillaGuns,** the placeholders are what stops the game deleting those items
  from the save.

`VWP2GoM_Placeholders` declares `incompatible=MarzVanillaGuns`, so the game refuses to load both.

## The placeholders

[tools/gen_placeholders.py](../tools/gen_placeholders.py) writes
`Contents/mods/VWP2GoM_Placeholders/42/media/scripts/zz_VWP2GoM_Placeholders.txt` from the
installed mods. Run it again if MarzVanillaGuns changes.

- **Mod-only items (43)** get a full placeholder:
  - identity values: `DisplayName` with a `(VWP2GoM)` suffix, `DisplayCategory`, `Weight`, and an
    `Icon` borrowed from the nearest vanilla item
  - every value a save does not store but loading depends on: `ItemType`, `PartType`,
    `MagazineType`, `ConditionMax`, `MaxAmmo`, `ClipSize`, `AmmoType`, `HaveChamber`, fire modes,
    `AttachmentType`, reload type, `ManuallyRemoveSpentRounds`, `Categories` for the knives, and
    so on
- **Vanilla IDs (16)** get only the values MarzVanillaGuns changed from vanilla. The generator
  compares them and found:
  - the six vanilla magazines, which MarzVanillaGuns turned from `base:normal` into
    `base:weaponpart` / `PartType = Clip` (with `MountOn`)
  - `AssaultRifle`'s fire modes
  - both double barrels' `ManuallyRemoveSpentRounds`
  - the `MountOn` lists of seven vanilla attachments (`x2Scope`, `x4Scope`, `RedDot`,
    `TritiumSights`, `Laser`, `GunLight`, `RecoilPad`), which MarzVanillaGuns extended with its
    own guns
  The other 18 vanilla IDs load identically without MarzVanillaGuns, so they get no placeholder.
  That makes 59 placeholders in all.
- **`MountOn` is required on every weapon part.** `Item.InstanceItem` calls
  `WeaponPart.setMountOn(script.mountOn)`, which calls `size()` on it without a null check. A part
  placeholder without `MountOn` throws a NullPointerException every time it is created. The part
  then fails to load, and so does **every weapon it is mounted on**. The first in-game test lost
  a Glock this way (its `CloseBolt` part). Placeholders copy MarzVanillaGuns' `MountOn`, and vanilla
  IDs that MarzVanillaGuns turned into parts (the magazines) get it as an override.
- **What is deliberately left out:** Lua callbacks (`OnCreate`, `CanAttach`…), models, sounds,
  `Tags`, `GunType`. None of them are needed to load, and each is another way for a line to fail.
- **`mvgi:bullets_762`** is only registered while MarzVanillaGuns' `registries.lua` runs, so
  placeholders use `swmg:bullet_762x39` instead. An unknown ammo type would load as null.
- **Values containing `,` or `=` stop the generator.** One unparsable line makes the game drop
  the whole item script, and every saved item of that type with it. This happened once:
  `Attack_Bayonet`'s display name contains a comma, so the generator keeps only the text before
  it.
- **The file name starts with `zz_`**, so it sorts after the other mods' files.

## Converter layout

| File | Role |
|---|---|
| `shared/VWP2GoM/VWP2GoM_Map.lua` | Every mapping table: weapons, magazines, rounds, boxes and cartons, the .44 repacks, attachment function lists, internal parts |
| `shared/VWP2GoM/VWP2GoM_Convert.lua` | Builds the replacement item(s) for one source item. Places nothing |
| `server/VWP2GoM/VWP2GoM_Server.lua` | Finds source items, swaps them in place, sends the network updates, and logs. Returns immediately on an MP client |
| `client/VWP2GoM/VWP2GoM_Client.lua` | MP client only: asks the server to convert its player on join, and refreshes the hotbar when told |

Conversion only runs where changes persist: single player and the server (every file but the
client one returns early when `isClient()`).

## Finding items

| Where | Hook |
|---|---|
| Map containers, floor items, corpses | `Events.LoadChunk`, which fires after a chunk's objects, corpses and first-time loot exist. The scan walks the 8x8 squares on every level |
| Newly rolled loot (map, zombies, vehicles) | `Events.OnFillContainer` |
| Vehicle part containers | `Events.OnSpawnVehicleEnd`, which fires on every spawn and every load |
| Player inventories | `OnCreatePlayer` and `OnGameStart` (single player), the client's `scanMe` command (MP join), plus `EveryOneMinute` for every player. The minute sweep also picks up vanilla items that enter an inventory later, such as crafted rounds |

- **Bags are scanned recursively**, up to 8 levels deep.
- **A converted item is never a source again**, so scanning the same place twice does nothing.

## Swapping an item in place

`Migrate.replaceInContainer`:

1. Records whether the item is in the primary or secondary hand, and its `AttachedItems`
   location (back, holster).
2. **Adds the new item and any extras first**, then removes the original. If anything fails, the
   worst outcome is a duplicate, never a loss.
3. Restores hands and the attached location on the new item, and sends the network updates (see
   "Multiplayer").
4. Refreshes the local hotbar in single player.

For floor items, `IsoWorldInventoryObject:swapItem` keeps the id, position and rotation. Extras go
onto the same square at the same offset.

Every conversion runs inside `pcall`, **before** the original is touched. A failure logs
`FAILED, left unchanged` and leaves the item as it was, so it is retried on the next scan.

## Multiplayer

Conversion runs only on the dedicated server, which owns every inventory (it loads players from
`players.db` and saves its own copy back). The facts behind each rule below are in research.md,
"Multiplayer item sync".

| Situation | What the server does |
|---|---|
| Chunk loads (`LoadChunk`) or loot is rolled (`OnFillContainer`) | Nothing extra. The chunk is sent to clients after `LoadChunk`, and freshly rolled loot is sent after `OnFillContainer`, so clients receive the converted items |
| Item in a player inventory, or a bag at any depth in it | `sendReplaceItemInContainer` / `sendAddItemToContainer`. These reach only the owner, and carry the full item (modData, parts, ammo, name, slots) |
| Item in furniture, a corpse, a vehicle part, or a bag lying on the floor | The same calls. They reach every client in range |
| Item in a bag inside furniture, a corpse or a vehicle | The engine sends nothing for a nested bag (no owner, no parent, no world item). After converting inside it, the server re-sends the whole bag to its outer container with `sendRemoveItemFromContainer` + `sendAddItemToContainer` |
| Floor item | `swapItem` sends the new item in full (it takes the old item's id). Extras use `AddWorldInventoryItem(..., true)`, which transmits |
| Gun in a player's hands | Replacement packets use ordering channel 1 and `Equip` uses channel 0, so they can arrive out of order. An `Equip` naming an item the client does not have yet empties the hand, and the client echoes that to the server. The server therefore waits 15 ticks (`queueEquip`) before `setPrimaryHandItem` / `setSecondaryHandItem` + `sendEquip` |
| Gun on the back or in a holster | `setAttachedItem` + `sendAttachedItem` update the server and other clients. The owning client ignores that packet; its `ISHotbar:update` re-attaches the new item because it carries the old `attachedSlot`, `attachedSlotType` and `attachedToModel` |
| Player joins | No server event exists. The client sends `scanMe` from `OnGameStart` (`client/VWP2GoM/VWP2GoM_Client.lua`), and `EveryOneMinute` sweeps every online player as a fallback |
| After converting a player's items | The server sends a `refresh` command; the client refreshes the hotbar, the hand models and the inventory window |

A converted gun's magazine type is not written by `HandWeapon.save` and so does not travel over
the network. It survives through `modData.MagazineType`, which Gunworks re-applies on equip
(`Magazine.RestoreMagazineType`).

## Building a replacement weapon

`Convert.weapon`, in order:

1. **Create the GoM gun without its `OnCreate`.** GoM's `MarzGuns_OnCreate.AttachParts` would
   add random attachments, a random magazine and random ammo. Scripts call `OnCreate` by name
   each time, so the converter swaps that function for a no-op around `instanceItem`.
2. **Mount the parts GoM requires** for that gun (`AttachmentPointsTable.required`: slides, bolts,
   pumps, integrated stocks and bipods, barrels), with these substitutions:
   - an MVG `OpenBolt` picks the `_Fired` variant of `_Lock` parts
   - a Side-by-Side barrel part picks the matching GoM barrel (open barrels are normalised to
     closed, as MarzVanillaGuns itself does on install)
   - `Map.RequiredPartSwaps` handles the JS3T pump selector and the sawn-off double barrel
3. **Mount functional attachments** in `Map.PartPriority` order, trying each candidate in
   `Map.Parts[...].mount`:
   - The gun must be listed in the part's `MountOn`. The engine resolves `MountOn` entries through
     `ScriptManager.getItem` and drops any it can't find, so GoM's bayonets (whose entries are
     quoted) end up with an empty list. Bayonets are therefore checked against Gunworks'
     `Bayonet.BayonetMountableWeapons` registry instead.
   - The PartType slot must be free, and no `UpgradeExclusives` or bayonet exclusive may block it.
   - Required parents come from `RequiredAttachment.Dependencies` / `AnyDependencies`. Missing
     ones are mounted first (rails, muzzle devices). If that fails, the parents added for this
     attempt are removed again.
   - No candidate fits → the part's `loose` (or `looseLongGun`) item is added to the extras.
   - Unknown parts from other mods go to the extras as they are.
   - Internal parts (`Clip`, `MovingBolt`, `StockIntegrated`, `Barrel`) are not handed out.
     Their state is rebuilt instead.
4. **Load the ammunition** (`loadWeapon`):
   - Rounds are `AmmoList` translated through `Map.Rounds`. The list is padded at the front with
     the gun's ammo type up to `count + chambered`, because MarzVanillaGuns' `OnCreate` never
     wrote `AmmoList`.
   - Rounds the new gun's ammo family does not accept become loose rounds.
   - **Magazine-fed target:**
     - Use the mapped magazine if the gun's GoM magazine profile lists it; otherwise use the
       largest magazine in the profile.
     - The gun keeps the top rounds (last in `AmmoList`, next to fire) up to that magazine's
       capacity. When the mapped magazine was used, the rest become loose rounds. When it was
       not, a loose magazine of the mapped type is always handed back, holding the rest (possibly
       none). Examples: an M93R gets a 60-round `9x19Magazine60_M93R` plus an empty
       `9x19Magazine15_M92FS`; an AC556 (M16A3) gets a 150-round STANAG plus an empty
       `223Magazine20_Mini14`; an SR25 (PSG1) gets its 5-round magazine plus an M14 magazine
       holding the surplus.
     - Guns with no Gunworks magazine profile (M14, M1911, PSG1, CAMP_CARBINE…) accept only their
       script `MagazineType`.
     - Sets `magazineType`, `maxAmmo`, `containsClip`, `modData.MagazineType`, and the visual clip
       part through `Magazine.manageMagazineAttachment`.
   - **Tube, revolver or break-action target:**
     - The inserted source magazine is handed back empty, as its mapped type.
     - The gun takes rounds up to its `MaxAmmo`; the surplus becomes loose rounds.
   - **The chambered round** stays chambered only if the new gun has a chamber. Otherwise it goes
     into the tube or becomes a loose round.
   - `jammed`, spent round count and chambered flag, and `SpentAmmoList` (translated) are copied.
5. **Copy the rest:**
   - fire mode, if the new gun offers it
   - blood level
   - condition as a proportion of `ConditionMax` (0 stays 0, full stays full)
   - repairs, favourite, custom name, attached slot fields, world rotation
   - all modData except the keys in `Map.TransientModData`
6. **Record the origin** in `modData.VWP2GoM`: `from` type, the source part list, and a copy of
   the original modData. A bad mapping can be traced and undone from that.
7. **Restore framework state** the way Gunworks does on equip: magazine type, underbarrel, folding
   stock (`StockFolded` from JS5 stock parts), bipod, bayonet, then
   `StatsFactory.ReapplyAllModifiers`.

## Rerolled vanilla revolvers

`Map.RerollWeapons` lists the three vanilla revolvers. `Convert.weaponTarget` picks a random entry
from `Convert.rerollPool(source)`: the `Map.RerollCandidates` handguns that share the source's
handgun class (`AttachmentType` starting with `Holster`) and accept its translated round
(`Convert.accepts`). With the current GoM data only revolvers qualify: `.38 .357` → PYTHON,
RHINO, MP412 or DETECTIVE_38; `.44 Magnum` → SW629. Pools are cached per ammo family and class.
The pick then goes through the
same `Convert.weapon` path as every other gun, so rounds, condition, name and slots carry over and
no bonus items are added.

Freshly rolled loot is unaffected: GoM's own random replacement still handles it (see the GoM
section below).

## Other items

- **Loose magazines:** the mapped type. Rounds translated; surplus and wrong-caliber rounds come
  out loose (the .44 magazine becomes an empty .50 magazine plus loose .44 rounds).
- **Rounds, boxes and cartons:** 1:1 through `Map.Rounds` / `Map.AmmoPacks`. .44 boxes and
  cartons are repacked to exactly the same round count (`Map.AmmoRepacks`).
- **Loose attachments:** the function's `loose` item. `looseLongGun` is used instead only for a
  part that came off a gun that is not a handgun, so a pump shotgun's `AmmoStraps` come back as a
  `Rem700_Sling`; attachments found loose always use `loose`. Condition, battery charge
  (proportional), on/off state, favourite, custom name and modData are copied.
- **Knives and internal items found loose:** `Map.LooseOther`.

## GoM's random vanilla replacement

GoM sets `OnCreate = MarzGuns_OnCreate.VanillaReplace` on vanilla guns, magazines, attachments
and ammo when its sandbox options ask for it. `OnCreate` also runs while a saved item loads, and
GoM would then replace a player's loaded gun with a random new one (research.md, "Guns of Marz
and vanilla items"). The converter wraps that function:

- **The wrapper records the item** instead of replacing it.
- **`OnFillContainer` marks recorded items that belong to freshly rolled loot.**
- **On the next tick,** only marked items go to GoM's original function, so new loot keeps GoM's
  random variety.
- **Every other recorded item is left alone:** saved items are converted deterministically by
  the scans above (vanilla revolvers are rerolled by caliber with their state kept).

## Debug mode stop and log reset

`shared/VWP2GoM/VWP2GoM_Guard.lua` runs on `Events.OnInitWorld` in single player and on the
server.

- **The log is cleared.** `VWP2GoM.log` is rewritten with a header naming the world, so each load
  starts a fresh log.
- **Debug mode stops the game.** If `getDebug()` is true, it writes a `STOPPED` line and exits.
  - **Why:** in debug mode, `InventoryItem.loadItem` throws on a size mismatch instead of skipping
    to the end of the item.
  - **Why this point:** `OnInitWorld` fires in `IsoWorld.init` before `WorldDictionary.init`,
    `ServerMap.init` and any player or chunk loading, so nothing has been read or written yet.
  - **How:** with no player object, `Core.quit()` saves only `options.ini` and calls
    `System.exit(0)`. If a player object still exists, `Core.quitToDesktop()` is used instead.
    That goes through `GameWindow.exit()`, which only saves the world when `okToSaveOnExit` is
    set, and `GameLoadingState` keeps that false until loading has finished.

## Log

`Convert.log` writes each line to the console (prefixed `[VWP2GoM]`) and appends it to
`Zomboid/Lua/VWP2GoM.log`. Every conversion writes one line (`report` in `VWP2GoM_Server.lua`), for example:

```
Base.AssaultRifleAK47 [cond 10/10, ammo 60+1, mag] -> MarzGuns.AK47 [cond 15/15, ammo 60+1, mag] + MarzGuns.M9_BAYONET | none on Player at 10862,9412,0
```

- `Convert.describe` adds `[cond c/max, ammo n(+1)(, mag)]` for weapons and `[ammo n]` for
  magazines.
- Extras follow a `+`.
- The location comes from `describeContainer`: `<container type> on <parent object name> at
  x,y,z`, `<container type> in <bag full type> / <outer location>` for bags, or `floor at x,y,z`.

Other lines: `FAILED, left unchanged: <type> (<error or "no target item">)`, `FAILED while
placing <type>: <error>`, `Guns of Marz or Gunworks is not loaded; nothing will be converted.`
(written once, when `ready()` first fails), and the guard's `STOPPED` line.

## Tests

`tests/` runs the converter offline against the real item scripts, the real Gunworks framework
modules and the real GoM registries, with a strict fake of the Java API (`fake_pz.lua`). Calling a
method the fake does not define is an error. The fake also reproduces engine behaviour found in
game: a weapon part without `MountOn` fails to instance, and `MountOn` keeps only entries that
resolve to a script.

The tests run standard Lua 5.1, not Kahlua. Kahlua has no one-argument `next(t)` (the first
in-game run failed on it), so check any standard-library call against vanilla's Lua before using
it.

```
uv run --with lupa python3 tests/run_tests.py      # add -v to print the log
```

`run_tests.py` reads the installed mods and game scripts from the macOS Steam paths in its
`WORKSHOP` and `GAME` constants. On another system, change those two lines first.

Each scenario checks that no source item is left behind and that the number of rounds is the same
before and after. The scenarios:

- Glock held and holstered
- AK-47 on the back with drum, suppressor, scope and bayonet
- SR-25 to PSG1
- .44 Desert Eagle to SW629
- double barrels with straps, pad and choke
- Side-by-Side barrels
- JS5 stock
- ammo, magazines and parts inside a bag
- the GoM wrapper
- vanilla revolvers rerolled by caliber
- dedicated-server packets: replace for a player inventory, delayed equip, nested bag re-send
- placeholders: all 59 instance using only vanilla + GoM + placeholder scripts, and a Glock with
  parts converts without MarzVanillaGuns loaded
- entering a world clears the log, and debug mode quits before the world loads
- M16A2 bayonet, rails and fire mode
- MP5 light
- L92 capacity

**What the tests cannot show:** the real engine's behaviour. Stat changes from parts,
`StatsFactory` restores, packet delivery and the hotbar all need an in-game test; see the README.
The server test only checks that the right send functions are called at the right time.
