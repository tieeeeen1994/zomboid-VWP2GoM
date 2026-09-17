# How to use VWP2GoM

VWP2GoM moves a save from **Vanilla Weapons Plus - Gunworks Edition** to **Guns of Marz**. Every
gun, magazine, attachment, round, box and carton in the save is turned into its Guns of Marz
version.

## Read this first

**If a save ever loads without Vanilla Weapons Plus and without VWP2GoM Placeholders, every
Vanilla Weapons Plus item in it is deleted.** Once the game saves after that, the items cannot be
recovered.

This includes loading "just to look around". Every time the save loads, one of these must be on:
- **Vanilla Weapons Plus**
- **VWP2GoM Placeholders**

## What you need

These mods, all enabled for this save:

| Mod | Mod id |
|---|---|
| Gunworks-gang | `SWMG` |
| Guns of Marz | `GunsOfMarz` |
| VWP2GoM | `VWP2GoM` |
| VWP2GoM Placeholders | `VWP2GoM_Placeholders` |

## Single player

1. **Back up your save.** Close the game and copy the save's folder from `Zomboid/Saves/`
   somewhere safe.
2. **Optional, but safest:** load the save once with these mods on, then save and quit:
   - Vanilla Weapons Plus
   - Gunworks-gang
   - Guns of Marz
   - VWP2GoM

   Everything you carry and every area that loads is converted while Vanilla Weapons Plus is still
   there.
3. In the mod list for the save:
   - **Turn off:** Vanilla Weapons Plus
   - **Turn on:** Gunworks-gang, Guns of Marz, VWP2GoM, VWP2GoM Placeholders

   The mod list will not let you turn on VWP2GoM Placeholders while Vanilla Weapons Plus is on.
   That is on purpose.
4. **Load the save.** Don't start the game with `-debug` for this load.
5. **Check the log** (see below). Save and keep playing.
6. **Leave VWP2GoM and VWP2GoM Placeholders turned on.** Items in places you have not been yet
   still use the old guns. They are converted the first time you go there.

## Dedicated server

1. **Stop the server and back up the world:** `Zomboid/Saves/Multiplayer/<server name>/` and
   `Zomboid/db/<server name>.db`.
2. In `Zomboid/Server/<server name>.ini`:
   - Remove Vanilla Weapons Plus from `Mods=` and `WorkshopItems=`.
   - Add Guns of Marz, VWP2GoM and VWP2GoM Placeholders to both lines.
   - `Mods=` must include `SWMG;GunsOfMarz;VWP2GoM;VWP2GoM_Placeholders`.
3. **Start the server.** Players download the mods when they join; every client needs them.
4. **Players join as normal.** Each player's inventory is converted as they log in. The world
   converts as areas load.
5. **Check the server's log** (see below).
6. **Leave both VWP2GoM mods in the mod list.**

## What happens to your stuff

- **Guns** become the Guns of Marz version of the same gun, for example M9 → M92FS, M4 → M4A1 and
  AK-47 → AK47.
  - **Guns with no Guns of Marz version** become the closest one: Glock 17 → M92FS, .44 Desert
    Eagle → S&W 629, SR-25 → PSG1, sawn-off pump → Remington 870, JS-556 → M16A3, JS5 → MP5.
  - **Vanilla revolvers** become a random Guns of Marz revolver of the same caliber.
- **A converted gun keeps:**
  - its loaded magazine and chambered round
  - its condition, repairs, custom name and favourite star
  - where it was: in your hands, on your back or holster, in your hotbar, in a bag, in a
    container or on the floor
- **Attachments** are refitted as the Guns of Marz part that does the same job, including any
  rail or mount the part needs.
- **Magazines** become the matching Guns of Marz magazine with the same rounds in them.
- **Ammo** becomes Guns of Marz ammo with exactly the same number of rounds. A .44 carton becomes
  9 boxes and 15 loose rounds, because a Guns of Marz .44 box holds 25.
- **Nothing is thrown away.** Anything that no longer fits is put right next to the gun:
  - rounds over the new magazine's size
  - a magazine the new gun can't use
  - an attachment with nowhere to mount

## The log

Every conversion is written as one line to `VWP2GoM.log`:

- single player: `Zomboid/Lua/VWP2GoM.log`
- dedicated server: `Zomboid/Lua/VWP2GoM.log` on the server

```
Base.PistolGlock [cond 7/10, ammo 12+1, mag] -> MarzGuns.M92FS [cond 7/10, ammo 12+1, mag] | none on Player
```

That line reads: a Glock at 7/10 condition, holding 12 rounds plus one chambered with a magazine
in, became an M92FS with the same, in the player's inventory.

**A line starting with `FAILED`** means that item was left exactly as it was. It is retried the
next time that area or player loads. If it keeps failing, send the line and `Zomboid/console.txt`
to the mod author.

## Questions

**Can I remove VWP2GoM later?** Only once you are sure no old items remain anywhere in the world.
Areas nobody has visited still hold them. Removing VWP2GoM Placeholders deletes those items, so the
safe choice is to keep both mods on.

**Why does new loot give me random guns?** That is Guns of Marz's own "replace vanilla weapons"
sandbox option. VWP2GoM leaves new loot to Guns of Marz and only converts items that already exist
in your save.

**Can I use it on a new save?** Yes, but there is nothing to convert. It is only needed for saves
that used Vanilla Weapons Plus.
