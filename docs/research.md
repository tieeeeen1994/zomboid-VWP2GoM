# VWP2GoM research notes

Facts gathered before writing the mod, so they do not have to be researched again.

- **Goal:** migrate a save from MarzVanillaGuns (Vanilla Weapons Plus - Gunworks Edition,
  workshop 3773834525, mod id `MarzVanillaGuns`) to Guns of Marz (workshop 3722134990, mod
  id `GunsOfMarz`) with no data loss.
- **Engine claims** were read from the bytecode of the Build 42 `projectzomboid.jar`, using
  [tools/jdis.py](../tools/jdis.py) and [tools/strsearch.py](../tools/strsearch.py).
- **Mod claims** were read from the workshop files.

Anything not yet confirmed is marked **UNCONFIRMED**.

## Mods involved

| Workshop | Mod id | Name | Version folder | Notes |
|---|---|---|---|---|
| 3773834525 | `MarzVanillaGuns` | Vanilla Weapons Plus - Gunworks Edition | `42.18` | Being removed. Every item script is in `module Base`. `require=SWMG` |
| 3722134990 | `GunsOfMarz` | Guns of Marz | `42.16` | Target. Items are in `module MarzGuns`. `require=SWMG` |
| 3722134990 | `MarzGuns` | Guns of Marz (Old Version) | `42.16` | Not used |
| 3722064198 | `SWMG` | Gunworks-gang | `42.13` | Framework used by both gun mods |
| 3610677934 | `HBVCEFb42`, `HBTacReload`, `HBAmmoCraft`, `zHBVCEF` | Hot Brass | various | MarzVanillaGuns has Hot Brass integration |

Paths are under `~/Library/Application Support/Steam/steamapps/workshop/content/108600/`.
The game install is `~/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app/Contents/Java/`.

## MarzVanillaGuns items: vanilla IDs vs mod-only IDs

Every MarzVanillaGuns item lives in `module Base`. Some redefine vanilla items; the rest exist
only in the mod. A quick check against `media/scripts` of the game install gave this split:

- **Also defined by vanilla**, so they survive without the mod but load with vanilla's
  values:
  - **Weapons:** `Pistol`, `Pistol2`, `Pistol3`, `AssaultRifle`, `AssaultRifle2`, `Shotgun`,
    `ShotgunSawnoff`, `DoubleBarrelShotgun`, `DoubleBarrelShotgunSawnoff`, `HuntingRifle`,
    `VarmintRifle`, `JS14_Rifle`, `JS3T_Shotgun`, `L92_Carbine`, `L94_Rifle`, `MSR7T_Rifle`,
    `TrapperCarbine`
  - **Magazines:** `9mmClip`, `44Clip`, `45Clip`, `556Clip`, `M14Clip`, `JS14_Clip`
  - **Attachments:** `x2Scope`, `x4Scope`, `x8Scope`, `RedDot`, `TritiumSights`, `Laser`,
    `GunLight`, `RecoilPad`, `AmmoStraps`, `ChokeTubeFull`, `ChokeTubeImproved`
- **Mod-only**, so they are deleted on load without a definition:
  - **Weapons:** `PistolGlock`, `Pistolm93r`, `AssaultRifleA3`, `AssaultRifleAK47`,
    `AssaultRifleM4`, `SR25_Rifle`, `MP5_SMG`, `MP5SD_SMG`, `AC556`, `JS5_smg`, `Side_By_Side`
  - **Magazines:** `9mmClip_25`, `9mmClip_30`, `9mmClip_40`, `9mmClip_100`, `556Clip_20`,
    `556Clip_75`, `308Clip_10`, `308Clip_20`, `762Clip_30`, `762Clip_75`, `JS14_Clip_30`,
    `JS5_Clip`
  - **Ammo:** `762Bullets`, `762Box`, `762Carton`
  - **Attachments:** `Pistol_Silencer`, `Heavy_Pistol_Silencer`, `AR_Silencer`, `556Muzzle`,
    `762Muzzle`
  - **Framework and internal visuals:** `M9_Bayonet_Attachment`, `M9_Bayonet`,
    `Attack_Bayonet`, `Side_By_Side_Barrel_Close`, `Side_By_Side_Barrel_Open`,
    `Side_By_Side_Barrel_Sawnoff_Close`, `Side_By_Side_Barrel_Sawnoff_Open`, `OpenBolt`,
    `CloseBolt`, `JS5_Stock_Folded`, `JS5_Stock_Deployed`, `GenericFakeItem`

`registries.lua` in MarzVanillaGuns registers its own ammo type:
`AmmoType.register("mvgi:bullets_762", "Base.762Bullets")`. It also registers the `.223` type.

### Mounted parts that are really state

MarzVanillaGuns and the Gunworks framework mount some parts purely as visuals for weapon state.
[PermanentAttachments.lua](../../../Library/Application%20Support/Steam/steamapps/workshop/content/108600/3773834525/mods/MarzVanillaGuns/42.18/media/lua/shared/MarzVanillaWeapons/Registries/PermanentAttachments.lua)
registers them with `PreventRemoval`:

| Part | Mounted when |
|---|---|
| Every magazine type (`PartType = Clip`) | A magazine is loaded |
| `OpenBolt` / `CloseBolt` (`PartType = MovingBolt`) | Always, showing the bolt position |
| `JS5_Stock_Folded` / `JS5_Stock_Deployed` (`PartType = StockIntegrated`) | Always, showing the stock position |
| `M9_Bayonet_Attachment` (`PartType = BayonetKnife`, `MountOn = Base.GenericFakeItem`) | The bayonet is fitted |

They still need placeholders, because a weapon whose part fails to resolve is dropped whole
(see below). Their meaning is carried again by weapon fields and modData, so the converter
does not hand them out as loose items (`Map.InternalPartTypes`); it rebuilds that state on the
new gun instead.

## Guns of Marz and vanilla items

- **No item overrides.** GoM's `module Base` files are only recipes
  (`recipes/ammunition.txt`, `recipes/weapon_recipes.txt`) and a sound
  (`sounds/M1_Garand.txt`).
- **It replaces vanilla items when they are created.**
  [ItemPatcher.lua](../../../Library/Application%20Support/Steam/steamapps/workshop/content/108600/3722134990/mods/GunsOfMarz/42.16/media/lua/shared/MarzWeapons/Hooks/ItemPatcher.lua)
  sets `OnCreate = MarzGuns_OnCreate.VanillaReplace` on vanilla weapons, magazines,
  attachments and ammo. This runs from `Events.OnInitGlobalModData`.
  - It is gated by the sandbox options `MarzGuns.VanillaWeaponReplacement`,
    `VanillaAttachmentReplacement` and `VanillaAmmoReplacement`.
- **The replacement is random and adds extras.**
  [VanillaReplacerTable.lua](../../../Library/Application%20Support/Steam/steamapps/workshop/content/108600/3722134990/mods/GunsOfMarz/42.16/media/lua/shared/MarzWeapons/OnCreate/VanillaReplacerTable.lua)
  can turn `Base.AssaultRifle` into `MarzGuns.M16A1` or `M16A2`, plus random magazines and an
  ammo box. That is fine for loot but not for a gun a player owns, so the migration needs its
  own fixed mapping.
- **GoM's replacement also fires on items loaded from a save, and throws their state away.**
  Confirmed from bytecode:
  - `Item.InstanceItem` ends with a thread check. On the game thread, the loading thread
    (`GameLoadingState.loader`) or the server main thread, it calls `initialiseItem()` when the
    new item is not yet initialised. `initialiseItem()` runs the script's Lua `OnCreate`.
  - Loading a saved item goes `InventoryItemFactory.CreateItem(short)` → `createItemInternal` →
    `Item.InstanceItem`, so `OnCreate` runs on a blank item **before** `load()` fills it in.
    Only then does `load()` restore the saved fields, including `isInitialised`.
  - GoM's `VanillaReplace` sees the blank item with no container yet, so
    `ItemSpawnCore.resolve` queues it on `OnTick`. On a later tick the loaded item is in its
    container, and `replaceContainerSpawner` adds a **new random** GoM item plus bonus
    magazines and ammo, then `DoRemoveItem`s the original. Its ammo, parts, modData, condition
    and name are lost.
  - This applies to every vanilla ID in GoM's lists (guns, magazines, attachments and ammo)
    whenever the matching `SandboxVars.MarzGuns.Vanilla*Replacement` option is on. A player's
    inventory loads on the loading thread, so it is affected.
  - **UNCONFIRMED:** whether chunk loading runs on one of those three threads. Items in chunks
    streamed by `WorldStreamer` may skip `OnCreate`.
  - **VWP2GoM neutralises this.** Scripts call `OnCreate` by name through
    `LuaManager.getFunctionObject` each time, so replacing the global
    `MarzGuns_OnCreate.VanillaReplace` with a wrapper works regardless of load order. VWP2GoM's
    wrapper only records the item; items that turn out to be fresh loot (`OnFillContainer`) are
    passed to GoM's original function on the next tick, and every other item is left for the
    state-preserving converter (implementation.md, "GoM's random vanilla replacement").
  - MarzVanillaGuns' own `MarzVanillaGuns_OnCreate.AttachParts` also runs on load, but
    `HandWeapon.load` starts with `clearAllWeaponParts()`, so the saved parts win.

## How the engine saves and loads items

### Item identity

- **The type is saved as an id, not a name.** `InventoryItem.save` writes
  `putShort(getRegistry_id())`, a byte, then `putInt(id)`, followed by a bit-flag header and
  the fields.
- **Each item has a size prefix.** `saveWithSize` writes an int size in front of the item.
- **Containers group identical items.** They save through `CompressIdenticalItems.save`: a
  short group count, then for each group an int count, one full item with its size, and
  `count-1` int item ids.

### Loading an item whose type is missing

`InventoryItem.loadItem(bb, ver, Z, item)`:

```
getInt size; if size <= 0 throw IOException
getShort id; get byte
CreateItem(S); if item != null item.load(bb, ver)   EXC -> logException; item = null
if item == null: skip to start+size, DebugLog, return null
if size != -1 && position != start+size: position(start+size); DebugLog;
     if Core.debug -> throw IOException
```

- **A missing type is skipped and lost.** The size prefix lets the loader skip it, it logs a
  line and returns null, and the game does not crash.
- **An exception inside `load()` drops the item.** It is caught and logged.
- **A size mismatch is repositioned in a normal run and the item is kept.** In `-debug` mode it
  throws instead. **Do not run the migration load with `-debug`.**
- **The next save makes the loss permanent.** `CompressIdenticalItems.load` leaves the null
  out of the container, so the next save no longer contains the item.
- **Placeholders must therefore be active the very first time the save loads without
  MarzVanillaGuns.** A chunk or player loaded and saved once without them has lost those
  items for good.

`CreateItem(short)`:

```
info = WorldDictionary.getItemInfoFromID(id)
if info != null && info.isValid(): createItemInternal(info.getFullType(), ...)
   -> ScriptManager.FindItem(fullType) -> Item.InstanceItem(...)
else DebugLog, return null
```

- `isValid()` is `!obsolete && !removed && isLoaded`.
- The script lookup is by **full type name**, so a placeholder named `Base.PistolGlock` from
  any mod resolves.

### WorldDictionary

- **What it stores:** registryId, module, name and a flags byte per entry. The flags are
  1 = modded (+ modId), 2 = existsAsVanilla, 4 = obsolete, 8 = removed, 16/32 = modOverrides.
- **Load order:** at world load `init()` runs `parseInfoLoadList`, then `parseCurrentInfoSet`,
  then saves the dictionary file.
- **Script missing:** `parseCurrentInfoSet` sets `removed = true` and logs `RemovedItem`. The
  entry and its registry id are kept.
- **Script back again:** if the existing entry is removed and the new one is not obsolete, it
  sets `removed = false` and logs `ReinstateItem`.
  - The **same registry id is reused**, so ids already in the save resolve again.
  - A different modId only logs `ModIDChangedItem` and is harmless.
- **Obsolete is permanent.** If a loaded script is ever obsolete, both `obsolete` and
  `removed` are set, and nothing clears `obsolete` again. **Never put `OBSOLETE` on a
  placeholder.**
- `onLoadItem` returns straight away on `GameClient.client`; clients receive the dictionary
  from the server.
- WorldDictionary and ItemInfo are **not exposed to Lua**.

### The Java class must match

`ItemType` decides the Java class `InstanceItem` creates:

| `ItemType` | Class |
|---|---|
| `base:weapon` | `HandWeapon` |
| `base:weaponpart` | `WeaponPart` |
| `base:normal` | `ComboItem` |
| `base:drainable` | `DrainableComboItem` |
| `base:container` | `InventoryContainer` |
| `base:food` | `Food` |
| `base:clothing` | `Clothing` |
| `base:literature` | `Literature` |
| `base:key` | `Key` |
| `base:radio` | `Radio` |
| `base:moveable` | `Moveable` |
| `base:map` | `MapItem` |
| `base:alarmclock` | `AlarmClock` |
| `base:alarmclockclothing` | `AlarmClockClothing` |
| `base:animal` | `AnimalInventoryItem` |

These classes override `save`/`load` with their own layout: HandWeapon, Clothing, Food,
InventoryContainer, Key, Literature, MapItem, Moveable, Radio, AlarmClock (+Clothing) and
AnimalInventoryItem. WeaponPart, ComboItem and DrainableComboItem share the plain
InventoryItem layout.

- **A weapon saved and loaded as a non-weapon** reads only the base fields. The HandWeapon
  bytes are skipped, so ammo flags, parts and fire mode are lost.
- **A non-weapon saved and loaded as a weapon** reads garbage and drops or corrupts the item.
- **Placeholders must use the same `ItemType` as the original.**

### What a load resets from the script

- **Name and condition start from the script.** `load()` first sets `name = originalName` and
  `condition = conditionMax`.
- **Condition is clamped.** It is saved only when it differs from `conditionMax`, and read back
  through `setConditionWhileLoading`, which does `clamp(v, 0, getConditionMax())`. **The
  placeholder's `ConditionMax` must equal the original's.**
- **Name** is saved only if it differs from `originalName`.
- **Entity components** are rebuilt from the save. Components the placeholder has that were not
  saved are removed.

### Everything `InventoryItem.save` persists

uses, condition, visual, custom colour, itemCapacity, **modData**, activated,
haveBeenRepaired, name, byteData, extraItems (as registry ids), customName, customWeight, keyId,
remote id and range, colour RGB, worker, wetCooldown, favourite, stashMap, infected,
**currentAmmoCount**, attachedSlot, attachedSlotType, attachedToModel, maxCapacity,
recordedMediaIndex, worldScale, isInitialised, entity components, animalTracks, texture
override, modelIndex, world XYZ rotation.

### `HandWeapon.save` / `load`

`save` calls `super.save`, writes an int bit header, then each field only when it differs from a
hard-coded default:

- maxRange (1), minRangeRanged (0), clipSize (0), minDamage (0.4), maxDamage (1.5),
  recoilDelay, aimingTime, reloadTime, hitChance, minAngle (0.5)
- **Attached parts (flag 1024):** a byte count, then for each part a full nested
  `WeaponPart.save`: short id, byte, id, all fields and modData. There is **no size prefix**.
- fireMode string, cyclicRateMultiplier, explosionTimer, maxAngle (1), bloodLevel
- containsClip, roundChambered and isJammed as flags only
- weaponSprite, if it differs from the script's
- minSightRange (2), maxSightRange (6)

**Not saved, so they come from the script:** spentRoundCount, spentRoundChambered,
magazineType, haveChamber, ammoType, maxAmmo, projectileSpread, fireModePossibilities.
currentAmmoCount is saved by the base class.

`load`:

```
clearAllWeaponParts(); super.load; reset defaults; weaponSprite = script.getWeaponSprite()
flag 1024: n = get(); for each: CreateItem(getShort()); get(); item.load(bb, ver);
           if item instanceof WeaponPart -> attachWeaponPart(null, part, false)
...
setContainsClip(flag); if isNullOrWhitespace(magazineType) setContainsClip(false)
setRoundChambered(flag); setJammed(flag)
flag 33554432 (legacy): parts stored as short type only
isMelee = !weaponCategories.isEmpty()
```

- **A missing part type drops the whole weapon.** `CreateItem` returns null and
  `item.load` then throws an NPE, which `loadItem` catches, discarding the weapon. **Every part
  type that can be mounted needs a placeholder**, including MarzVanillaGuns parts sitting on
  vanilla-ID weapons.
- **A part that resolves to a non-WeaponPart is silently discarded.** Its bytes are consumed.
  If it resolves to a class with its own layout, the stream shifts and the weapon is dropped or
  corrupted. **Part placeholders must be `base:weaponpart`.**
- **Attaching during load** (`doChange = false`) calls `setWeaponPart`:
  - `if isNullOrEmpty(partType) return`: a part with no `PartType` is silently dropped.
  - Parts are stored by PartType, and a second part with the same PartType pushes out the
    first. **Keep the original PartType.**
  - `MountOn` is not checked.
  - Stats do not change and `onAttach` is not called.
- **Clip and chamber flags depend on the script.** `setContainsClip(v)` stores
  `usesExternalMagazine() && v`, where `usesExternalMagazine` is `magazineType != null`, and
  `setRoundChambered(v)` stores `haveChamber && v`. **Weapon placeholders must keep
  `MagazineType` and the chamber setting.**
- **No `Categories` on a firearm placeholder.** `isMelee = !weaponCategories.isEmpty()`, so
  categories would make it melee.

### Attaching and detaching parts from Lua

- **`attachWeaponPart(chr, part, true)`** detaches any part with the same PartType, then
  changes maxRange, reloadTime, recoilDelay, aimingTime, hitChance, projectileSpread and
  min/max damage (plus `part.getDamage`). It then calls `part.onAttach`, which runs the Lua
  `OnAttach` callback.
- **`detachWeaponPart(..., true)`** subtracts the same stats and **also clipSize**, even though
  attach never adds clipSize. It then calls `onDetach`. It does nothing unless the part is the
  one registered for its PartType.
- **Saved stat fields already include the changes from attached parts.**
- **Use `doChange = false`** (or `setWeaponPart` / `clearWeaponPart`) when only moving parts
  between items.

## Item scripts

- **`Item.Load`** splits each line on `=`, keeps the first two pieces, and calls
  `DoParam(key, value)` (keys ignore case).
  - **Any exception removes the whole item.** It becomes an `InvalidParameterException`; the
  Item script type has the `RemoveLoadError` flag, so the script is not registered and every
  saved item of that type is lost.
  - **Check placeholder scripts carefully:** no bad numbers, and no lines without `=`.
- **`ItemType`** goes through `ResourceLocation.of(value)`: `base` is added when there is no
  colon, and the value is lowercased.
  - **An unknown value leaves `itemType` null**, and creating the item then fails with an NPE.
  - **The legacy `Type = Weapon` is not supported.** It is treated as an unknown key and stored
  in `defaultModData`.
- **Only `ItemType` is strictly required.** Missing icons, models and sounds do not cause errors.
  - **Icon:** falls back to `media/inventory/Question_On.png` when the texture is missing, and
    stays null when there is no `Icon` line. **Always set an Icon.**
  - **DisplayName:** `ItemName_Base.X` wins when a translation exists; otherwise the script
    value is used. **Always set one.**
  - **AmmoType:** an unknown id leaves `ammoType` null with no error.
    - Vanilla-registered ids are `base:bullets_3030`, `bullets_308`, `bullets_357`,
      `bullets_38`, `bullets_44`, `bullets_45`, `bullets_556`, `bullets_9mm`, `cap_gun_cap` and
      `shotgun_shells`.
    - `mvgi:*` ids only exist while MarzVanillaGuns' `registries.lua` runs.
  - **UNCONFIRMED:** what later reload code does with a null ammoType.
  - `WeaponReloadType` falls back to `NONE` when unknown or missing.
- **A weapon part with no `MountOn` cannot be created.** Confirmed in game: `InstanceItem` calls
  `WeaponPart.setMountOn(null)`, which throws `NullPointerException: Cannot invoke
  "java.util.List.size()" because "mountOn" is null`. Loading such a part fails, and so does any
  weapon carrying it.
- **`MountOn` entries are resolved.** `setMountOn` looks each entry up with
  `ScriptManager.getItem` (adding the part's module when there is no `.`) and keeps only those
  that exist. Quoted entries, as in GoM's bayonets, never resolve.
- **Defaults** from `Item.<init>`: `conditionMax = 10`, `haveChamber = true`; `clipSize`,
  `maxAmmo` and `fireModePossibilities` start at 0 or null.
- **Two definitions of the same item merge.** `ScriptBucket.CreateFromTokenPP` appends the
  second body to the same script object, and `Load` runs once per body in order.
  - **Simple values are overwritten** by the later body.
  - **Some lists are rebuilt:** `MountOn`, `GunType`, `FireModePossibilities`.
  - **Others add up:** `Categories`, and probably `Tags` and `ModelWeaponPart` (**UNCONFIRMED**).
- **Script files are ordered by file name, not by mod load order.** `ScriptManager` sorts
  vanilla files first, then mod files with `template_` files first, then
  `File.getName().compareTo`.
  - A placeholder or patch file that must win should sort last, for example `zz_vwp2gom_*.txt`.
  - **UNCONFIRMED:** whether all mods' files form one combined list.
- **`OBSOLETE = true`** makes `ScriptBucket.LoadScripts` skip registering the item. Never use it.

## Every other place items are saved

Every persistence path found writes items with `saveWithSize` and reads them with
`InventoryItem.loadItem`, either directly or through `ItemContainer.load` →
`CompressIdenticalItems`. A missing type is therefore dropped, or becomes an empty slot. The
rest of the stream still reads correctly, with the one exception in the floor items section.

**Objects on a square have no size prefix.** `IsoGridSquare.load` reads a per-object size only
when a debug flag is set, and `IsoChunk.IsDebugSave()` always returns false. If one object's
`load` reads the wrong number of bytes, everything after it on that square is misread. An
exception in `IsoObject.load` is rethrown as a `RuntimeException`.

### Floor items (`IsoWorldInventoryObject`)

- **Save:** `item.saveWithSize`, then `putDouble dropTime`, then a BitHeader: 1 =
  ignoreRemoveSandbox, 2 = `requiresEntitySave()` → `saveEntity`, 4 = extendedPlacement.
- **Load:** `loadItem`. When the item is null it reads dropTime and the header, then returns
  **without reading the entity data**.
- **The floor object is removed on load.** `IsoGridSquare.load` skips any
  `IsoWorldInventoryObject` whose `getItem()` is null, so it is gone after the next chunk save.
- **Risk (inferred, not tested in game):** a floor item that owns components (a
  FluidContainer: bottles, buckets, pots) is saved with flag 2 and entity bytes. If its type is
  missing, those bytes are not consumed and the rest of the square is misread. MarzVanillaGuns
  items have no fluid containers, so this should not affect the migration. It is the one way a
  missing type can corrupt a chunk.

### Vehicles

- **Key:** `loadItem` inside a try/catch; a missing key type leaves no key.
- **Part item** (tyre, battery, seat): `put(0|1)` + `saveWithSize` / `loadItem` with no null
  check. A missing type makes the part look uninstalled, and it is lost at the next save. The
  rest of the part reads correctly.
- **Part container:** `ItemContainer.load`; missing items are dropped.
- **In `-debug` mode** a size mismatch throws, nothing catches it, and the vehicle fails to
  load.

### Corpses (`IsoDeadBody`)

- **Container** through `ItemContainer.load`.
- **Worn and attached items** are saved as `(location, short index into savedItems)`.
- **Hand items are not saved.**
- **Missing items leave the slot empty.** CII keeps nulls in `savedItems`, so indices still line
  up, and `WornItems.setItem` / `AttachedItems.setItem` treat null as empty.
- **The catch block does not reposition the buffer.** An exception mid-container would misread
  the rest of the corpse and square.

### Characters

- **`IsoGameCharacter.load`:** `inventory.load` → CII, keeping nulls in `savedInventoryItems`.
  Hand items are read as int indexes into `includingObsoleteItems`, which also holds nulls, so a
  missing hand item gives an empty hand.
- **`IsoZombie`:** worn items by short index; null leaves the slot empty. No attached items or
  hands are saved.
- **`IsoPlayer`:** worn items and primary/secondary hand items by short index into
  `savedInventoryItems`, overriding the base values. Null leaves an empty slot or hand.
- **Hotbar and attached slots** are not saved on the player. They live on each item
  (`attachedSlot`, `attachedSlotType`, `attachedToModel`), and `ISHotbar.lua` rebuilds them from
  `item:getAttachedSlot()`. **A converted item must copy these three fields**, or the gun drops
  off the player's back or holster.
- **`players.db`** (`PlayerDB`, `ServerPlayerDB`) stores a blob that goes through the same
  `IsoPlayer.load`.
- **`IsoAnimal`** loads no inventory.

### Everything else

| Class | What it stores | Missing item |
|---|---|---|
| `IsoObject` (crates, furniture, compost, trough, washer, dryer…) | containers via `ItemContainer.load` | Dropped |
| `IsoPushableObject` | container | Dropped |
| `IsoMannequin` | container + worn items by index | Empty slot |
| `InventoryContainer` (bags) | contents via `ItemContainer.load` | Dropped |
| `IsoCarBatteryCharger` | item, battery | Field stays null |
| `IsoTrap` | weapon | No weapon |
| `IsoHutch$NestBox` | eggs | Skipped |
| `ResourceItem` (entity storage) | stored items via CII | Dropped |
| `CraftRecipeData$CacheData` (craft in progress) | inputs via CII | Dropped |

Raw `InventoryItem.load` outside item classes only appears in network packet parsing, which is
not persistence.

**UNCONFIRMED:** whether Lua reinstalls a vehicle part whose item became null, and who catches a
chunk-load `RuntimeException`.

## Lua events

`LuaEventManager.triggerEvent` has no single-player or multiplayer check of its own, so where an
event fires depends only on its call sites. Events that do **not** exist: `OnChunkLoaded`,
`OnVehicleLoaded`, `OnPlayerConnect`, `OnPostChunkLoad`. Registered but never fired from Java or
vanilla Lua: `OnMapLoadCreateIsoObject`, `OnIsoThumpableLoad`, `OnPreGameStart`.

### Map loading (`IsoChunk.doLoadGridsquare`)

The steps run in this order:

1. **Chunk setup.** Vehicles and corpses are added for new chunks. The vehicle `addToWorld` loop
   runs only in single player and on the server.
2. **Square loop** (chunks are 8x8; z runs from minLevel to maxLevel). For each square **that has
   at least one IsoObject**:
   - `obj:addToWorld()` for each object, then erosion and `MapObjects.loadGridSquare`
     (`MapObjects.OnLoadWithSprite` hooks run here)
   - **`LoadGridsquare(square)` fires**
   - corpses in `getStaticMovingObjects()` are added to the world
3. **After the loop:**
   - global object systems, loot respawn and building stories
   - **first-time loot is rolled** (`ItemPicker.checkObject`: containers that are not explored are
     filled and then marked explored)
   - the server sends chunk state to clients
4. **`LoadChunk(chunk)` fires last**, once objects, corpses, vehicles and new loot are all in place.

**Where map loading runs:** in single player, on the dedicated server
(`ServerMap.preupdate` → `ServerCell.Load2` → `RecalcAll2`), and on MP clients. A client's chunk
is a streamed copy, so changes made there do not persist.

- **`LoadGridsquare` fires before new loot** and skips squares with no objects.
- **`ReuseGridsquare`** effectively never fires in normal play or on a server. Do not use it.
- **Vanilla Lua barely uses these:** `LoadGridsquare` appears only in `DebugScenarios.lua`, and
  `LoadChunk` not at all.

### Containers

- **`OnFillContainer(roomOrOutfit, containerType, container)`**
  (`ItemPickerJava.fillContainerInternal`) returns early on MP clients, so it runs in single player
  and on the server.
  - **It fires only for first-time loot generation:** map containers, bags inside them
    (`"Zombie Bag"`), zombie and corpse inventories (`"Zombie"`, outfit), vehicle containers
    (`BaseVehicle.randomizeContainer`), `ItemSpawner` and `createRandomDeadBody`.
- **`OnContainerUpdate`** is only a UI refresh signal, not a load hook.
- **`OnSeeNewRoom`** is driven by local player vision, so it is not a server hook.
- **`OnObjectAdded`** is fired by Lua actions and client packets, not by loading.

### Vehicles (`BaseVehicle.createPhysics`)

Every time a vehicle is spawned **or loaded from `VehiclesDB2`** into the world, in single player,
on the server and on MP clients:

1. `OnSpawnVehicleStart(vehicle)` fires.
2. `createParts()` calls each part's Lua `create` function, **only for a part's first creation**.
3. `initParts()` calls each part's Lua `init` function **on every physics creation**.
4. `randomizeContainers()` fills containers that are not explored yet (never on clients).
5. **`OnSpawnVehicleEnd(vehicle)`** fires.

### Characters and startup

| Event | Where it fires |
|---|---|
| `OnGameBoot` | SP/client; on the server in `GameServer.doMinimumInit` after Lua loads |
| `OnInitWorld` | `IsoWorld.init`, everywhere, straight after the `On*DistributionMerge` events |
| `OnInitGlobalModData(isNewGame)` | `GlobalModData.init` from `IsoWorld.init`, everywhere |
| `OnGameTimeLoaded` | SP/client; on the server in `GameServer.main`, before `OnSGlobalObjectSystemInit` |
| `OnServerStarted` | Dedicated server only |
| `OnGameStart`, `OnLoad` | `IngameState.enter`; treat as SP/client only |
| `OnCreatePlayer(index, player)` | SP/client (`GameLoadingState.exit`, splitscreen); **never on the dedicated server** |
| `OnNewGame(player, square)` | New character: SP/client; on the server only for new MP characters |
| `OnConnected` | MP client only |
| `OnZombieDead(zombie)` | Everywhere; on SP/server the zombie's inventory is already filled |
| `OnDeadBodySpawn(body)` | A live character becoming a corpse, SP/client only; **not when a corpse loads** |

- **No event fires when a corpse loads.** Loaded corpses are already on the square when
  `LoadChunk` fires, in `square:getStaticMovingObjects()`, with their container at
  `corpse:getContainer()`.
- **No event fires on the server when a player joins.** Poll `getOnlinePlayers()`, or have the
  client ask with `sendClientCommand` (`OnClientCommand`).

### Walking squares on the server

- **Square and chunk lookups work on the server.** `getCell():getGridSquare(x, y, z)` and
  `getChunkForGridSquare` forward to `ServerMap`, and return nil when the area is not loaded.
- **Client-only lookups:** `getChunkMap(0)` and `getCell():getChunk(wx, wy)` do not work on the
  server.
- **No Lua API lists every loaded chunk on the server.** Work inside `LoadChunk(chunk)` using
  `chunk:getGridSquare(lx, ly, z)` for local x/y 0–7 and `chunk:getMinLevel()` /
  `getMaxLevel()`.

### Hooks VWP2GoM uses

| What | Hook |
|---|---|
| Map containers, floor items, corpses | `LoadChunk`: walk `getObjects()` (containers via `getContainerCount()` / `getContainerByIndex`), `getWorldObjects()` (floor items via `IsoWorldInventoryObject:getItem()`) and `getStaticMovingObjects()` (corpses) |
| Newly generated loot, including zombie inventories | `OnFillContainer` |
| Vehicles | `OnSpawnVehicleEnd`: walk `getPartCount()` / `getPartByIndex` and each `part:getItemContainer()`. Items installed as vehicle parts (`part:getInventoryItem()`) are not scanned |
| Players | `OnCreatePlayer` and `OnGameStart`, the client's `scanMe` command on the server, and an `EveryOneMinute` sweep of every player |
| Chunks already loaded before hooks exist | Nothing lists them on the server. A converted item is no longer a source type, so `LoadChunk` can simply handle each chunk as it loads, again and again |

`OnZombieDead` is not needed: a zombie's rolled inventory goes through `OnFillContainer`, and a
corpse that is saved and loaded again is picked up by `LoadChunk`.

Run conversions only where the change persists: single player or the server, never
`isClient()`.

## Lua API (confirmed exposed)

### InventoryItem

- `getFullType()`, `getModData()` (creates it), `hasModData()`
- `copyModData(table)` wipes the target's modData first
- `getCondition()`, `setCondition(int)` (plays sounds), `setCondition(int, boolean)`,
  `getConditionMax()`
- `getHaveBeenRepaired()` / `setHaveBeenRepaired(int)`, `isBroken()` / `setBroken`
- `isFavorite()`, `setFavorite(bool[, sync])`
- `getName()`, `setName`, `isCustomName()` / `setCustomName`
- `getContainer()`, `getOutermostContainer()`, `getWorldItem()`, `getID()` / `setID(int)`
- `getAttachedSlot()` / `setAttachedSlot`, `getAttachedSlotType()` / `setAttachedSlotType`,
  `getAttachedToModel()` / `setAttachedToModel`
- `isEquipped()`
- `copyConditionModData(item)` copies only `condition:*` keys
- `copyConditionStatesFrom(item)` copies condition modData, condition, haveBeenRepaired, head
  condition, sharpness, favourite, blood level and drainable uses
- `syncItemFields()`
- `getBloodLevel()` / `setBloodLevel`
- `getCurrentAmmoCount()` / `setCurrentAmmoCount`, `getMaxAmmo()` / `setMaxAmmo`,
  `getAmmoType()` (returns an AmmoType object, not a string)
- `getCurrentUses()` / `setCurrentUses`, `isCustomColor()` / `setCustomColor`, colour RGB getters
  and setters
- `getActualWeight()` / `setActualWeight`, `isCustomWeight()` / `setCustomWeight`,
  `isInfected()` / `setInfected`, `isActivated()` / `setActivated`
- `getWorldZRotation()` / `setWorldZRotation`, `getRegistry_id()`, `getModID()`, `getScriptItem()`

### HandWeapon

- `getAllWeaponParts()` (the live list), `getWeaponPart(String partType)`
- `attachWeaponPart(part)` (doChange true), `attachWeaponPart(part, Z)`,
  `attachWeaponPart(chr, part[, Z])`
- `detachWeaponPart(part)`, `detachWeaponPart(partType)`, `detachWeaponPart(chr, part[, Z])`,
  `detachAllWeaponParts()`
- `clearAllWeaponParts()`, `clearWeaponPart(part | partType)`, `setWeaponPart(part)`,
  `setWeaponPart(partType, part)`: no stat changes
- `isRoundChambered()` / `setRoundChambered`, `isSpentRoundChambered()` / `set...`,
  `getSpentRoundCount()` / `set...`
- `isJammed()` / `setJammed`, `isContainsClip()` / `setContainsClip`,
  `getMagazineType()` / `setMagazineType`
- `getFireMode()` / `setFireMode`, `getFireModePossibilities()`, `getClipSize()` /
  `setClipSize`, `haveChamber()` / `setHaveChamber`, `usesExternalMagazine()`

### WeaponPart

`getPartType()` / `setPartType`, `getMountOn()`, `onAttach` / `onDetach(chr, weapon)`,
`canAttach` / `canDetach(chr, weapon)`.

### ItemContainer

- `AddItem(item)`: if the container already holds that id it logs an error and returns the
  existing item; otherwise it removes the item from its old container and adds it. **Remove
  the old item before adding a replacement that reuses its id.**
- `AddItem(String)`, `AddItemBlind(item)`, `AddItems(...)`
- `Remove(item)` also calls `removeFromHands` for a character's container and fires
  `OnBeforeRemoveFromContainer`
- `DoRemoveItem(item)`, `removeItemOnServer(item)` (client only; there is **no**
  `addItemOnServer`)
- `getItems()`, `getItemsFromFullType(...)`, `getAllTypeRecurse`, `getAllEvalRecurse(fn)`
- `getParent()`, `getType()`, `getSourceGrid()`, `getVehiclePart()`, `isExplored()` /
  `setExplored`, `containsID(int)`, `getItemWithID(int)`, `setDirty`, `setDrawDirty`,
  `requestSync()`

### IsoGridSquare

- `AddWorldInventoryItem(item | type, x, y, z[, Z[, Z]])`
- `getWorldObjects()`, `removeWorldObject(obj)`, `transmitRemoveItemFromSquare(obj)`
- `getObjects()`, `getStaticMovingObjects()` (corpses), `getDeadBody()`, `getDeadBodys()`,
  `getVehicleContainer()`

### IsoWorldInventoryObject

- `getItem()`, `getWorldPosX/Y/Z()`, `getOffX/Y/Z()`, `removeFromWorld()`,
  `removeFromSquare()`
- **`swapItem(newItem)`** is the right tool for floor items. It copies id, worldScale and XYZ
  rotation, moves any FluidContainer, fires `OnContainerUpdate`, and on the server sends
  `SWAP_ITEM`. It throws if `newItem:getWorldItem() ~= nil`.

### IsoGameCharacter

- `getAttachedItems()`, `getAttachedItem(location)`, `setAttachedItem(location, item)`,
  `removeAttachedItem(item)`, `isAttachedItem(item)`
- `getPrimaryHandItem()` / `setPrimaryHandItem`, `getSecondaryHandItem()` /
  `setSecondaryHandItem`, `removeFromHands(item)`, `isEquipped(item)`,
  `resetEquippedHandsModels()`
- `getWornItems()`, `setWornItem(...)`, `removeWornItem(...)`

### Global functions

- `instanceItem(String[, F])`
- `sendAddItemToContainer(container, item)`: server only
- `sendRemoveItemFromContainer(container, item)`: server and client
- `sendReplaceItemInContainer(container, old, new)`: server only
- `replaceItemInContainer(...)` **does not replace items**; it only retargets queued timed
  actions in single player
- `syncItemModData(player, item)`, `syncItemFields(player, item)`,
  `syncHandWeaponFields(player, weapon)`, `sendAttachedItem(chr, location, item)`,
  `sendItemStats(item)`: server only
- `isServer()`, `isClient()`, `getScriptManager()`, `sendServerCommand` /
  `sendClientCommand`, `triggerEvent`

## Rules for zero data loss

1. **Have placeholders active on the first load without MarzVanillaGuns.** Every
   MarzVanillaGuns-only type needs one, including parts and magazines that can sit mounted
   inside any weapon, vanilla-ID weapons included.
2. **Match `ItemType`.** Use `base:weapon` for guns, `base:weaponpart` for parts and for
   MarzVanillaGuns magazines (they are weapon parts in that mod), and the original type for
   everything else.
3. **Copy the load-relevant script values** that saves do not store: `PartType` on parts;
   `MagazineType`, chamber setting, `ConditionMax`, `AmmoType`, `MaxAmmo` and `ClipSize` on
   weapons; `ConditionMax`, `MaxAmmo` and `AmmoType` on magazines.
4. **Keep MarzVanillaGuns' load-relevant values on vanilla-ID items during the migration** (for
   example, vanilla `9mmClip` is `base:normal` while MarzVanillaGuns made it `base:weaponpart`).
   Put the patch in a script file that sorts after the others, or use a Lua `DoParam` patch
   that runs before items load (**UNCONFIRMED:** timing).
5. **No `Categories` on firearm placeholders, and never `OBSOLETE`.**
6. **Validate every placeholder script.** One bad value removes the item type.
7. **Do not load the migration with `-debug`.**
8. **Convert floor items with `IsoWorldInventoryObject:swapItem`.** Inside containers `AddItem`
   the new item first, then remove the original, so a failure can only duplicate, never lose.
   Send network updates on the server.
9. **Copy modData, condition, repairs, favourite, custom name, blood, ammo, clip and chamber
   state, jam and fire mode**, and remap any item full types stored inside modData values.
10. **Copy `attachedSlot`, `attachedSlotType` and `attachedToModel`** so hotbar, back and holster
    slots survive.
11. **Keep a record of the original on the new item** so a bad mapping can be undone.

## Multiplayer item sync

Read from the bytecode; dumps were in the session scratchpad.

**Server replace, add and remove** (`LuaManager$GlobalObject.sendReplaceItemInContainer` /
`sendAddItemToContainer` / `sendRemoveItemFromContainer`, which only act on the server):

- **Packets:** `ReplaceInventoryItemInContainerPacket`, `AddInventoryItemToContainerPacket`,
  `RemoveInventoryItemFromContainerPacket`. Ordering channel 1, reliable.
- **The item is sent in full.** Replace uses `PlayerItem.write` → `item.save`, and Add uses
  `CompressIdenticalItems.save` → `saveWithSize`. That covers modData (nested tables),
  name, custom name, favourite, condition, ammo count, attached slot fields, weapon parts,
  `containsClip`, `roundChambered`, jam and fire mode. A bag's save includes its contents.
- **Not saved or sent anywhere:** `magazineType`, `ammoType`, `spentRoundCount`,
  `spentRoundChambered`, `haveChamber`. They come from the script on load.
- **Recipients** (`GameServer.sendReplaceItemInContainer`, same for add and remove):
  1. `container.getCharacter()` is an IsoPlayer → the owner only. This walks up through bags, so
     a bag at any depth in a player inventory counts.
  2. otherwise `container.getParent() != null` → every client in range
  3. otherwise the container's bag is lying on the floor → every client in range
  4. otherwise **nothing is sent**. This is the case for a bag inside furniture, a corpse or a
     vehicle part.
- **Client side:** Replace does `removeItemWithID(old)` (which also removes it from the hands) and
  `addItem(new)`. Add skips item ids the container already has. If the container cannot be
  found, the packet is dropped.
- **`ContainerID` types:** DeadBody, WorldObject, IsoObject, ObjectContainer, ObjectInVehicle,
  Vehicle, PlayerInventory, InventoryContainer (player id + bag item id), Floor.

**Hands and attached items:**

- **`sendEquip(player)`** → `updateHandEquips` → `EquipPacket` to everyone in range, owner
  included, ordering channel 0.
  - The owning client looks the item up with `getInventory().getItemWithID(id)` (top level only).
    If it is not there yet, the hand becomes null, and the client echoes that back to the server.
  - Setting a hand item on the server also marks `handItemShouldSendToClients`.
- **`sendAttachedItem(chr, location, item)`** → `GameCharacterAttachedItemPacket`, in range. The
  owning client **ignores** it (`if local player return`).
  - The owner's `ISHotbar:update` repairs itself every frame: it drops attached items that left
    the inventory and re-attaches any item whose `attachedSlot` is set but is not attached.
  - The owner's own attached model is therefore only correct for items that are in the hotbar.

**Floor:**
- `IsoGridSquare.AddWorldInventoryItem(item, x, y, z, transmit)`: with `transmit` true on the
  server, it sends `AddItemToMap` with the full item.
- `IsoWorldInventoryObject.swapItem(new)`: the new item takes the old id, and the server sends
  `SWAP_ITEM` with the full item.

**Chunks and loot:**

- **`LoadChunk` fires before the chunk is sent.** `ServerMap.preupdate` runs
  `doLoadGridsquare` (which fires `LoadChunk`), and only later in the same loop does
  `PlayerDownloadServer` serialise the in-memory chunk for clients. Changes made in `LoadChunk`
  need no packets.
- **Loot in containers is filled when a client first opens them.**
  `RequestItemsForContainerPacket.processServer` returns early for explored containers.
  Otherwise it fills the container, which fires `OnFillContainer`, then sends the contents. Changes
  made in `OnFillContainer` need no packets. There is no general "resync this container" request.

**Players:**

- **The server owns the inventory.** On connect, `ServerPlayerDB.serverLoadNetworkCharacter` loads
  the server's IsoPlayer from `players.db`, and the server saves its own copy back periodically and
  on disconnect.
- **No Lua event fires on the server when a player connects.** `OnCreateLivingCharacter` fires
  before the inventory loads. `OnCreatePlayer` is client only.
- `getOnlinePlayers()` includes the player as soon as the connection is processed.

**Syncing items that already exist on a client:**
- `syncItemModData(player, item)` (in range)
- `syncItemFields(player, item)` (owner; includes modData and slots)
- `syncHandWeaponFields(player, weapon)` (owner; ammo, chamber, clip, jam, stats, parts, modData)

## Item mapping and item state

The full catalogue, mapping and state notes are in [mapping.md](mapping.md): every
MarzVanillaGuns item, the GoM catalogue with mount rules, the implemented mapping with confidence,
and every modData key. The item lists were extracted with
[tools/parse_items.py](../tools/parse_items.py). The main points:

- **GoM and MarzVanillaGuns can run together.** GoM's `incompatible=` list does not include
  MarzVanillaGuns, and both require `SWMG`.
  - **The shipped procedure does not rely on that.** The user disables MarzVanillaGuns and
    enables `VWP2GoM` and `VWP2GoM_Placeholders` in the same load, and the placeholders keep
    every item loadable until it is converted. Areas nobody visits stay unconverted for as long
    as it takes, so both VWP2GoM mods stay enabled for good.
  - **Placeholders must not be active at the same time as MarzVanillaGuns.** Two definitions of
    one item merge, so a placeholder would overwrite MarzVanillaGuns' models and icons, and
    `Categories` would add up. They therefore ship as a separate mod id,
    `VWP2GoM_Placeholders`, with `incompatible=MarzVanillaGuns`.
- **All ammo is converted: rounds, boxes and cartons.** The full table with round counts is in
  [mapping.md, section C.3](mapping.md#c3-ammo-rounds-boxes-and-cartons).
  - **Only the MarzVanillaGuns 7.62x39 items would be lost**: `Base.762Bullets` / `762Box` /
    `762Carton`. They become `SWMG.762x39_Bullet` / `MarzGuns.762x39_Box` /
    `MarzGuns.762x39_Carton`.
  - **Vanilla ammo would survive, but is converted anyway** so everything matches GoM. The
    targets are GoM's own `VanillaAmmoMap`: rounds → `SWMG.*`, boxes and cartons → `MarzGuns.*`.
  - **Round counts match everywhere except .44.** A vanilla .44 box holds 20 rounds and a GoM box
    holds 25, so .44 boxes and cartons are repacked to the exact count (a box becomes 20 loose
    rounds; a carton becomes 9 boxes + 15 loose rounds).
  - `.308` goes to `SWMG.762x51_Bullet`, which keeps vanilla .308's stats, not to the weaker
    `SWMG.308_Bullet`.
  - Bullet types inside `AmmoList` and `SpentAmmoList` are remapped with the same table. The
    player's `GunworksAmmoPref` is left alone; the framework ignores entries it no longer knows.
  - Use `SWMG.*_Bullet` rounds. GoM's own `MarzGuns.*_Bullet` scripts are orphans.
  - Hot Brass casings belong to Hot Brass and are left alone.
- **Guns with no GoM counterpart convert to the GoM gun with the closest stats**, scored by
  [tools/closest_gun.py](../tools/closest_gun.py) (method in mapping.md C.1):

  | MVG | GoM | Why |
  |---|---|---|
  | `PistolGlock` | `M92FS` | Nearest overall; same 9mm, 15 rounds |
  | `Pistol3` (.44 Desert Eagle) | `SW629` | Near tie with M1911; SW629 matches damage, recoil, noise and the .44 caliber. 8 → 6 rounds, surplus handed back |
  | `SR25_Rifle` | `PSG1` | Clearly nearest; 20 → 5 rounds, surplus stays in a loose magazine |
  | `ShotgunSawnoff` | `REMINGTON_870` | Tie with TRENCHGUN |
  | `AC556` | `M16A3` | Tie with M16A1; keeps Auto |
  | `JS5_smg` | `MP5` | Near-identical stats |

- **Attachments with no counterpart convert to the GoM part with the same function**, mounted
  when the new gun accepts it and handed back loose otherwise (full table in mapping.md C.4). The
  judgement calls:
  - **Choke tubes:** no GoM part changes a shotgun's spread or range, and no muzzle device mounts
    on a GoM shotgun. They become loose `LR2_Compensator` (full) and `LX_Flashhider` (improved).
  - **Recoil pad:** `Shellholder` is the only GoM part that reduces recoil. It is mounted on
    double barrels, `Stub_Foregrip` is mounted on railed rifles, and the pad goes loose as a
    `Shellholder` otherwise.
  - **Heavy pistol silencer:** the SW629 takes no suppressor, so it becomes a loose
    `P45_Suppressor`.
  - **Scopes by magnification:** x2 → `LR4X_Scope` (exact match), x4 → `PSO1_Scope`,
    x8 → `LRX12X_Scope`.
- **`AmmoList`** is an array of bullet full types, one per round; the last entry is the next
  round (the chambered round on a gun).
  - Framework actions append to it (loading), copy it (inserting), split it (ejecting) and pop
    from it (firing, racking).
  - **MarzVanillaGuns' `OnCreate` never writes it**, so guns and magazines can hold rounds with
    no list. The converter builds one from the gun's ammo type (`Convert.roundsOf`).
  - Every entry is remapped through `Map.Rounds` (`Base.762Bullets` → `SWMG.762x39_Bullet`,
    vanilla types included). The list is padded or trimmed from the front to match the round
    count, and rounds beyond the new capacity come out loose.
- **Other modData to translate or reset:**
  - `MagazineType` (full type): translate.
  - `SpentAmmoList` (Hot Brass): remap and copy.
  - `StockFolded` and `BipodDeployed`: copied from the source (`StockFolded` also follows a
    `JS5_Stock_*` part). `GW_BayonetDeployed`: kept only when a bayonet was mounted.
  - `MagazineTypeLastIndex`, `ActiveAmmoProfile`, `GW_CachedBayonetSpear`,
    `GW_BayonetOriginalWeapon`, `GWG_FiringExplosiveAmmo`, `shortRackAfterInsert`: set nil.
- **Visual parts become GoM parts:**
  - `OpenBolt` / `CloseBolt` → GoM's `Slide_` / `Bolt_` / `Pump_` / `Lever_` `Lock` or `Fired`
    part, by gun family.
  - `JS5_Stock_*` → `MP5_Integrated_Stock_*`.
  - `Side_By_Side_Barrel_*` → `DOUBLEBARREL_Barrel_*`.
  - Mounted magazines → the mapped GoM magazine part.
- **Other state to copy:** condition, repairs, name and custom name, favourite, blood, fire mode
  (both mods use `Single` / `Burst` / `Auto`), attached slot fields, and part condition and
  GunLight battery.
- **After converting**, call `StatsFactory.ReapplyAllModifiers`. In multiplayer the server sends
  the whole new item (`sendReplaceItemInContainer` / `sendAddItemToContainer`), so
  `syncHandWeaponFields` and `Ammo.SyncAmmoListToClient` are not needed.

## Still open

- **Load timing:** when scripts are parsed and WorldDictionary initialises relative to Lua file
  loading. Not needed while placeholders ship as script files rather than Lua `DoParam` patches.
- **Whether chunk loading runs `OnCreate`** (see the GoM replacement section).
- **Vanilla revolvers** (`Base.Revolver`, `Revolver_Long`, `Revolver_Short`) are rerolled to a
  random same-caliber GoM handgun (see mapping.md C.1), so their ammo compatibility no longer
  matters.
- **Everything the offline tests cannot show** (see implementation.md, "Tests"): stat changes
  from parts, `StatsFactory` restores, MP sync of replaced items, hotbar refresh, and
  `swapItem` on floor items.
- **Whether B42 saves a gun's or magazine's ammo type by AmmoType registry id.** Probably not:
  neither the `InventoryItem.save` nor the `HandWeapon.save` field list above includes
  `ammoType`. If it does, `mvgi:bullets_762` may need registering during the migration.
