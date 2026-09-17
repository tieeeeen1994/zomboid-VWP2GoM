# MarzVanillaGuns (MVG) -> GunsOfMarz (GoM) migration research

Paths (W = `~/Library/Application Support/Steam/steamapps/workshop/content/108600`):
- MVG: `W/3773834525/mods/MarzVanillaGuns/42.18` (mod id `MarzVanillaGuns`, requires `SWMG`, module `Base`)
- GoM: `W/3722134990/mods/GunsOfMarz/42.16` (mod id `GunsOfMarz`, requires `SWMG`, module `MarzGuns`; GoM `incompatible=` list does NOT include MarzVanillaGuns -> both can be loaded at once, which the migration needs)
- Framework: `W/3722064198/mods/Gunworks_gang_framework/42.13` (mod id `SWMG`, ammo item module `SWMG`)
- Hot Brass: `W/3610677934/mods/{Hot_Brass_Visible_Casing_Ejection_Framework (HBVCEFb42), Hot_Brass_Tactical_Reload, Hot_Brass_Ammo_Crafting}`

## 0. Critical findings up front

1. **Many MVG items reuse vanilla IDs** (Base.Pistol, Base.9mmClip, Base.x4Scope ...). MVG *overrides* them. Most importantly MVG turns vanilla magazines (`Base.9mmClip`, `44Clip`, `45Clip`, `M14Clip`, `JS14_Clip`, `556Clip`) from `ItemType=base:normal` into `base:weaponpart` / `PartType=Clip` so they can be mounted as visual parts. Once MVG is removed, those IDs revert to vanilla *normal* items and every MVG-only ID (e.g. `Base.OpenBolt`, `Base.556Clip_75`, `Base.AR_Silencer`) disappears. A weapon whose saved part list contains them will load broken. **The migration must run while MVG is still enabled** (MVG + GoM + SWMG all active), then MVG is removed.
2. **No Glock and no SR-25 and no .44 Desert Eagle in GoM.** GoM DEAGLE is .50 AE (caliber mismatch). No sawn-off pump shotgun, no select-fire Mini-14, no chokes / recoil pads / ammo straps / heavy-pistol suppressor.
3. **Vanilla ammo does NOT need converting**: GoM `Registries/Ammunition.lua` adds vanilla bullet types into its families (`Base.Bullets9mm`, `Base.Bullets45`, `Base.Bullets44`, `Base.Bullets38`, `Base.Bullets357`, `Base.556Bullets`, `Base.308Bullets`, `Base.3030Bullets`, `Base.ShotgunShells`). GoM guns/mags accept them and AmmoList entries with those types are valid. Only **`Base.762Bullets` / `Base.762Box` / `Base.762Carton` (MVG-only)** must be converted -> `SWMG.762x39_Bullet` / `MarzGuns.762x39_Box` / `MarzGuns.762x39_Carton`.
4. **GoM round items `MarzGuns.*_Bullet` are orphans**: framework `registries.lua` registers every `swmg:*` AmmoType to `SWMG.*_Bullet`, GoM's ammo families and all GoM recipes use `SWMG.*_Bullet`. The `MarzGuns.9x19_Bullet` etc. scripts exist (same AmmoType) but nothing references them. Always convert rounds to `SWMG.*`.
5. MVG `OnCreate` never writes `AmmoList`; GoM `OnCreate` does. MVG-spawned guns/mags that were never hand-reloaded have `currentAmmoCount>0` with no `AmmoList` -> migration should synthesize one.
6. MVG `RPM.lua` registers `"Base.AK47"` (typo) instead of `Base.AssaultRifleAK47`, so the MVG AK never had a RoF profile. Irrelevant for state (no modData), just FYI.
7. MVG `registries.lua` registers AmmoTypes `mvgi:bullets_762 -> Base.762Bullets` and `mvgi:bullets_223 -> Base.223Bullets` (the latter item doesn't exist). If HandWeapon/magazine saves reference the AmmoType registry id, keeping a stub registration in the migration mod (`AmmoType.register("mvgi:bullets_762","SWMG.762x39_Bullet")`) for one release is a cheap safety net (not verified whether B42 serialises ammoType by id).

---

## A. MarzVanillaGuns catalogue

Script files: `media/scripts/MarzVanillaWeapons/items/{weapons,magazines,attachments,ammo,melee,generic,fixing,recipes}.txt` (all `module Base`). fixing.txt only has `fixing` blocks (M93R, Glock 17, M16A3, M4, SR25, JS-556, Side-by-Side, MP5, MP5SD). recipes.txt: open/pack 762 box (20 rounds) and carton (12 boxes), and `SawOffShotgun_mvgi` (Side_By_Side_Barrel_Open/Close -> Side_By_Side_Barrel_Sawnoff_Close).

"Vanilla?" = whether B42 vanilla `media/scripts` defines the same full type (checked by parsing all vanilla scripts).

### A.1 Weapons (all ItemType=base:weapon, SubCategory Firearm, OnCreate=MarzVanillaGuns_OnCreate.AttachParts unless noted)

| Full type | Vanilla? | DisplayName (MVG/vanilla) | Class | AmmoType (caliber) | MagazineType | MaxAmmo | FireModes (default) | ReloadType | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Base.Pistol | yes | M9 (Beretta 92) | pistol | base:bullets_9mm (9x19) | Base.9mmClip | 15 | single | handgun | slide = OpenBolt/CloseBolt; parts GunLight, Laser, Pistol_Silencer, TritiumSights |
| Base.PistolGlock | no | Glock 17 Pistol | pistol | base:bullets_9mm | Base.9mmClip | 15 | single | handgun | same parts |
| Base.Pistolm93r | no | M93R Pistol | pistol (burst) | base:bullets_9mm | Base.9mmClip | 15 | Single/Burst (Burst) | handgun | RPM 950, burst 3 |
| Base.Pistol2 | yes | M1911 | pistol | base:bullets_45 (.45 ACP) | Base.45Clip | 7 | single | handgun | |
| Base.Pistol3 | yes | D-E (Desert Eagle) | heavy pistol | base:bullets_44 (.44 Mag) | Base.44Clip | 8 | single | handgun | Heavy_Pistol_Silencer |
| Base.AssaultRifle | yes | M16A2 Assault Rifle | AR | base:bullets_556 (5.56) | Base.556Clip | 30 | Burst/Single (Burst) | boltaction | RPM 800 burst 3; mag profile STANAG; bayonet |
| Base.AssaultRifleA3 | no | M16A3 Assault Rifle | AR | base:bullets_556 | Base.556Clip | 30 | Auto/Single (Auto) | boltaction | RPM 800; STANAG; bayonet; 556Muzzle 100% on spawn |
| Base.AssaultRifleM4 | no | M4 Carbine | AR carbine | base:bullets_556 | Base.556Clip | 30 | Auto/Single (Auto) | boltaction | RPM 800; STANAG; bayonet; 556Muzzle 100% |
| Base.AssaultRifleAK47 | no | AK-47 Assault Rifle | AR | mvgi:bullets_762 (7.62x39) | Base.762Clip_30 | 30 | Auto/Single (Auto) | boltaction | mag profile 762x39; bayonet; 762Muzzle 100%; RPM entry mis-keyed "Base.AK47" |
| Base.AssaultRifle2 | yes | M14 | battle rifle | base:bullets_308 | Base.M14Clip | 20 | Single | boltaction | bayonet |
| Base.SR25_Rifle | MarzGuns.PSG1 | **Closest stats** | No SR-25 in GoM. PSG1 is clearly nearest (1.44; M14 1.97, FAL 2.01): semi-auto 7.62x51, damage 1.2-2.0 vs 1.0-1.8, recoil 20 = 20, weight 4.5 = 4.5, aim 50 vs 45. Capacity 20 -> 5: the gun keeps 5 rounds in a `762x51Magazine5_PSG1`, and the surplus stays in a loose M14 magazine (see C.2). |
| Base.Shotgun | yes | JS-2000 | pump shotgun | base:shotgun_shells | - | 5 | Single | shotgun | pump = OpenBolt/CloseBolt; chokes, RecoilPad, AmmoStraps |
| Base.ShotgunSawnoff | MarzGuns.REMINGTON_870 | **Closest stats** | No sawn-off pump in GoM. REMINGTON_870 and TRENCHGUN tie at 1.71 (MOSSBERG_590 1.73); the 870 is chosen as the plainer civilian pump. 5 shells = 5. |
| Base.VarmintRifle | yes | MSR700 | bolt rifle | base:bullets_556 | - | 5 | Single | boltactionnomag | |
| Base.HuntingRifle | yes | MSR788 | bolt rifle | base:bullets_308 | - | 4 | Single | boltactionnomag | |
| Base.MSR7T_Rifle | yes | MSR-7T | tactical bolt rifle | base:bullets_308 | - | 4 | Single | boltactionnomag | Laser capable |
| Base.JS3T_Shotgun | yes | JS-3T | pump shotgun (RackAfterShoot) | base:shotgun_shells | - | 7 | Single | shotgun | chokes, RedDot |
| Base.JS14_Rifle | yes | JS-14 | semi rifle | base:bullets_556 | Base.JS14_Clip | 20 | Single | boltaction | mag profile JS14 |
| Base.AC556 | no | JS-556 Rifle | select-fire carbine (Ruger AC-556 look) | base:bullets_556 | Base.JS14_Clip | 30 | Auto/Single (Auto) | boltaction | RPM 750; JS14 profile; ModelWeaponPart has bayonet but not registered bayonet-mountable |
| Base.L92_Carbine | yes | L92 | lever carbine | base:bullets_357 | - | 10 | Single | leveraction | |
| Base.L94_Rifle | yes | L94 | lever rifle | base:bullets_3030 | - | 6 | Single | leveraction | |
| Base.TrapperCarbine | yes | Trapper Carbine | pistol-caliber carbine | base:bullets_45 | Base.45Clip | 7 | Single | boltaction | 45Clip visual magazine |
| Base.JS5_smg | MarzGuns.MP5 | **Closest stats** | Fictional 9mm SMG. MP5 is clearly nearest (0.47; MP5A2 0.65): identical damage 1.0-1.6, hit 50, aim 40, recoil 15, range 30, 30 rounds. Burst is lost (GoM MP5 is Auto/Single). Folding stock maps to `MP5_Integrated_Stock_*`. |
| Base.MP5_SMG | no | MP5 SMG | SMG | base:bullets_9mm | Base.9mmClip_25 | 30 | Auto/Single/Burst (Auto) | boltaction | RPM 850; profile "9mm MP5" |
| Base.MP5SD_SMG | no | MP5SD SMG | suppressed SMG | base:bullets_9mm | Base.9mmClip_25 | 30 | Auto/Single/Burst | boltaction | |
| Base.DoubleBarrelShotgun | yes | Double Barrel Shotgun | break-action | base:shotgun_shells | - | 2 | Single | doublebarrelshotgun | ManuallyRemoveSpentRounds; OnCreate AttachParts (no bolt) |
| Base.DoubleBarrelShotgunSawnoff | yes | DB sawn-off | break-action | base:shotgun_shells | - | 2 | Single | doublebarrelshotgunsawn | no OnCreate |
| Base.Side_By_Side | no | Side by Side Shotgun | break-action SxS | base:shotgun_shells | - | 2 | Single | doublebarrelshotgun | barrel part state (Side_By_Side_Barrel_*); canShoot requires Barrel part |

(`Base.Side_By_Side_Sawnoff` appears in ItemName.json and HotBrass params but has no item script.)

### A.2 Magazines (MVG: all ItemType=base:weaponpart, PartType=Clip, CanStack=false, CanAttach=MarzVanillaGuns_AttachAndDetach.IsMagazine, all PreventRemoval)

| Full type | Vanilla? (vanilla ItemType) | DisplayName | AmmoType | MaxAmmo | MountOn | MVG mag profile |
|---|---|---|---|---|---|---|
| Base.9mmClip | yes (normal) | 9mm magazine | bullets_9mm | 15 | Pistol, Pistolm93r, PistolGlock | none (vanilla MagazineType) |
| Base.44Clip | yes (normal) | .44 magazine | bullets_44 | 8 | Pistol3 | none |
| Base.45Clip | yes (normal) | .45 magazine | bullets_45 | 7 | Pistol2 (GunType also TrapperCarbine) | none |
| Base.M14Clip | yes (normal) | M14 magazine | bullets_308 | 20 | AssaultRifle2 | none |
| Base.JS14_Clip | yes (normal) | JS14 20-Round Magazine | bullets_556 | 20 | JS14_Rifle, AC556 | JS14 |
| Base.JS14_Clip_30 | no | JS14 30-Round Magazine | bullets_556 | 30 | JS14_Rifle, AC556 | JS14 |
| Base.JS5_Clip | no | "JS5 20-Round Magazine" (actually MaxAmmo 30) | bullets_9mm | 30 | JS5_smg | none |
| Base.556Clip_20 | no | 5.56mm 20-Round Magazine | bullets_556 | 20 | AssaultRifle, A3, M4 | STANAG |
| Base.556Clip | yes (normal) | 5.56mm 30-Round Magazine | bullets_556 | 30 | AssaultRifle, A3, M4 | STANAG |
| Base.556Clip_75 | no | 5.56mm 75-Round Magazine | bullets_556 | 75 | AssaultRifle, A3, M4 | STANAG |
| Base.308Clip_10 | MarzGuns.762x51Magazine20_M14 | M | Loose magazine: capacity rises, no loss. Inside a converted SR25 (now PSG1) the host-dependent rule applies: the gun gets a `762x51Magazine5_PSG1` holding at most 5 rounds, and the original magazine is also handed back as a loose M14 magazine holding the surplus rounds. |
| Base.308Clip_20 | MarzGuns.762x51Magazine20_M14 | M | Same as `308Clip_10`. Two MVG types collapse into one GoM type. |
| Base.762Clip_30 | no | 7.62x39mm 30-Round Magazine | mvgi:bullets_762 | 30 | AssaultRifleAK47 | 762x39 |
| Base.762Clip_75 | no | 7.62x39mm 75-Round Magazine | mvgi:bullets_762 | 75 | AssaultRifleAK47 | 762x39 |
| Base.9mmClip_25 | no | 9mm 25-Round Magazine | bullets_9mm | 25 | MP5_SMG, MP5SD_SMG | 9mm MP5 |
| Base.9mmClip_30 | no | 9mm 30-Round Magazine | bullets_9mm | 30 | MP5, MP5SD | 9mm MP5 |
| Base.9mmClip_40 | no | 9mm 40-Round Magazine | bullets_9mm | 40 | MP5, MP5SD | 9mm MP5 |
| Base.9mmClip_100 | no | 9mm 100-Round Magazine | bullets_9mm | 100 | MP5, MP5SD | 9mm MP5 |

### A.3 Ammo (MVG-defined)

| Full type | Vanilla? | Name | ItemType | Notes |
|---|---|---|---|---|
| Base.762Bullets | no | 7.62x39mm Round | normal (tag base:ammo) | AmmoType registry `mvgi:bullets_762`; AmmoMaker map 762x39; HotBrass casing HBVCEF.762x39_Casing |
| Base.762Box | no | Box of 7.62x39mm Rounds | normal | 20 rounds (recipe OpenBoxOfBullets20_mvgi) |
| Base.762Carton | no | Carton of 7.62x39mm Rounds | normal | 12 boxes |
| (Base.223Bullets) | no | ".223 Round" (translation only) | - | registered `mvgi:bullets_223` but no script -> never exists |

Vanilla ammo used by MVG guns (not redefined by MVG): Base.Bullets9mm/Box/Carton (box 50), Base.Bullets45/Box/Carton (50), Base.Bullets44/Box/Carton (20), Base.Bullets357/Box/Carton (50), Base.556Bullets/556Box/556Carton (20), Base.308Bullets/308Box/308Carton (20), Base.3030Bullets/Box/Carton (20), Base.ShotgunShells/Box/Carton (25). Carton = 12 boxes.

### A.4 Attachments (all ItemType=base:weaponpart, CanAttach=MarzVanillaGuns_AttachAndDetach.requiredTools)

| Full type | Vanilla? | PartType | MVG MountOn | Tools | Custom stats (MVG AttachmentCustomStats) |
|---|---|---|---|---|---|
| Base.x2Scope | yes | Scope | HuntingRifle, VarmintRifle, AssaultRifle, AssaultRifle2, JS14_Rifle, Revolver_Long, TrapperCarbine, MSR7T_Rifle, A3, AK47, M4, SR25, MP5, MP5SD, AC556 | screwdriver | vanilla script stats |
| Base.x4Scope | yes | Scope | same minus Revolver_Long/MP5/MP5SD | screwdriver | |
| Base.x8Scope | yes | Scope | HuntingRifle, VarmintRifle, MSR7T_Rifle | screwdriver | |
| Base.AmmoStraps | yes | Sling | HuntingRifle, VarmintRifle, Shotgun, ShotgunSawnoff, DoubleBarrelShotgun, JS3T, L92, L94, MSR7T | screwdriver | |
| Base.TritiumSights | yes | Scope | Pistol, PistolGlock, Pistol2, Pistol3, Pistolm93r | screwdriver | |
| Base.RecoilPad | yes | RecoilPad | AssaultRifle2, HuntingRifle, VarmintRifle, Shotgun, DoubleBarrelShotgun, MSR7T, L94, SR25 | screwdriver | |
| Base.Laser | yes | Canon | pistols (Pistol, Glock, Pistol2, Pistol3, M93R), AssaultRifle, AssaultRifle2, TrapperCarbine, MSR7T, A3, AK47, M4, SR25, MP5, MP5SD, AC556 | screwdriver | |
| Base.RedDot | yes | Scope | AssaultRifle, AssaultRifle2, JS14, JS3T, TrapperCarbine, A3, AK47, M4, SR25, MP5, MP5SD, AC556 | screwdriver | |
| Base.GunLight | yes | Canon (tags flashlight, usesbattery) | pistols (5), MP5, MP5SD | screwdriver | |
| Base.ChokeTubeFull | yes | Canon | Shotgun, DoubleBarrelShotgun | screwdriver | |
| Base.ChokeTubeImproved | yes | Canon | Shotgun, DoubleBarrelShotgun | screwdriver | |
| Base.Pistol_Silencer | no | Muzzle | Pistol, Glock, Pistol2, M93R | wrench | SoundRadius/Volume x0.3, Min/MaxDamage x0.9, SwingSound CapGunRifleShoot, no muzzle flash |
| Base.Heavy_Pistol_Silencer | no | Muzzle | Pistol3 | wrench | same, CapGunRevolverShoot |
| Base.AR_Silencer | no | Muzzle | AssaultRifle, A3, AK47, M4 | wrench | same; exclusive with M9 bayonet |
| Base.556Muzzle | no | Muzzle | A3, M4 | wrench | Sound x0.99 |
| Base.762Muzzle | no | Muzzle | AK47 | wrench | Sound x0.99 |
| Base.M9_Bayonet_Attachment | no | BayonetKnife | (MountOn GenericFakeItem; mounted via Bayonet system) | - | PreventRemoval |
| Base.Side_By_Side_Barrel_Close | no | Barrel | Side_By_Side | wrench+screwdriver | |
| Base.Side_By_Side_Barrel_Open | no | Barrel | Side_By_Side | | |
| Base.Side_By_Side_Barrel_Sawnoff_Close | no | Barrel | Side_By_Side | | AimingTime 30, HitChance 70, ProjectileSpread 2.0 |
| Base.Side_By_Side_Barrel_Sawnoff_Open | no | Barrel | Side_By_Side | | same |

### A.5 Melee / generic (internal)

| Full type | Vanilla? | ItemType | PartType | Meaning |
|---|---|---|---|---|
| Base.M9_Bayonet | no | weapon (knife, Stab, smallblade) | - | real knife item; registered bayonet knife -> attachment Base.M9_Bayonet_Attachment -> spear Base.Attack_Bayonet |
| Base.Attack_Bayonet | no | weapon (spear, improvised) | - | temporary spear substitute used for bayonet melee ("Do not spawn me") |
| Base.GenericFakeItem | no | normal | - | dummy MountOn target for internal parts |
| Base.OpenBolt | no | weaponpart | MovingBolt | action open (slide/bolt/pump/lever back) visual state |
| Base.CloseBolt | no | weaponpart | MovingBolt | action closed/locked visual state (required on spawn) |
| Base.JS5_Stock_Folded | no | weaponpart | StockIntegrated | JS5 stock folded visual |
| Base.JS5_Stock_Deployed | no | weaponpart | StockIntegrated | JS5 stock deployed visual |

### A.6 MVG Lua registries

- `media/registries.lua`: `MarzVanillaGuns_AmmoTypes.BULLET_762x39 = AmmoType.register("mvgi:bullets_762","Base.762Bullets")`, `BULLET_223 = AmmoType.register("mvgi:bullets_223","Base.223Bullets")`.
- `Registries/Ammunition.lua`: RestoreStats {MaxDamage, MinDamage, CritDmgMultiplier, CriticalChance, ConditionLowerChanceOneIn}; item->family `.38 .357` = {Base.Revolver, Base.Revolver_Short}; family `.38 .357` = {Base.Bullets357 profile 357MagnumAmmo, Base.Bullets38 profile 38SpecialAmmo}; profile 38SpecialAmmo (dmg x0.8 etc.). No other families -> all other MVG guns have no ammo family (AmmoList still maintained by framework hooks).
- `Registries/Magazines.lua`: profiles STANAG {556Clip_20, 556Clip, 556Clip_75}; 762x39 {762Clip_30, 762Clip_75}; 762x51 {308Clip_10, 308Clip_20}; "9mm MP5" {9mmClip_25/30/40/100}; JS14 {JS14_Clip, JS14_Clip_30}. Weapons: STANAG={AssaultRifle, A3, M4}; 762x39={AK47}; 762x51={SR25}; "9mm MP5"={MP5_SMG, MP5SD_SMG}; JS14={JS14_Rifle, AC556}.
- `Registries/Stocks.lua`: FoldingStock JS5_smg {partType StockIntegrated, folded Base.JS5_Stock_Folded, deployed Base.JS5_Stock_Deployed, initialState folded}.
- `Registries/Bayonets.lua`: mountable {Base.M9_Bayonet_Attachment} on {AssaultRifle, AssaultRifle2, AK47, A3, M4}; knife Base.M9_Bayonet -> attachment -> spear Base.Attack_Bayonet; exclusive with Base.AR_Silencer.
- `Registries/RPM.lua`: AssaultRifle/A3/M4 800, "Base.AK47" 650 (typo), Pistolm93r 950, JS5 850, MP5 850, MP5SD 850, AC556 750; all burstCount 3, spread on. No multi-stage RPM -> no GW_RpmStage.
- `Registries/PermanentAttachments.lua` (PreventRemoval): all 17 magazines, CloseBolt, OpenBolt, M9_Bayonet_Attachment, JS5_Stock_Folded/Deployed.
- `Registries/VanillaAnimated.lua` (Animations): SingleAttachment {open=Base.OpenBolt, locked=Base.CloseBolt} for Pistol, Glock, M93R, Pistol2, Pistol3, Shotgun, ShotgunSawnoff, VarmintRifle, HuntingRifle, MSR7T, JS3T, L92, L94, TrapperCarbine; same with cycleTicks 3 for AssaultRifle, AssaultRifle2, AK47, A3, M4, SR25, JS14, MP5, MP5SD, AC556; Side_By_Side uses MultipleAttachmentsVariant on PartType Barrel (normal pair Open/Close, sawnoff pair Sawnoff_Open/Sawnoff_Close). JS5 and DoubleBarrelShotgun not animated.
- `Registries/AttachmentCustomStats.lua`: see A.4 column.
- `OnCreate/AttachAndDetach.lua`: tool requirements Muzzle wrench; Canon/Scope/Sling/RecoilPad screwdriver; Barrel wrench+screwdriver.
- `Hooks/CustomHooks.lua`: Side_By_Side cannot shoot without Barrel part; ISUpgradeWeapon:complete replaces an installed `*_Open` barrel with its `*_Close` counterpart.
- `Hooks/ItemAdjustment.lua`: with Hot Brass, sets 762Bullets/223Bullets world model + icon.
- `server/.../Distribution/ItemInsertion.lua`: inserts Pistolm93r/PistolGlock next to Pistol, A3/M4/AK47/MP5/MP5SD next to AssaultRifle, 762Box/Carton next to 556, SR25 next to AssaultRifle2, Side_By_Side next to DoubleBarrelShotgun, AC556 next to JS14/MP5, silencers next to Laser/GunLight; zombie AttachedWeaponDefinitions: Glock, A3, MP5, SR25, AC556, Side_By_Side. `WeaponUpgrades.lua` empties vanilla `WeaponUpgrades` table.
- `server/.../HotBrass/CustomOverwriteAndParams.lua`: casing ejection params per weapon (AssaultRifle, AK47, A3, M4, AssaultRifle2, HuntingRifle, MSR7T, L92, L94, Pistol, M93R, Pistol2, Pistol3, Revolver_Long/Short/Revolver, Side_By_Side, Side_By_Side_Sawnoff), casing map Base.762Bullets -> HBVCEF.762x39_Casing, overrides SpentCasingPhysics.doSpawnCasing. No persistent state.
- `ammomaker_apiTablesVanillaGuns.lua`: Ammo Maker map Base.762Bullets -> 762x39. `IAData_Marz.lua`: ItemArrange profiles for 762Box/Carton.

### A.7 MVG OnCreate (`OnCreate/AttachmentsOnCreate.lua`, `MarzVanillaGuns_OnCreate.AttachParts`)

Per weapon: attach every `required` part, then roll each `optional` "Type:chance" (`random(100) < chance`).
- required `Base.CloseBolt` on every weapon except DoubleBarrelShotgun (no required) and Side_By_Side (required `Base.Side_By_Side_Barrel_Close`).
- optionals: AssaultRifle {556Clip_20:40, 556Clip:20, 556Clip_75:2, x2Scope:10, x4Scope:10, Laser:10, RedDot:10, AR_Silencer:2, M9_Bayonet_Attachment:2}; AK47 {762Clip_30:20, 762Clip_75:2, x2/x4/Laser/RedDot:10, 762Muzzle:100, AR_Silencer:2, bayonet:2}; A3 and M4 {556 mags as AR, scopes/laser/reddot 10, 556Muzzle:100, AR_Silencer:2, bayonet:2}; AssaultRifle2 {M14Clip:40, x2/x4/RecoilPad/Laser/RedDot:10, bayonet:2}; SR25 {308Clip_10:40, 308Clip_20:20, x2/x4/RecoilPad/Laser/RedDot:10}; Pistol, Glock, M93R {9mmClip:40, TritiumSights/Laser/GunLight:10, Pistol_Silencer:2}; Pistol2 {45Clip:40, ...Pistol_Silencer:2}; Pistol3 {44Clip:40, ..., Heavy_Pistol_Silencer:2}; Shotgun {AmmoStraps:10, RecoilPad:10, ChokeTubeImproved:10, ChokeTubeFull:5}; ShotgunSawnoff {AmmoStraps:10}; JS3T {AmmoStraps:10, RedDot:10}; JS14 {JS14_Clip:40, JS14_Clip_30:20, x2/x4/RedDot/Laser:10}; VarmintRifle, HuntingRifle {x2/x4/x8/AmmoStraps/RecoilPad:10}; MSR7T {same + Laser:10}; TrapperCarbine {45Clip:40, x2/x4/Laser/RedDot:10}; L92 {AmmoStraps:10}; L94 {AmmoStraps:10, RecoilPad:10}; MP5, MP5SD {9mmClip_25:40, _30:20, _40:5, _100:1, x2Scope/Laser/RedDot/GunLight:10}; DoubleBarrelShotgun {AmmoStraps/RecoilPad/ChokeTubeImproved:10, ChokeTubeFull:5}; Side_By_Side {Side_By_Side_Barrel_Sawnoff_Close:10}; AC556 {JS14_Clip:40, JS14_Clip_30:20, x2/x4/RedDot:10}. (JS5_smg has no table entry -> nothing attached; its stock comes from FoldingStock restore.)
- Then: if a `BayonetKnife` part is present -> `modData.GW_BayonetDeployed = true`.
- If `weapon:getMagazineType() == nil` (tube/internal guns) -> `setCurrentAmmoCount(random(1..MaxAmmo))`.
- If a `Clip` part is present -> `setMaxAmmo(mag MaxAmmo)`, `setMagazineType(mag fullType)`, `setCurrentAmmoCount(random(1..magMax))`, `setContainsClip(true)`, `modData.MagazineType = mag fullType`; else `setContainsClip(false)`.
- **No AmmoList is written** (contrast GoM OnCreate). Note: the Clip part mounted on the gun is the *visual* of the inserted magazine; its own currentAmmoCount is irrelevant (the rounds live on the weapon).

---

## B. GunsOfMarz catalogue (mapping-relevant)

Scripts: `media/scripts/MarzWeapons/items/{weapons/*,ammunition/*,attachments/*,spawners/spawners.txt,generic.txt,fx}` (module MarzGuns). Full generated tables (B.1-B.4) follow this summary.

### B.0 Summary of GoM systems relevant to mapping

**Ammo** (`Registries/Ammunition.lua`, framework `registries.lua`, `Hooks/AmmoPatch.lua`):
- AmmoType ids `swmg:*` are registered by the framework to `SWMG.*` round items (module SWMG, `scripts/AmmunitionLibrary/ammo.txt`); `AmmoPatch.lua` only restyles those SWMG rounds (icon/model/weight). Rounds to use: SWMG.9x19_Bullet, 45_Bullet, 38_Bullet, 357_Bullet, 44_Bullet, 50_Bullet, 223_Bullet, 556x45_Bullet(+_HollowPoint/_ArmorPiercing/_Subsonic/_Overpressured), 545x39_Bullet, 762x39_Bullet, 3030_Bullet, 308_Bullet, 762x51_Bullet, 4570_Bullet, 762x54_Bullet, 9x39_Bullet, 12Gauge_Shell_Buckshot/_Slug, 3006_Bullet, 40mm_Round_*, Rocket_PG7V.
- Families (bullet type -> profile): `5.56x45mm` {SWMG.556x45 (base), SWMG.223 (civilian), AP, HP, +P, Subsonic, **Base.556Bullets** (base)}; `7.62x51mm` {SWMG.762x51, SWMG.308 (civilian), **Base.308Bullets**}; `12Gauge` {buck, slug, **Base.ShotgunShells**}; `.30-30 Winchester` {SWMG.3030, **Base.3030Bullets**}; `.38 .357` {SWMG.357, SWMG.38, **Base.Bullets357**, **Base.Bullets38**}; `.44 Magnum` {SWMG.44, **Base.Bullets44**}; `.50 AE` {SWMG.50}; `.45 ACP` {SWMG.45, **Base.Bullets45**}; `9x19mm` {SWMG.9x19, **Base.Bullets9mm**}; `5.45x39mm`, `7.62x39mm` {SWMG.762x39 only}, `9x39mm`, `.30-06`, `7.62x54mm`, `40mm`, `.45-70 Government`.
- Items -> family: magazines (all GoM mags), plus non-magazine guns (MODEL_70, REMINGTON_700, M24, all shotguns, W1894, PYTHON/RHINO/W1873/W1873_CARBINE/MP412/DETECTIVE_38, SW629, COLT_SINGLE, SKS, M1903, M79, M203_Weapon, M1895). Mag-fed guns resolve ammo through the inserted magazine / AmmoList.
- `Hooks/ItemPatcher.lua` additionally registers every script item whose AmmoType is a vanilla enum into the matching GoM family (so vanilla guns and vanilla magazines also get families) and, if sandbox `MarzGuns.VanillaWeaponReplacement/VanillaAmmoReplacement/VanillaAttachmentReplacement` is on, sets OnCreate=`MarzGuns_OnCreate.VanillaReplace` on vanilla guns/mags/ammo/attachments (affects only newly created items, never existing ones).
- Box sizes (tags): 50 rounds = 9x19, 45, 38, 357 boxes; 25 = 12ga, 44, 50; 20 = 762x51, 308, 762x54, all 556 variants, 223, 545x39, 762x39, 9x39, 3006, 3030, 4570; 10 = 40mm. Carton = 12 boxes, Crate = 4 cartons. Vs vanilla: identical counts except .44 box (vanilla 20, GoM 25).

**Magazine profiles** (`Registries/Magazines.lua`): STANAG {20,25,30,50,60,75,100,150} -> M16A1, M16A2, M16A2_M203, M16A3, AR15, FNC, FAMAS, CAR15, XM177, M4A1; 545x39 {30,45,100 drum} -> AK74, AKS74U; AA12 {8,20}; "9x19 M92FS" {15,30,50} -> M92FS; "9x19 M93R" {18,60} -> M93R; ".45 USP" {12,20}; ".50 Deagle" {8,12} -> DEAGLE; ".45 Thompson" {20,30,100}; "9x19mm MP5" {20,25,30,60,100} -> MP5, MP5K, MP5A2, MP5SD; 762x39 {30,75} -> AK47; "45 MAC10" {30,40}; "9x19mm VP70M" {18,30}; Mini14 {10,20,30} -> MINI_14. Guns without profile use script MagazineType only: M14 (762x51Magazine20_M14), FAL, G3, PSG1, SVD, M1_GARAND (3006Clip8), M1911 & CAMP_CARBINE (45Magazine7_M1911), HIPOWER, P226, M60, BAR, G36/G36C (556x45Magazine30_G36), ASVAL, TEC9. Speedloaders: PYTHON/DETECTIVE_38/RHINO -> 38357SpeedLoader6; MOSIN -> 762x54StripperClip5_MOSIN.

**Animated internal parts** (`Registries/AnimationsFiring.lua`, required on spawn via `AttachmentPointsTable.lua`): "locked"=closed, "Fired"=open.
- Slide {open MarzGuns.Slide_Fired, locked Slide_Lock} PartType Slide: M92FS, M93R, USP, DEAGLE, HIPOWER, P226, M1911, VP70M.
- Pump {Pump_Fired/Pump_Lock} PartType Pump: MOSSBERG_590, TRENCHGUN, REMINGTON_870.
- Bolt {Bolt_Fired/Bolt_Lock, cycleTicks 3} PartType Bolt: AA12, BENELLI_M4, all ARs (M16*, AR15, FNC, AK74, AKS74U, ASVAL, G36C, G36, FAMAS, CAR15, AK47, XM177, M4A1, MINI_14), M1_GARAND, G3, M14, FAL, M60, BAR, MOSIN, M24, M1903, REMINGTON_700, MODEL_70, SVD, SKS, PSG1, CAMP_CARBINE, THOMPSON, MP5, MP5K, TEC9, MP5SD, MP5A2, MAC10.
- Lever {Lever_Fired/Lever_Lock} PartType Lever: W1894, M1895, W1887, W1873, W1873_CARBINE.
- Barrel {Barrel_Open/Barrel_Close}: M79. Break shotguns (MultipleAttachmentsVariant on PartType Barrel): DOUBLEBARREL_Barrel_{Close,Open,Sawnoff_Close,Sawnoff_Open} and same for STEVENS_555, TOZ34.
- Revolvers (force, cycleTicks 20): Hammer_{Open,Close} + Cylinder_{Open,Close}.
- SPAS12: selector part (PartType Selector) SPAS12_Selector_Semi -> Bolt parts; SPAS12_Selector_Pump -> Bolt + Pump parts.
- Required on spawn: all Bolt guns `Bolt_Lock`; slide pistols `Slide_Lock`; pumps `Pump_Lock`; levers `Lever_Lock`; break shotguns `<GUN>_Barrel_Close`; revolvers `Hammer_Close`+`Cylinder_Close`; plus integrated parts: CAR15/XM177/M4A1/FNC/G36/G36C/AKS74U/ASVAL/MP5/MP5SD/MAC10/SPAS12 `<GUN>_Integrated_Stock_Folded`; G36C `G36C_Integrated_Rail_Up/Down`; M24/M60/BAR `<GUN>_Integrated_Bipod_Folded`; M16A2_M203 `Underbarrel_Close` + `M16A2_M203_Integrated`; SPAS12 `Bolt_Lock`, `Pump_Lock`, `SPAS12_Selector_Semi`.

**Folding stocks** (`Registries/Stocks.lua`, PartType StockIntegrated, initial folded): FNC, AKS74U, ASVAL, G36C, G36, CAR15, XM177, M4A1, SPAS12, MP5, MP5SD, MAC10. Beretta_Stock_Deployed/Folded (PartType Stock, removable) on M92FS/M93R are regular attachments, not FoldingStock. **Folding bipods** (`Bipods.lua`, BipodIntegrated): M60, BAR, M24. Removable bipod pair Bipod_Deployed/Bipod_Folded (PartType Bipod).

**Bayonets** (`Bayonets.lua`): attachments K98/M5/M9_Bayonet_Attachment (PartType BayonetKnife) mount on M16A1, M16A2, M16A3, AR15, FAMAS, M14, M1_GARAND, G3, MOSIN, M1903, MOSSBERG_590, BENELLI_M4, TRENCHGUN, REMINGTON_870 (NOT M4A1, AK47, MINI_14). Knives K98_BAYONET/M5_BAYONET/M9_BAYONET; spear substitute MarzGuns.Attack_Bayonet. Integrated: SKS (SKS_Bayonet_Folded/Deployed). Exclusive with MKI/NDR/PBS-1 suppressors, LR2/LX/Trix42 muzzles, M203.

**Required parent parts** (`AttachmentsRequiredParts.lua`, framework RequiredAttachment):
- Long-gun sights/scopes (ReflexS2, Kobra, OKP3, JS14_Sight, EXPS3, EXPS1, Aimpoint = short; LR4X, TA28, ElcanX2 = mid; TR06X, PSO1, LR10X, LRX12X = long) require one of Picatinny_Rail_Up / AK_Mount / Sniper_Mount / G36C_Integrated_Rail_Up.
- Pistol sights PL4/PM2/PS1 require Beretta_Mount / Colt_Mount / Heavy_Pistol_Rail; PRL1_Scope requires Heavy_Pistol_Rail.
- Bipod_Deployed/Folded and foregrips require Picatinny_Rail_Down or G36C_Integrated_Rail_Down.
- BrightPoint-5_Light, SR7_Light require Picatinny_Rail_Left; AimRight_Laser, LRX-7_Laser require Picatinny_Rail_Right.
- MKI/NDR suppressors, LR2_Compensator, LX_Flashhider, Trix42_Muzzlebreak require AR_Muzzle_Mount_Device; PBS-1 requires AK_Muzzle_Mount_Device; P45 requires 45_Muzzle_Mount_Device; M&P and Shh9 require Pistol_Muzzle_Mount_Device.
- Pistol lasers/lights (PJ-3, PX1, TR-1, LP_Light, TL_Light; PartType Underbarrel) have no parent requirement.
- Rails: Picatinny_Rail_Up/Down/Left/Right have explicit MountOn lists (see B.3). `MarzGuns.Picatinny_Rail` (MountOn FakeItem) is a *universal* kit: `Registries/UniversalAttachments.lua` maps it per weapon to the allowed Up/Down/Left/Right outcomes (e.g. M16A2/M16A3/CAR15/XM177/M4A1/FAL/G3/MP5/MP5A2/MP5SD: all four; M14/AR15/FAMAS/PSG1: Up+Down; M24/MOSSBERG_590/BENELLI_M4/REMINGTON_870/W1894/M1895/W1887/W1873/MP5K/MINI_14/FNC/M16A2_M203: Up; SVD/AKS74U: Down; G36C: Left+Right; AA12/G36/ASVAL: Down+Left+Right). GoM does not use the framework Railing registry.
- UpgradeExclusives: bayonets vs muzzle devices/M203; PRL1_Scope vs PL4/PM2/PS1; M203 vs foregrips/bipods.

**Mount availability per likely target** (from MountOn):
| Target | Rail/mount for optics | Laser | Light | Muzzle mount -> suppressor | Bayonet | Other |
|---|---|---|---|---|---|---|
| M92FS | Beretta_Mount -> PL4/PS1/PM2 | PX1/PJ-3/TR-1 | LP/TL | Pistol_Muzzle_Mount_Device -> Shh9 / M&P | no | Beretta_Stock |
| M93R | Beretta_Mount -> PL4/PS1/PM2 | none | none | Pistol mount -> Shh9 / M&P | no | Beretta_Stock |
| M1911 | Colt_Mount | PX1/PJ-3/TR-1 | LP/TL | 45_Muzzle_Mount_Device -> P45 | no | |
| DEAGLE | Heavy_Pistol_Rail -> PL4/PS1/PM2/PRL1 | PX1/PJ-3/TR-1 | LP/TL | none | no | |
| M16A2, M16A3, M4A1 | Picatinny_Rail_Up (+Down/Left/Right) | AimRight/LRX-7 (Rail_Right) | SR7/BrightPoint-5 (Rail_Left) | AR_Muzzle_Mount_Device -> MKI/NDR, LR2 (+LX/Trix42 not M4A1? LX/Trix42 MountOn includes M4A1) | M16A2/A3 yes, M4A1 no | foregrips/bipod on Rail_Down |
| AK47 | AK_Mount | none | none | AK_Muzzle_Mount_Device -> PBS-1 | no | |
| M14 | Picatinny_Rail_Up/Down | none | none | none | yes | bipod/foregrip on Rail_Down |
| MINI_14 | Picatinny_Rail_Up | none | none | AR_Muzzle_Mount_Device -> MKI/NDR | no | |
| MP5, MP5SD | Picatinny_Rail_Up (LR4X etc. not on MP5; ok on MP5SD) | AimRight/LRX-7 | SR7/BrightPoint-5 | none | no | integrated folding stock |
| M24 | Picatinny_Rail_Up | none | none | none | no | integrated bipod |
| REMINGTON_700 / MODEL_70 | Sniper_Mount | none | none | none | no | Rem700_Sling / Model_70_Sling (PartType Sling) |
| W1873, W1894 | Picatinny_Rail_Up | none | none | none | no | |
| CAMP_CARBINE | none | none | none | none | no | |
| MOSSBERG_590 | Picatinny_Rail_Up | none | none | none | yes | |
| SPAS12 | none | none | none | none | no | selector, folding stock |
| DOUBLEBARREL | none | none | none | none | no | Shellholder (PartType Shellholder), barrel parts |

**Spawner items** (`items/spawners/spawners.txt`, OnCreate `MarzGuns_OnCreate.SelectItem`): Zombie_*_Spawner and World_*_Spawner weapons that replace themselves by a random pick from `ItemSpawnerTable.lua`; they store the chosen type in modData `Gunworks_SpawnerItemType`. Not useful for deterministic migration (random), but do not produce them.

**GoM's own vanilla mapping hints** (`OnCreate/VanillaReplacerTable.lua`, random pick lists): AssaultRifle -> M16A1|M16A2; AssaultRifle2 -> M14; DoubleBarrelShotgun(+Sawnoff) -> DOUBLEBARREL|STEVENS_555; HuntingRifle -> REMINGTON_700; Pistol -> M92FS; Pistol2 -> M1911; Pistol3 -> DEAGLE; Revolver -> PYTHON; Revolver_Long -> SW629; Revolver_Short -> DETECTIVE_38; Shotgun(+Sawnoff) -> MOSSBERG_590|REMINGTON_870; VarmintRifle -> MODEL_70; JS14_Rifle -> MINI_14 or AR15; JS3T_Shotgun -> SPAS12; L92_Carbine -> W1873|W1873_CARBINE; L94_Rifle -> W1894 or M1895; MSR7T_Rifle -> M24; TrapperCarbine -> CAMP_CARBINE. Mags: 44Clip -> 50Magazine8_DEAGLE; 45Clip -> 45Magazine7_M1911; 9mmClip -> 9x19Magazine15_M92FS; M14Clip -> 762x51Magazine20_M14; 556Clip -> 556x45Magazine30_STANAG; JS14_Clip -> 223Magazine10/20/30_Mini14. Ammo: Base.<x>Bullets -> SWMG.<x>_Bullet, boxes/cartons -> MarzGuns.<x>_Box/_Carton (308 -> 762x51, 556 -> 556x45). Attachments (thematic, random): TritiumSights -> ReflexS2|Kobra|OKP3|JS14_Sight; RedDot -> those + EXPS3; x2Scope -> EXPS1|Aimpoint; x4Scope -> LR4X|TA28|ElcanX2; x8Scope -> TR06X|PSO1|LR10X|LRX12X; AmmoStraps -> Shellholder|Beretta_Stock_Folded|VP70M_Stock|Rem700_Sling|Model_70_Sling; RecoilPad -> Bipod_Folded; Laser -> PJ-3|PX1|TR-1|AimRight|LRX-7; GunLight -> LP|TL|BrightPoint-5|SR7; ChokeTubeFull -> LR2|LX|Trix42; ChokeTubeImproved -> AR/AK/Pistol/45 muzzle mount devices.

**GoM OnCreate** (`CustomWeaponOnCreate.lua` `MarzGuns_OnCreate.AttachParts`): attaches required parts, rolls optionals `Type:chance[:MOUNTCODE]` (mount code PRU/PRD/PRL/PRR/AM/BM/CM/HPR/SM auto-attaches the parent rail first), sets GW_BayonetDeployed if BayonetKnife, and for a Clip: setMaxAmmo/MagazineType/random count/ContainsClip/modData.MagazineType **and fills modData.AmmoList with N copies of `weapon:getAmmoType():getItemKey()`** (i.e. SWMG.* rounds); tube guns are filled to MaxAmmo with AmmoList. `GiveRandomMagAmmo(magazine)` does the same for loose mags. `ReturnAmmoList` (recipe callback) returns AmmoList rounds of consumed items.

### B.1 GoM weapons

| Type | Name | Class | AmmoType | Default MagazineType | MaxAmmo | FireModes | ReloadType |
|---|---|---|---|---|---|---|---|
| MarzGuns.M16A1 | M16A1 Assault Rifle | Assault rifle | swmg:bullet_556x45 | MarzGuns.556x45Magazine30_STANAG | 30 | Auto/Single | boltaction |
| MarzGuns.M16A2 | M16A2 Assault Rifle | Assault rifle | swmg:bullet_556x45 | MarzGuns.556x45Magazine30_STANAG | 30 | Burst/Single | boltaction |
| MarzGuns.M16A2_M203 | M16A2 Assault Rifle with M203 | Assault rifle | swmg:bullet_556x45 | MarzGuns.556x45Magazine30_STANAG | 30 | Burst/Single | boltaction |
| MarzGuns.M16A3 | M16A3 Assault Rifle | Assault rifle | swmg:bullet_556x45 | MarzGuns.556x45Magazine30_STANAG | 30 | Auto/Single | boltaction |
| MarzGuns.AR15 | AR-15 Civilian Rifle | Assault rifle | swmg:bullet_223 | MarzGuns.556x45Magazine20_STANAG | 30 | Single | boltaction |
| MarzGuns.FNC | FN FNC Assault Rifle | Assault rifle | swmg:bullet_556x45 | MarzGuns.556x45Magazine30_STANAG | 30 | Auto/Single | boltaction |
| MarzGuns.CAR15 | CAR-15 Assault Rifle | Assault rifle | swmg:bullet_556x45 | MarzGuns.556x45Magazine30_STANAG | 30 | Auto/Single | boltaction |
| MarzGuns.XM177 | XM177 Assault Rifle | Assault rifle | swmg:bullet_556x45 | MarzGuns.556x45Magazine30_STANAG | 30 | Auto/Single | boltaction |
| MarzGuns.M4A1 | M4A1 Assault Rifle | Assault rifle | swmg:bullet_556x45 | MarzGuns.556x45Magazine30_STANAG | 30 | Auto/Burst/Single | boltaction |
| MarzGuns.G36C | G36C Assault Rifle | Assault rifle | swmg:bullet_556x45 | MarzGuns.556x45Magazine30_G36 | 30 | Auto/Single | boltaction |
| MarzGuns.G36 | G36 Assault Rifle | Assault rifle | swmg:bullet_556x45 | MarzGuns.556x45Magazine30_G36 | 30 | Auto/Single | boltaction |
| MarzGuns.AK74 | AK-74 Assault Rifle | Assault rifle | swmg:bullet_545x39 | MarzGuns.545x39Magazine30_Bakelite | 30 | Auto/Single | boltaction |
| MarzGuns.AKS74U | AKS-74U Assault Rifle | Assault rifle | swmg:bullet_545x39 | MarzGuns.545x39Magazine30_Bakelite | 30 | Auto/Single | boltaction |
| MarzGuns.ASVAL | AS VAL Assault Rifle | Assault rifle | swmg:bullet_9x39 | MarzGuns.9x39Magazine30 | 30 | Auto/Single | boltaction |
| MarzGuns.FAMAS | FAMAS Assault Rifle | Assault rifle | swmg:bullet_556x45 | MarzGuns.556x45Magazine30_STANAG | 30 | Auto/Single | boltaction |
| MarzGuns.AK47 | AK-47 Assault Rifle | Assault rifle | swmg:bullet_762x39 | MarzGuns.762x39Magazine30 | 30 | Auto/Single | boltaction |
| MarzGuns.M14 | M14 Battle Rifle | Battle rifle | swmg:bullet_762x51 | MarzGuns.762x51Magazine20_M14 | 20 | Single | boltaction |
| MarzGuns.M1_GARAND | M1 Garand Battle Rifle | Battle rifle | swmg:bullet_3006 | MarzGuns.3006Clip8 | 8 | Single | boltaction |
| MarzGuns.FAL | FN FAL Battle Rifle | Battle rifle | swmg:bullet_762x51 | MarzGuns.762x51Magazine20_FAL | 20 | Single | boltaction |
| MarzGuns.G3 | G3 Battle Rifle | Battle rifle | swmg:bullet_762x51 | MarzGuns.762x51Magazine20_G3 | 20 | Single | boltaction |
| MarzGuns.MOSIN | Mosin-Nagant Bolt Rifle | Bolt rifle | swmg:bullet_762x54 | - | 5 | Single | boltactionnomag |
| MarzGuns.M24 | M24 Sniper Rifle | Bolt rifle | swmg:bullet_762x51 | - | 5 | Single | boltactionnomag |
| MarzGuns.M1903 | M1903 Springfield Bolt Rifle | Bolt rifle | swmg:bullet_3006 | - | 5 | Single | boltactionnomag |
| MarzGuns.REMINGTON_700 | Remington 700 Bolt Rifle | Bolt rifle | swmg:bullet_308 | - | 5 | Single | boltactionnomag |
| MarzGuns.MODEL_70 | Model 70 Bolt Rifle | Bolt rifle | swmg:bullet_223 | - | 5 | Single | boltactionnomag |
| MarzGuns.M79 | M79 Grenade Launcher | Launcher | swmg:round_40mm_buckshot | - | 1 | Single | doublebarrelshotgun |
| MarzGuns.M203_Weapon | M203 Grenade Launcher | Launcher | swmg:round_40mm_buckshot | - | 1 | Single | doublebarrelshotgun |
| MarzGuns.W1894 | Winchester 1894 Rifle | Lever rifle | swmg:bullet_3030 | - | 6 | Single | leveraction |
| MarzGuns.M1895 | Marlin 1895 Rifle | Lever rifle | swmg:bullet_4570 | - | 6 | Single | leveraction |
| MarzGuns.W1887 | Winchester 1887 Shotgun | Lever rifle | swmg:shell_12g_buckshot | - | 5 | Single | leveraction |
| MarzGuns.W1873 | Winchester 1873 Rifle | Lever rifle | swmg:bullet_357 | - | 9 | Single | leveraction |
| MarzGuns.W1873_CARBINE | Winchester 1873 Short Carbine | Lever rifle | swmg:bullet_357 | - | 6 | Single | leveraction |
| MarzGuns.M60 | M60 Machine Gun | LMG | swmg:bullet_762x51 | MarzGuns.762x51Box100_M60 | 100 | Auto/Single | boltaction |
| MarzGuns.BAR | Browning Automatic Rifle | LMG | swmg:bullet_3006 | MarzGuns.3006Magazine20_BAR | 20 | Auto/Single | boltaction |
| MarzGuns.M92FS | Beretta M92FS | Pistol | swmg:bullet_9x19 | MarzGuns.9x19Magazine15_M92FS | 15 |  | handgun |
| MarzGuns.M93R | Beretta Burst M93R | Pistol | swmg:bullet_9x19 | MarzGuns.9x19Magazine18_M93R | 18 | Burst/Single | handgun |
| MarzGuns.HIPOWER | Browning Hi-Power | Pistol | swmg:bullet_9x19 | MarzGuns.9x19Magazine13_HIPOWER | 13 |  | handgun |
| MarzGuns.P226 | Sig Sauer P226 | Pistol | swmg:bullet_9x19 | MarzGuns.9x19Magazine10_P226 | 10 |  | handgun |
| MarzGuns.M1911 | Colt M1911 | Pistol | swmg:bullet_45 | MarzGuns.45Magazine7_M1911 | 7 |  | handgun |
| MarzGuns.USP | Heckler & Koch USP | Pistol | swmg:bullet_45 | MarzGuns.45Magazine12_USP | 12 |  | handgun |
| MarzGuns.DEAGLE | .50 Desert Eagle | Pistol | swmg:bullet_50 | MarzGuns.50Magazine8_DEAGLE | 8 |  | handgun |
| MarzGuns.VP70M | Heckler & Koch VP70M | Pistol | swmg:bullet_9x19 | MarzGuns.9x19Magazine18_VP70M | 18 | Single/Burst | handgun |
| MarzGuns.SW629 | Smith & Wesson Model 629 | Revolver | swmg:bullet_44 | - | 6 |  | revolver |
| MarzGuns.PYTHON | Colt Python Revolver | Revolver | swmg:bullet_357 | - | 6 |  | revolver |
| MarzGuns.RHINO | Rhino Revolver | Revolver | swmg:bullet_357 | - | 6 |  | revolver |
| MarzGuns.MP412 | MP-412 Revolver | Revolver | swmg:bullet_38 | - | 5 |  | revolver |
| MarzGuns.COLT_SINGLE | Colt Single Action Revolver | Revolver | swmg:bullet_45 | - | 6 |  | revolver |
| MarzGuns.DETECTIVE_38 | Detective .38 Revolver | Revolver | swmg:bullet_38 | - | 6 |  | revolver |
| MarzGuns.SVD | SVD Semi-Automatic Rifle | Semi-auto rifle | swmg:bullet_762x54 | MarzGuns.762x54Magazine10_SVD | 10 | Single | boltaction |
| MarzGuns.SKS | SKS Carbine | Semi-auto rifle | swmg:bullet_762x39 | - | 10 | Single | boltactionnomag |
| MarzGuns.PSG1 | PSG-1 Semi-Automatic Rifle | Semi-auto rifle | swmg:bullet_762x51 | MarzGuns.762x51Magazine5_PSG1 | 5 | Single | boltaction |
| MarzGuns.CAMP_CARBINE | Marlin Camp Carbine | Semi-auto rifle | swmg:bullet_45 | MarzGuns.45Magazine7_M1911 | 7 | Single | boltaction |
| MarzGuns.MINI_14 | Mini-14 Semi-Automatic Rifle | Semi-auto rifle | swmg:bullet_223 | MarzGuns.223Magazine20_Mini14 | 30 | Single | boltaction |
| MarzGuns.MOSSBERG_590 | Mossberg 590 Shotgun | Shotgun | swmg:shell_12g_buckshot | - | 5 | Single | shotgun |
| MarzGuns.TRENCHGUN | Trench Shotgun | Shotgun | swmg:shell_12g_buckshot | - | 5 | Single | shotgun |
| MarzGuns.BENELLI_M4 | Benelli M4 Semi-Shotgun | Shotgun | swmg:shell_12g_buckshot | - | 7 | Single | shotgun |
| MarzGuns.SPAS12 | SPAS-12 Semi-Shotgun | Shotgun | swmg:shell_12g_buckshot | - | 7 | Single | shotgun |
| MarzGuns.STEVENS_555 | Stevens 555 Double Barrel Shotgun | Shotgun | swmg:shell_12g_buckshot | - | 2 | Single | doublebarrelshotgun |
| MarzGuns.DOUBLEBARREL | Double Barrel Shotgun | Shotgun | swmg:shell_12g_buckshot | - | 2 | Single | doublebarrelshotgun |
| MarzGuns.AA12 | AA-12 Automatic Shotgun | Shotgun | swmg:shell_12g_buckshot | MarzGuns.12GMagazine8_AA12 | 8 | Auto/Single | boltaction |
| MarzGuns.REMINGTON_870 | Remington 870 Shotgun | Shotgun | swmg:shell_12g_buckshot | - | 5 | Single | shotgun |
| MarzGuns.TOZ34 | TOZ-34 Double Barrel Shotgun | Shotgun | swmg:shell_12g_buckshot | - | 2 | Single | doublebarrelshotgun |
| MarzGuns.THOMPSON | Thompson Submachine Gun | SMG | swmg:bullet_45 | MarzGuns.45Magazine30_THOMPSON | 30 | Auto/Single | boltaction |
| MarzGuns.MP5 | MP5 Submachine Gun | SMG | swmg:bullet_9x19 | MarzGuns.9x19Magazine20_MP5 | 30 | Auto/Single | boltaction |
| MarzGuns.MP5SD | MP5SD Submachine Gun | SMG | swmg:bullet_9x19 | MarzGuns.9x19Magazine20_MP5 | 30 | Auto/Single | boltaction |
| MarzGuns.MP5A2 | MP5A2 Submachine Gun | SMG | swmg:bullet_9x19 | MarzGuns.9x19Magazine20_MP5 | 30 | Auto/Single | boltaction |
| MarzGuns.MP5K | MP5K Submachine Gun | SMG | swmg:bullet_9x19 | MarzGuns.9x19Magazine20_MP5 | 15 | Auto/Single | handgun |
| MarzGuns.TEC9 | TEC-9 Machine Pistol | SMG | swmg:bullet_9x19 | MarzGuns.9x19Magazine20_TEC9 | 20 |  | handgun |
| MarzGuns.MAC10 | Ingram MAC-10 Machine Pistol | SMG | swmg:bullet_45 | MarzGuns.45Magazine30_MAC10 | 15 | Auto/Single | handgun |
| MarzGuns.MASTERKEY_Weapon | Masterkey Underbarrel Shotgun | Underbarrel | swmg:shell_12g_buckshot | - | 5 | Single | shotgun |

### B.2 GoM magazines / clips / speedloaders (all ItemType=weaponpart, PartType=Clip)

| Type | Name | AmmoType | Capacity | MountOn |
|---|---|---|---|---|
| MarzGuns.556x45Magazine20_STANAG | STANAG 20Rds 5.56x45mm Magazine | swmg:bullet_556x45 | 20 | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1 |
| MarzGuns.556x45Magazine25_STANAG | STANAG 25Rds 5.56x45mm Magazine | swmg:bullet_556x45 | 25 | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1 |
| MarzGuns.556x45Magazine30_STANAG | STANAG 30Rds 5.56x45mm Magazine | swmg:bullet_556x45 | 30 | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1 |
| MarzGuns.556x45Magazine60_STANAG | STANAG 60Rds Jungle-Style 5.56x45mm Magazine | swmg:bullet_556x45 | 60 | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1 |
| MarzGuns.556x45Magazine50_STANAG | STANAG 50Rds 5.56x45mm Magazine | swmg:bullet_556x45 | 50 | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1 |
| MarzGuns.556x45Magazine75_STANAG | STANAG 75Rds 5.56x45mm Magazine | swmg:bullet_556x45 | 75 | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1 |
| MarzGuns.556x45Magazine100_STANAG | STANAG 100Rds 5.56x45mm Magazine | swmg:bullet_556x45 | 100 | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1 |
| MarzGuns.556x45Magazine150_STANAG | STANAG 150Rds 5.56x45mm Magazine | swmg:bullet_556x45 | 150 | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1 |
| MarzGuns.556x45Magazine30_G36 | G36 30Rds 5.56x45mm Translucent Magazine | swmg:bullet_556x45 | 30 | G36C;G36 |
| MarzGuns.545x39Magazine30_Bakelite | Bakelite 30Rds 5.45x39mm Magazine | swmg:bullet_545x39 | 30 | AK74;AKS74U |
| MarzGuns.545x39Magazine45_Bakelite | Bakelite 45Rds Extended 5.45x39mm Magazine | swmg:bullet_545x39 | 45 | AK74;AKS74U |
| MarzGuns.545x39Magazine100_Drum | Drum 100Rds 5.45x39mm Magazine | swmg:bullet_545x39 | 100 | AK74;AKS74U |
| MarzGuns.9x39Magazine30 | 9x39mm 30Rds Magazine | swmg:bullet_9x39 | 30 | ASVAL |
| MarzGuns.762x39Magazine30 | 7.62x39mm 30Rds Magazine | swmg:bullet_762x39 | 30 | AK47 |
| MarzGuns.762x39Magazine75 | 7.62x39mm 75Rds Extended Magazine | swmg:bullet_762x39 | 75 | AK47 |
| MarzGuns.3006Clip8 | En Bloc 8Rds .30-06 Clip | swmg:bullet_3006 | 8 | M1_GARAND |
| MarzGuns.762x51Magazine20_M14 | M14 20Rds 7.62x51mm Magazine | swmg:bullet_762x51 | 20 | M14 |
| MarzGuns.762x51Magazine20_FAL | FAL 20Rds 7.62x51mm Magazine | swmg:bullet_762x51 | 20 | FAL |
| MarzGuns.762x51Magazine20_G3 | G3 20Rds 7.62x51mm Magazine | swmg:bullet_762x51 | 20 | G3 |
| MarzGuns.762x54StripperClip5_MOSIN | Mosin-Nagant 5Rds 7.62x54mm Stripper Clip | swmg:bullet_762x54 | 5 | MOSIN |
| MarzGuns.762x51Box100_M60 | M60 100Rds 7.62x51mm Box | swmg:bullet_762x51 | 100 | M60 |
| MarzGuns.3006Magazine20_BAR | BAR 20Rds .30-06 Magazine | swmg:bullet_3006 | 20 | BAR |
| MarzGuns.9x19Magazine15_M92FS | M92FS 15Rds 9x19mm Magazine | swmg:bullet_9x19 | 15 | M92FS |
| MarzGuns.9x19Magazine30_M92FS | M92FS 30Rds 9x19mm Extended Magazine | swmg:bullet_9x19 | 30 | M92FS |
| MarzGuns.9x19Magazine50_M92FS | M92FS 50Rds 9x19mm Drum Magazine | swmg:bullet_9x19 | 50 | M92FS |
| MarzGuns.9x19Magazine18_M93R | M93R 18Rds 9x19mm Magazine | swmg:bullet_9x19 | 18 | M93R |
| MarzGuns.9x19Magazine60_M93R | M93R 60Rds 9x19mm Extended Magazine | swmg:bullet_9x19 | 60 | M93R |
| MarzGuns.9x19Magazine13_HIPOWER | Hi-Power 13Rds 9x19mm Magazine | swmg:bullet_9x19 | 13 | HIPOWER |
| MarzGuns.9x19Magazine10_P226 | P226 10Rds 9x19mm Magazine | swmg:bullet_9x19 | 10 | P226 |
| MarzGuns.45Magazine7_M1911 | M1911 7Rds .45 ACP Magazine | swmg:bullet_45 | 7 | M1911;CAMP_CARBINE |
| MarzGuns.45Magazine12_USP | USP 12Rds .45 ACP Magazine | swmg:bullet_45 | 12 | USP |
| MarzGuns.45Magazine20_USP | USP 20Rds .45 ACP Magazine | swmg:bullet_45 | 20 | USP |
| MarzGuns.50Magazine8_DEAGLE | .50 AE 8Rds Magazine | swmg:bullet_50 | 8 | DEAGLE |
| MarzGuns.50Magazine12_DEAGLE | .50 AE 12Rds Magazine | swmg:bullet_50 | 12 | DEAGLE |
| MarzGuns.9x19Magazine18_VP70M | VP70M 18Rds 9x19mm Magazine | swmg:bullet_9x19 | 18 | VP70M |
| MarzGuns.9x19Magazine30_VP70M | VP70M 30Rds 9x19mm Magazine | swmg:bullet_9x19 | 30 | VP70M |
| MarzGuns.38357SpeedLoader6 | 6Rds .38 Special/.357 Magnum Speedloader | swmg:bullet_357 | 6 | PYTHON |
| MarzGuns.762x54Magazine10_SVD | SVD 10Rds 7.62x54mm Magazine | swmg:bullet_762x54 | 10 | SVD |
| MarzGuns.762x51Magazine5_PSG1 | PSG-1 5Rds 7.62x51mm Magazine | swmg:bullet_762x51 | 5 | PSG1 |
| MarzGuns.223Magazine10_Mini14 | .223 10Rds Mini-14 Magazine | swmg:bullet_223 | 10 | MINI_14 |
| MarzGuns.223Magazine20_Mini14 | .223 20Rds Mini-14 Magazine | swmg:bullet_223 | 20 | MINI_14 |
| MarzGuns.223Magazine30_Mini14 | .223 30Rds Mini-14 Magazine | swmg:bullet_223 | 30 | MINI_14 |
| MarzGuns.12GMagazine8_AA12 | 12 Gauge AA-12 8Rds Magazine | swmg:shell_12g_buckshot | 8 | AA12 |
| MarzGuns.12GMagazine20_AA12 | 12 Gauge AA-12 Drum 20Rds Magazine | swmg:shell_12g_buckshot | 20 | AA12 |
| MarzGuns.45Magazine30_THOMPSON | Thompson 30Rds .45 ACP Magazine | swmg:bullet_45 | 30 | THOMPSON |
| MarzGuns.45Magazine20_THOMPSON | Thompson 20Rds .45 ACP Magazine | swmg:bullet_45 | 20 | THOMPSON |
| MarzGuns.45Magazine100_THOMPSON | Thompson 100Rds .45 ACP Drum Magazine | swmg:bullet_45 | 100 | THOMPSON |
| MarzGuns.9x19Magazine20_MP5 | MP5 20Rds 9x19mm Magazine | swmg:bullet_9x19 | 20 | MP5;MP5K;MP5A2;MP5SD |
| MarzGuns.9x19Magazine25_MP5 | MP5 25Rds 9x19mm Magazine | swmg:bullet_9x19 | 25 | MP5;MP5K;MP5A2;MP5SD |
| MarzGuns.9x19Magazine30_MP5 | MP5 30Rds 9x19mm Magazine | swmg:bullet_9x19 | 30 | MP5;MP5K;MP5A2;MP5SD |
| MarzGuns.9x19Magazine60_MP5 | MP5 Dual 30Rds 9x19mm Magazine | swmg:bullet_9x19 | 60 | MP5;MP5K;MP5A2;MP5SD |
| MarzGuns.9x19Magazine100_MP5 | MP5 100Rds Drum 9x19mm Magazine | swmg:bullet_9x19 | 100 | MP5;MP5K;MP5A2;MP5SD |
| MarzGuns.9x19Magazine20_TEC9 | TEC-9 20Rds 9x19mm Magazine | swmg:bullet_9x19 | 20 | TEC9 |
| MarzGuns.45Magazine30_MAC10 | MAC-10 30Rds .45 ACP Magazine | swmg:bullet_45 | 30 | MAC10 |
| MarzGuns.45Magazine40_MAC10 | MAC-10 40Rds .45 ACP Extended Magazine | swmg:bullet_45 | 40 | MAC10 |

### B.3 GoM attachments & internal parts

| Type | Name | File | PartType | MountOn |
|---|---|---|---|---|
| MarzGuns.MASTERKEY | Masterkey Underbarrel Shotgun | underbarrel | Underbarrel | M16A2 |
| MarzGuns.Slide_Lock | Locked Slide | animated | Slide | FakeItem |
| MarzGuns.Slide_Fired | Fired Slide | animated | Slide | FakeItem |
| MarzGuns.Pump_Lock | Locked Pump | animated | Pump | FakeItem |
| MarzGuns.Pump_Fired | Fired Pump | animated | Pump | FakeItem |
| MarzGuns.Bolt_Lock | Locked Bolt | animated | Bolt | FakeItem |
| MarzGuns.Bolt_Fired | Fired Bolt | animated | Bolt | FakeItem |
| MarzGuns.Lever_Lock | Locked Lever | animated | Lever | FakeItem |
| MarzGuns.Lever_Fired | Fired Lever | animated | Lever | FakeItem |
| MarzGuns.Barrel_Close | Barrel Close | animated | Barrel | FakeItem |
| MarzGuns.Barrel_Open | Barrel Open | animated | Barrel | FakeItem |
| MarzGuns.Hammer_Close | Hammer Close | animated | Hammer | FakeItem |
| MarzGuns.Hammer_Open | Hammer Open | animated | Hammer | FakeItem |
| MarzGuns.Cylinder_Close | Cylinder Close | animated | Cylinder | FakeItem |
| MarzGuns.Cylinder_Open | Cylinder Open | animated | Cylinder | FakeItem |
| MarzGuns.Underbarrel_Close | Underbarrel Close | animated | UnderbarrelChamber | FakeItem |
| MarzGuns.Underbarrel_Open | Underbarrel Open | animated | UnderbarrelChamber | FakeItem |
| MarzGuns.DOUBLEBARREL_Barrel_Close | Double Barrel | barrels | Barrel | DOUBLEBARREL |
| MarzGuns.DOUBLEBARREL_Barrel_Open | Double Barrel | barrels | Barrel | DOUBLEBARREL |
| MarzGuns.DOUBLEBARREL_Barrel_Sawnoff_Close | Double Barrel Sawnoff | barrels | Barrel | DOUBLEBARREL |
| MarzGuns.DOUBLEBARREL_Barrel_Sawnoff_Open | Double Barrel Sawnoff | barrels | Barrel | DOUBLEBARREL |
| MarzGuns.STEVENS_555_Barrel_Close | Stevens 555 Barrel | barrels | Barrel | STEVENS_555 |
| MarzGuns.STEVENS_555_Barrel_Open | Stevens 555 Barrel | barrels | Barrel | STEVENS_555 |
| MarzGuns.STEVENS_555_Barrel_Sawnoff_Close | Stevens 555 Barrel Sawnoff | barrels | Barrel | STEVENS_555 |
| MarzGuns.STEVENS_555_Barrel_Sawnoff_Open | Stevens 555 Barrel Sawnoff | barrels | Barrel | STEVENS_555 |
| MarzGuns.TOZ34_Barrel_Close | TOZ-34 Barrel | barrels | Barrel | TOZ34 |
| MarzGuns.TOZ34_Barrel_Open | TOZ-34 Barrel | barrels | Barrel | TOZ34 |
| MarzGuns.TOZ34_Barrel_Sawnoff_Close | TOZ-34 Barrel Sawnoff | barrels | Barrel | TOZ34 |
| MarzGuns.TOZ34_Barrel_Sawnoff_Open | TOZ-34 Barrel Sawnoff | barrels | Barrel | TOZ34 |
| MarzGuns.K98_Bayonet_Attachment | Karabiner 98k Bayonet (Attached) | bayonets | BayonetKnife | M16A1;M16A2;M16A3;AR15;FAMAS;M14;M1_GARAND;G3;MOSIN;M1903;MOSSBERG_590;BENELLI_M4;TRENCHGUN;REMINGTON_870 |
| MarzGuns.M5_Bayonet_Attachment | M5 Bayonet (Attached) | bayonets | BayonetKnife | M16A1;M16A2;M16A3;AR15;FAMAS;M14;M1_GARAND;G3;MOSIN;M1903;MOSSBERG_590;BENELLI_M4;TRENCHGUN;REMINGTON_870 |
| MarzGuns.M9_Bayonet_Attachment | M9 Bayonet (Attached) | bayonets | BayonetKnife | M16A1;M16A2;M16A3;AR15;FAMAS;M14;M1_GARAND;G3;MOSIN;M1903;MOSSBERG_590;BENELLI_M4;TRENCHGUN;REMINGTON_870 |
| MarzGuns.Bipod_Deployed | Bipod (Deployed) | bipods | Bipod | M16A1;M16A2;M16A3;AR15;XM177;M4A1;G36;M14;FAL;G3;SVD;PSG1;MP5;MP5A2;MP5SD;G36C |
| MarzGuns.Bipod_Folded | Bipod (Folded) | bipods | Bipod | M16A1;M16A2;M16A3;AR15;XM177;M4A1;G36;M14;FAL;G3;SVD;PSG1;MP5;MP5A2;MP5SD;G36C |
| MarzGuns.Shellholder | Shellholder | custom | Shellholder | STEVENS_555;DOUBLEBARREL;TOZ34 |
| MarzGuns.Beretta_Stock_Deployed | Beretta Stock (Deployed) | custom | Stock | M92FS;M93R |
| MarzGuns.Beretta_Stock_Folded | Beretta Stock (Folded) | custom | Stock | M92FS;M93R |
| MarzGuns.VP70M_Stock | VP70M Stock | custom | Stock | VP70M |
| MarzGuns.Rem700_Sling | Remington 700 Sling | custom | Sling | REMINGTON_700 |
| MarzGuns.Model_70_Sling | Model 70 Sling | custom | Sling | MODEL_70 |
| MarzGuns.SPAS12_Selector_Pump |  | custom | Selector | SPAS12 |
| MarzGuns.SPAS12_Selector_Semi |  | custom | Selector | SPAS12 |
| MarzGuns.Bullet_1 | Bullet | details | Animated1 | FakeItem |
| MarzGuns.Bullet_2 | Bullet | details | Animated2 | FakeItem |
| MarzGuns.Bullet_3 | Bullet | details | Animated3 | FakeItem |
| MarzGuns.Bullet_4 | Bullet | details | Animated4 | FakeItem |
| MarzGuns.Bullet_5 | Bullet | details | Animated5 | FakeItem |
| MarzGuns.Bullet_6 | Bullet | details | Animated6 | FakeItem |
| MarzGuns.Bullet_7 | Bullet | details | Animated7 | FakeItem |
| MarzGuns.Bullet_8 | Bullet | details | Animated8 | FakeItem |
| MarzGuns.Bullet_9 | Bullet | details | Animated9 | FakeItem |
| MarzGuns.Stub_Foregrip | Stub Foregrip | foregrips | Foregrip | M16A1;M16A2;M16A3;AR15;AKS74U;ASVAL;FAMAS;CAR15;XM177;M4A1;G36;M14;FAL;G3;AA12;MP5;MP5A2;MP5SD;G36C;SVD;PSG1 |
| MarzGuns.MKC_Foregrip | MKC Foregrip | foregrips | Foregrip | M16A1;M16A2;M16A3;AR15;AKS74U;ASVAL;FAMAS;CAR15;XM177;M4A1;G36;M14;FAL;G3;AA12;MP5;MP5A2;MP5SD;G36C;SVD;PSG1 |
| MarzGuns.MK2_Foregrip | MK2 Foregrip | foregrips | Foregrip | M16A1;M16A2;M16A3;AR15;AKS74U;ASVAL;FAMAS;CAR15;XM177;M4A1;G36;M14;FAL;G3;AA12;MP5;MP5A2;MP5SD;G36C;SVD;PSG1 |
| MarzGuns.M60_Integrated_Bipod_Folded | M60 Integrated Bipod (Folded) | integrated | BipodIntegrated | FakeItem |
| MarzGuns.M60_Integrated_Bipod_Deployed | M60 Integrated Bipod (Deployed) | integrated | BipodIntegrated | FakeItem |
| MarzGuns.BAR_Integrated_Bipod_Folded | BAR Integrated Bipod (Folded) | integrated | BipodIntegrated | FakeItem |
| MarzGuns.BAR_Integrated_Bipod_Deployed | BAR Integrated Bipod (Deployed) | integrated | BipodIntegrated | FakeItem |
| MarzGuns.M24_Integrated_Bipod_Folded | M24 Integrated Bipod (Folded) | integrated | BipodIntegrated | FakeItem |
| MarzGuns.M24_Integrated_Bipod_Deployed | M24 Integrated Bipod (Deployed) | integrated | BipodIntegrated | FakeItem |
| MarzGuns.AKS74U_Integrated_Stock_Folded | AKS-74U Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.AKS74U_Integrated_Stock_Deployed | AKS-74U Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.ASVAL_Integrated_Stock_Folded | AS VAL Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.ASVAL_Integrated_Stock_Deployed | AS VAL Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.G36C_Integrated_Stock_Folded | G36C Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.G36C_Integrated_Stock_Deployed | G36C Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.G36_Integrated_Stock_Folded | G36 Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.G36_Integrated_Stock_Deployed | G36 Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.G36C_Integrated_Rail_Up | G36C Integrated Rail (Up) | integrated | RailUp | FakeItem |
| MarzGuns.G36C_Integrated_Rail_Down | G36C Integrated Rail (Down) | integrated | RailDown | FakeItem |
| MarzGuns.SPAS12_Integrated_Stock_Folded | SPAS-12 Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.SPAS12_Integrated_Stock_Deployed | SPAS-12 Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.SKS_Bayonet_Folded | SKS Bayonet (Folded) | integrated | BayonetIntegrated | FakeItem |
| MarzGuns.SKS_Bayonet_Deployed | SKS Bayonet (Deployed) | integrated | BayonetIntegrated | FakeItem |
| MarzGuns.CAR15_Integrated_Stock_Folded | CAR-15 Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.CAR15_Integrated_Stock_Deployed | CAR-15 Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.XM177_Integrated_Stock_Folded | XM177 Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.XM177_Integrated_Stock_Deployed | XM177 Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.M4A1_Integrated_Stock_Folded | M4A1 Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.M4A1_Integrated_Stock_Deployed | M4A1 Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.FNC_Integrated_Stock_Folded | FN FNC Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.FNC_Integrated_Stock_Deployed | FN FNC Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.MP5_Integrated_Stock_Folded | MP5 Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.MP5_Integrated_Stock_Deployed | MP5 Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.MP5SD_Integrated_Stock_Folded | MP5SD Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.MP5SD_Integrated_Stock_Deployed | MP5SD Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.MAC10_Integrated_Stock_Folded | MAC10 Integrated Stock (Folded) | integrated | StockIntegrated | FakeItem |
| MarzGuns.MAC10_Integrated_Stock_Deployed | MAC10 Integrated Stock (Deployed) | integrated | StockIntegrated | FakeItem |
| MarzGuns.M16A2_M203_Integrated | M203 Integrated Grenade Launcher | integrated | Underbarrel | FakeItem |
| MarzGuns.AR_Muzzle_Mount_Device | AR Family Muzzle Mounting Device | muzzles | CanonMount | M16A1;M16A2;M16A3;M4;G36C;G36;FAMAS;CAR15;M4A1;M16A2_M203;FNC;MINI_14 |
| MarzGuns.AK_Muzzle_Mount_Device | AK Family Muzzle Mounting Device | muzzles | CanonMount | AK74;AKS74U;AK47 |
| MarzGuns.Pistol_Muzzle_Mount_Device | Pistol Family Muzzle Mounting Device | muzzles | CanonMount | M92FS;M93R;HIPOWER;P226 |
| MarzGuns.45_Muzzle_Mount_Device | .45 ACP Family Muzzle Mounting Device | muzzles | CanonMount | M1911;USP;MAC10 |
| MarzGuns.LR2_Compensator | LR2 Compensator | muzzles | Canon | M16A1;M16A2;M16A3;M4;G36C;G36;FAMAS;CAR15;M4A1;M16A2_M203 |
| MarzGuns.LX_Flashhider | LX Flashhider | muzzles | Canon | M16A1;M16A2;M16A3;G36C;G36;FAMAS;CAR15;M4A1;M16A2_M203 |
| MarzGuns.Trix42_Muzzlebreak | Trix42 Muzzlebreak | muzzles | Canon | M16A1;M16A2;M16A3;G36C;G36;FAMAS;CAR15;M4A1;M16A2_M203 |
| MarzGuns.PJ-3_Laser | PJ-3 Laser | pointers | Underbarrel | M92FS;HIPOWER;M1911;USP;DEAGLE;P226 |
| MarzGuns.PX1_Laser | PX1 Laser | pointers | Underbarrel | M92FS;HIPOWER;M1911;USP;DEAGLE;P226 |
| MarzGuns.TR-1_Laser | TR-1 Laser | pointers | Underbarrel | M92FS;HIPOWER;M1911;USP;DEAGLE;P226 |
| MarzGuns.LP_Light | LP Tactical Light | pointers | Underbarrel | M92FS;HIPOWER;M1911;USP;DEAGLE;P226 |
| MarzGuns.TL_Light | TL Tactical Light | pointers | Underbarrel | M92FS;HIPOWER;M1911;USP;DEAGLE;P226 |
| MarzGuns.AimRight_Laser | AimRight Laser | pointers | LaserRifle | M16A2;M16A3;ASVAL;CAR15;XM177;M4A1;G36C;G36;FAL;G3;AA12;MP5;MP5A2;MP5SD |
| MarzGuns.LRX-7_Laser | LRX-7 Laser | pointers | LaserRifle | M16A2;M16A3;ASVAL;CAR15;XM177;M4A1;G36C;G36;FAL;G3;AA12;MP5;MP5A2;MP5SD |
| MarzGuns.BrightPoint-5_Light | BrightPoint-5 Light | pointers | LightRifle | M16A2;M16A3;ASVAL;CAR15;XM177;M4A1;G36C;G36;FAL;G3;AA12;MP5;MP5A2;MP5SD |
| MarzGuns.SR7_Light | SR7 Tactical Light | pointers | LightRifle | M16A2;M16A3;ASVAL;CAR15;XM177;M4A1;G36C;G36;FAL;G3;AA12;MP5;MP5A2;MP5SD |
| MarzGuns.Picatinny_Rail | Picatinny Rail | rails | GenericRail | FakeItem |
| MarzGuns.Picatinny_Rail_Up | Picatinny Rail (Up) | rails | RailUp | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5;MP5A2;MP5SD;MP5K;MINI_14 |
| MarzGuns.Picatinny_Rail_Down | Picatinny Rail (Down) | rails | RailDown | M16A1;M16A2;M16A3;AR15;AKS74U;ASVAL;FAMAS;CAR15;XM177;M4A1;G36;M14;FAL;G3;AA12;SVD;PSG1;MP5;MP5A2;MP5SD |
| MarzGuns.Picatinny_Rail_Right | Picatinny Rail (Right) | rails | RailRight | M16A2;M16A3;ASVAL;CAR15;XM177;M4A1;G36C;G36;FAL;G3;AA12;MP5;MP5A2;MP5SD |
| MarzGuns.Picatinny_Rail_Left | Picatinny Rail (Left) | rails | RailLeft | M16A2;M16A3;ASVAL;CAR15;XM177;M4A1;G36C;G36;FAL;G3;AA12;MP5;MP5A2;MP5SD |
| MarzGuns.AK_Mount | AK Mounting Rail | rails | RailUp | AK74;AKS74U;ASVAL;SVD;AK47 |
| MarzGuns.Sniper_Mount | Sniper Mounting Rail | rails | RailUp | MOSIN;M1903;REMINGTON_700;MODEL_70 |
| MarzGuns.Beretta_Mount | Beretta Mounting Rail | rails | RailUp | M92FS;M93R;HIPOWER;P226 |
| MarzGuns.Colt_Mount | Colt Mounting Rail | rails | RailUp | M1911;USP |
| MarzGuns.Heavy_Pistol_Rail | Heavy Pistol Mounting Rail | rails | RailUp | DEAGLE;PYTHON;SW629 |
| MarzGuns.ReflexS2_Sight | Reflex S2 Sight | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5;MP5A2;MP5SD;MP5K;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.Kobra_Sight | Kobra Sight | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5;MP5A2;MP5SD;MP5K;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.OKP3_Sight | OKP3 Sight | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5;MP5A2;MP5SD;MP5K;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.JS14_Sight | JS14 Sight | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5;MP5A2;MP5SD;MP5K;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.EXPS3_Sight | EXPS3 Sight | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5;MP5A2;MP5SD;MP5K;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.EXPS1_Sight | EXPS1 Sight | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5;MP5A2;MP5SD;MP5K;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.Aimpoint_Sight | Aimpoint Sight | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5;MP5A2;MP5SD;MP5K;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.LR4X_Scope | LR4X Scope | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5A2;MP5SD;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.TA28_Scope | TA28 Scope | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5A2;MP5SD;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.ElcanX2_Scope | Elcan X2 Scope | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5A2;MP5SD;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.TR06X_Scope | TR06X Scope | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5A2;MP5SD;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.PSO1_Scope | PSO1 Scope | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5A2;MP5SD;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.LR10X_Scope | LR10X Scope | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5A2;MP5SD;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.LRX12X_Scope | LRX12X Scope | scopes | Scope | M16A1;M16A2;M16A2_M203;M16A3;AR15;FNC;FAMAS;CAR15;XM177;M4A1;M14;FAL;G3;M24;REMINGTON_700;MODEL_70;MOSSBERG_590;BENELLI_M4;REMINGTON_870;PSG1;W1894;M1895;W1887;W1873;MP5A2;MP5SD;AK74;AKS74U;ASVAL;SVD;AK47;MOSIN;M1903;G36C;MINI_14 |
| MarzGuns.PL4_Sight | PL-4 Sight | scopes | Scope | M92FS;M93R;HIPOWER;P226;M1911;USP;DEAGLE;PYTHON;SW629 |
| MarzGuns.PS1_Sight | PS1 Sight | scopes | Scope | M92FS;M93R;HIPOWER;P226;M1911;USP;DEAGLE;PYTHON;SW629 |
| MarzGuns.PM2_Sight | PM-2 Sight | scopes | Scope | M92FS;M93R;HIPOWER;P226;M1911;USP;DEAGLE;PYTHON;SW629 |
| MarzGuns.PRL1_Scope | PRL-1 Sight | scopes | Scope | DEAGLE;PYTHON;SW629 |
| MarzGuns.MKI_Suppressor | MKI Suppressor (5.56mm Rifles) | suppressors | Canon | M16A1;M16A2;M16A3;G36C;G36;FAMAS;CAR15;M4A1;M16A2_M203;FNC;MINI_14 |
| MarzGuns.NDR_Suppressor | NDR Suppressor (5.56mm Rifles) | suppressors | Canon | M16A1;M16A2;M16A3;G36C;G36;FAMAS;CAR15;M4A1;M16A2_M203;FNC;MINI_14 |
| MarzGuns.PBS-1_Suppressor | PBS-1 Suppressor (AK Rifles) | suppressors | Canon | AK74;AKS74U;AK47 |
| MarzGuns.M&P_Suppressor | M&P Suppressor (9mm Pistols) | suppressors | Canon | M92FS;M93R;HIPOWER;P226 |
| MarzGuns.Shh9_Suppressor | Shh9 Suppressor (9mm Pistols) | suppressors | Canon | M92FS;M93R;HIPOWER;P226 |
| MarzGuns.P45_Suppressor | P45 Suppressor (.45 ACP Weapons) | suppressors | Canon | M1911;USP;MAC10 |

### B.4 GoM melee / misc / spawners

| Type | Name | File | ItemType |
|---|---|---|---|
| MarzGuns.FakeItem | Rifles and Shotguns | generic | base:normal |
| MarzGuns.RepairPack | Weapon Repair Pack | generic | base:drainable |
| MarzGuns.K98_BAYONET | Karabiner 98k Bayonet | melee | base:weapon |
| MarzGuns.M5_BAYONET | M5 Bayonet | melee | base:weapon |
| MarzGuns.M9_BAYONET | M9 Bayonet | melee | base:weapon |
| MarzGuns.Elvorenstein_Tacticool_Knife |  | melee | base:weapon |
| MarzGuns.Attack_Bayonet |  | melee | base:weapon |
| MarzGuns.Zombie_Civilian_Handgun_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Civilian_Revolver_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Civilian_Rifle_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Civilian_Shotgun_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Civilian_SemiRifle_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Police_Handgun_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Police_Revolver_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Police_Shotgun_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Police_Rifle_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Police_SemiRifle_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Police_SMG_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Army_Handgun_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Army_Rifle_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Army_SemiRifle_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_SWAT_Handgun_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Cowboy_Revolver_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Cowboy_Rifles_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Hunter_SemiRifles_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Crime_Rifle_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Survivalist_Rifle_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_SWAT_Shotgun_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.Zombie_Oldies_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Import_Rifle_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Army_Heavy_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Army_Rifle_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Russian_Rifle_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Short_SMG_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Anachronistic_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Oldies_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Ordnance_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Optics_Reflex_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Optics_Magnified_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Optics_Pistol_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Tactical_Light_Laser_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Muzzle_Device_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Foregrip_Rail_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Suppressor_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Bayonet_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_Russian_Attachment_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_HighCap_AR_Magazine_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_HighCap_Russian_Magazine_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_HighCap_Tactical_Magazine_Spawner | Spawner | spawners | base:weapon |
| MarzGuns.World_HighCap_Oldies_Magazine_Spawner | Spawner | spawners | base:weapon |

---

## C. Proposed deterministic mapping MVG -> GoM

Confidence: H = same real-world model + caliber + capacity; M = right class/caliber, different model or small feature loss; L = best available, noticeable mismatch; FLAG = no good equivalent (explain handling). "Return" = detach and put the item (or rounds) into the same container as the converted weapon so nothing is lost.

### C.1 Weapons

**Closest stats rule:** where GoM has no counterpart, the gun converts to the GoM firearm with the
smallest stat distance. The distance is computed by [tools/closest_gun.py](../tools/closest_gun.py)
(after [tools/item_stats.py](../tools/item_stats.py) builds the item table; MVG values are
merged over vanilla the way the game merges scripts). It sums normalised differences with these
weights:

- min and max damage ×2
- hit chance ×1.5
- critical chance, crit multiplier, aiming time and recoil delay ×1
- max range, min angle, sound radius, weight, jam chance and stop power ×0.5
- projectile count ×3
- capacity ×1.5, compared on a log scale so 5 vs 20 counts more than 30 vs 45
- a different reload type +1, a different set of fire modes up to +1, and a different caliber +1.5

Rows marked **Closest stats** below use this rule. Any rounds or magazines that no longer fit
are handed back as items.

| MVG | GoM | Conf | Reasoning / handling |
|---|---|---|---|
| Base.Pistol (M9) | MarzGuns.M92FS | H | Beretta 92FS = M9; 9x19; 15-rd mag both; GoM's VanillaReplacer uses the same. Slide part -> Slide_Lock/Slide_Fired. |
| Base.PistolGlock (Glock 17) | MarzGuns.M92FS | **Closest stats** | No Glock in GoM. Nearest by stat distance (0.69; runner-up TEC9 0.78): same 9x19, 15 rounds, 0.5-1.0 vs 0.7-0.9 damage, hit 50, recoil 12, handgun reload. |
| Base.Pistolm93r | MarzGuns.M93R | H | Same model, burst; GoM M93R mags are 18/60 (>=15, no loss). |
| Base.Pistol2 (M1911) | MarzGuns.M1911 | H | .45 ACP, 7-rd mag both. |
| Base.Pistol3 (D-E .44) | MarzGuns.SW629 | **Closest stats** | No .44 Desert Eagle in GoM. M1911 (2.38) and SW629 (2.45) are a near tie on the overall score; SW629 is chosen because it matches on the stats that define the gun: damage 1.2-1.8 vs 1.0-1.6 (M1911 0.9-1.2), recoil 17 = 17, sound radius 120 = 120, and the same .44 Magnum caliber, so loaded rounds stay loaded. Capacity 8 -> 6: surplus rounds are returned as `SWMG.44_Bullet`. The inserted magazine is returned as an item (see C.2 `44Clip`). |
| Base.AssaultRifle (MVG "M16A2") | MarzGuns.M16A2 | H | Same model, burst/single, STANAG. |
| Base.AssaultRifleA3 | MarzGuns.M16A3 | H | Same model, auto/single. |
| Base.AssaultRifleM4 | MarzGuns.M4A1 | H | M4 -> M4A1; GoM adds Burst mode and an integrated collapsible stock (M4A1_Integrated_Stock_*; set modData.StockFolded=false to match MVG's always-extended look, or leave nil for GoM default folded). Bayonet not mountable on GoM M4A1 -> return knife. |
| Base.AssaultRifleAK47 | MarzGuns.AK47 | H | Same model, 7.62x39, 30/75 mags. Ammo must be converted (Base.762Bullets -> SWMG.762x39_Bullet). Bayonet not mountable on GoM AK47 -> return knife. |
| Base.AssaultRifle2 (M14) | MarzGuns.M14 | H | Same model, 20-rd; bayonet OK. |
| Base.SR25_Rifle | MarzGuns.M14 | L / FLAG | No SR-25/AR-10 in GoM. M14 = semi-auto 7.62x51 DMR-ish with 20-rd mag and Picatinny rails; family 7.62x51mm accepts Base.308Bullets. Alternatives: PSG1 (semi DMR, but 5-rd mags = capacity loss), G3/FAL (20-rd). |
| Base.Shotgun (JS-2000) | MarzGuns.MOSSBERG_590 | M | Fictional pump; GoM author maps to 590 or 870; both MaxAmmo 5. Pump -> Pump_Lock. Alternative REMINGTON_870. |
| Base.ShotgunSawnoff | MarzGuns.MOSSBERG_590 | L / FLAG | No sawn-off pump in GoM (break-action guns are the only sawn variants). Capacity 5=5; sawn-off handling stats lost. |
| Base.JS3T_Shotgun | MarzGuns.SPAS12 | M | Author's mapping; 7=7; JS3T is a pump (RackAfterShoot) so attach `SPAS12_Selector_Pump` + Bolt_Lock + Pump_Lock + SPAS12_Integrated_Stock_Folded (all required parts). Alternative BENELLI_M4 (7, semi). |
| Base.VarmintRifle (MSR700, 5.56) | MarzGuns.MODEL_70 | M | .223 bolt rifle, 5 rds; 5.56x45mm family includes Base.556Bullets. |
| Base.HuntingRifle (MSR788, .308) | MarzGuns.REMINGTON_700 | H/M | Author's mapping; .308 bolt; 4 -> 5 capacity (no loss). |
| Base.MSR7T_Rifle | MarzGuns.M24 | M | Author's mapping; tactical .308 bolt; 7.62x51mm family accepts Base.308Bullets; 4 -> 5; M24 needs M24_Integrated_Bipod_Folded. |
| Base.JS14_Rifle | MarzGuns.MINI_14 | M | Author's first option; .223/5.56 semi with 10/20/30 mags. (AR15 is the other author option.) |
| Base.AC556 (JS-556) | MarzGuns.M16A3 | **Closest stats** | No select-fire Mini-14 in GoM. M16A3 and M16A1 tie at 1.19 (FAMAS 1.23, FNC 1.29, MINI_14 not in the top 6 because it lacks Auto); M16A3 is chosen for the closer weight (3.40 vs 3.2; M16A1 2.89). Keeps Auto/Single and the 30-round 5.56 magazine. |
| Base.L92_Carbine (.357, 10) | MarzGuns.W1873 | M | .357 lever; GoM capacity 9 -> if 10 loaded, return 1 round (the first-loaded/bottom AmmoList[1]). Alternative W1873_CARBINE (6). |
| Base.L94_Rifle (.30-30, 6) | MarzGuns.W1894 | H | Winchester 1894 .30-30, 6=6. (Author's other option M1895 is .45-70 - wrong caliber.) |
| Base.TrapperCarbine (.45) | MarzGuns.CAMP_CARBINE | H | Author's mapping; .45 carbine using M1911 7-rd mags. No optic/laser mounts in GoM -> return those attachments. |
| Base.JS5_smg | MarzGuns.MP5 | L / FLAG | Fictional 9mm 30-rd folding-stock SMG (never distributed by MVG). MP5 has integrated folding stock, 30-rd mag; Burst mode lost. |
| Base.MP5_SMG | MarzGuns.MP5 | H | Same model; GoM MP5 has no Burst (Auto/Single) and adds integrated folding stock (set StockFolded=false to keep look). |
| Base.MP5SD_SMG | MarzGuns.MP5SD | H | Same; same notes. |
| Base.DoubleBarrelShotgun | MarzGuns.DOUBLEBARREL (+DOUBLEBARREL_Barrel_Close) | H | Same class; 2 shells. |
| Base.DoubleBarrelShotgunSawnoff | MarzGuns.DOUBLEBARREL (+DOUBLEBARREL_Barrel_Sawnoff_Close) | H | GoM represents sawn-off as a barrel part with the same sawn stats (AimingTime 30, HitChance 70, spread 2.0, +MaxRange 15). |
| Base.Side_By_Side | MarzGuns.DOUBLEBARREL (barrel part mapped 1:1, see C.5) | H | SxS break action; DOUBLEBARREL is GoM's plain double barrel (STEVENS_555/TOZ34 are alternatives). |

**Vanilla revolvers reroll.** `Base.Revolver` (.357), `Base.Revolver_Short` (.38) and `Base.Revolver_Long` (.44) are not MarzVanillaGuns items, but they are converted too. Each one becomes a **random** Guns of Marz handgun (attachment type `Holster*`) whose ammo family accepts the revolver's rounds, with its state kept and no bonus items:
- .357 and .38 (GoM's `.38 .357` family): PYTHON, RHINO, MP412 or DETECTIVE_38
- .44: SW629

The pool is built at runtime from `Map.RerollCandidates` (`Convert.rerollPool`).

Note on vanilla-ID weapons: Base.Pistol, Pistol2, Pistol3, AssaultRifle, AssaultRifle2, Shotgun, ShotgunSawnoff, VarmintRifle, HuntingRifle, MSR7T_Rifle, JS3T_Shotgun, JS14_Rifle, L92_Carbine, L94_Rifle, TrapperCarbine, DoubleBarrelShotgun(+Sawnoff) keep existing after MVG removal as plain vanilla guns. Converting them is the user's choice; if you do NOT convert them you must still strip MVG-only parts (OpenBolt/CloseBolt, MVG mags as Clip parts, silencers/muzzles) and clear Gunworks modData, otherwise they load with unknown parts.

### C.2 Magazines (loose items; when mounted/inserted see "host-dependent" rule)

| MVG | GoM | Conf | Reasoning |
|---|---|---|---|
| Base.9mmClip (15) | MarzGuns.9x19Magazine15_M92FS | H | Author's mapping; same capacity. Host-dependent: inside a Pistolm93r -> MarzGuns.9x19Magazine18_M93R (18 >= 15). |
| Base.44Clip (8, .44) | MarzGuns.50Magazine8_DEAGLE, **emptied** | Function | Pistol3 now becomes the SW629 revolver, which takes no magazine. The functional equivalent is GoM's 8-round heavy-pistol magazine. It holds .50 AE, so every loaded .44 round is taken out first and kept as `SWMG.44_Bullet`. |
| Base.45Clip (7) | MarzGuns.45Magazine7_M1911 | H | Also the CAMP_CARBINE mag. |
| Base.M14Clip (20) | MarzGuns.762x51Magazine20_M14 | H | |
| Base.JS14_Clip (20) | MarzGuns.223Magazine20_Mini14 | H/M | Same capacity, 5.56x45mm family. |
| Base.JS14_Clip_30 | MarzGuns.223Magazine30_Mini14 | H/M | |
| Base.JS5_Clip (30) | MarzGuns.9x19Magazine30_MP5 | M | Follows JS5 -> MP5. |
| Base.556Clip_20 | MarzGuns.556x45Magazine20_STANAG | H | |
| Base.556Clip (30) | MarzGuns.556x45Magazine30_STANAG | H | |
| Base.556Clip_75 | MarzGuns.556x45Magazine75_STANAG | H | |
| Base.308Clip_10 | MarzGuns.762x51Magazine20_M14 | M | Follows SR25 -> M14; capacity up, no loss. (If you pick PSG1 instead you'd lose 5 rounds per mag.) |
| Base.308Clip_20 | MarzGuns.762x51Magazine20_M14 | M | Two MVG types collapse into one GoM type (fine; not reversible). |
| Base.762Clip_30 | MarzGuns.762x39Magazine30 | H | |
| Base.762Clip_75 | MarzGuns.762x39Magazine75 | H | |
| Base.9mmClip_25 | MarzGuns.9x19Magazine25_MP5 | H | |
| Base.9mmClip_30 | MarzGuns.9x19Magazine30_MP5 | H | |
| Base.9mmClip_40 | MarzGuns.9x19Magazine60_MP5 | M | No 40; next larger in same profile, no loss. |
| Base.9mmClip_100 | MarzGuns.9x19Magazine100_MP5 | H | |

Host-dependent rule for a gun's inserted magazine: use the mapped type if the target gun accepts it. Otherwise use the largest magazine in the target's profile; if it holds fewer rounds than are loaded, the surplus rounds stay in a second, loose magazine of the mapped type (or loose rounds when the magazine is not an MVG item). Nothing is discarded.

### C.3 Ammo: rounds, boxes and cartons

**Decision:** convert every round, box and carton, using the same targets as GoM's own
`VanillaAmmoMap` in `VanillaReplacerTable.lua`. Rounds become `SWMG.*` items; boxes and cartons
become `MarzGuns.*` items. The vanilla items are still valid in GoM, so this is for consistency
rather than to prevent loss. The MarzVanillaGuns 7.62x39 items are the only ones that would be
lost without conversion.

Round counts, checked against the recipes:

| Recipe source | Box | Carton |
|---|---|---|
| Vanilla (`recipes_ammunition.txt`, `recipes_packing.txt`) | 50 for 9mm, .45, .38, .357; 20 for .44, .308, 5.56, .30-30; 25 for shotgun shells | 12 boxes (`OpenCarton12`) |
| MarzVanillaGuns (`recipes.txt`) | 20 for 7.62x39 (`OpenBoxOfBullets20_mvgi`) | 12 boxes (`OpenCarton12_mvgi`) |
| GoM (`recipes/ammunition.txt`) | By tag: `marzguns:ammobox50` / `ammobox25` / `ammobox20` / `ammobox10` | 12 boxes (`OpenCartonOfBoxesOfAmmo`) |

| From | To | Rounds from → to | Conversion |
|---|---|---|---|
| `Base.762Bullets` (MVG only) | `SWMG.762x39_Bullet` | 1 → 1 | 1:1 |
| `Base.762Box` (MVG only) | `MarzGuns.762x39_Box` | 20 → 20 | 1:1 |
| `Base.762Carton` (MVG only) | `MarzGuns.762x39_Carton` | 240 → 240 | 1:1 |
| `Base.Bullets9mm` | `SWMG.9x19_Bullet` | 1 → 1 | 1:1 |
| `Base.Bullets9mmBox` | `MarzGuns.9x19_Box` | 50 → 50 | 1:1 |
| `Base.Bullets9mmCarton` | `MarzGuns.9x19_Carton` | 600 → 600 | 1:1 |
| `Base.Bullets45` | `SWMG.45_Bullet` | 1 → 1 | 1:1 |
| `Base.Bullets45Box` | `MarzGuns.45_Box` | 50 → 50 | 1:1 |
| `Base.Bullets45Carton` | `MarzGuns.45_Carton` | 600 → 600 | 1:1 |
| `Base.Bullets38` | `SWMG.38_Bullet` | 1 → 1 | 1:1 |
| `Base.Bullets38Box` | `MarzGuns.38_Box` | 50 → 50 | 1:1 |
| `Base.Bullets38Carton` | `MarzGuns.38_Carton` | 600 → 600 | 1:1 |
| `Base.Bullets357` | `SWMG.357_Bullet` | 1 → 1 | 1:1 |
| `Base.Bullets357Box` | `MarzGuns.357_Box` | 50 → 50 | 1:1 |
| `Base.Bullets357Carton` | `MarzGuns.357_Carton` | 600 → 600 | 1:1 |
| `Base.Bullets44` | `SWMG.44_Bullet` | 1 → 1 | 1:1 |
| `Base.Bullets44Box` | **repack** | 20 → GoM boxes hold 25 | 20 loose `SWMG.44_Bullet` |
| `Base.Bullets44Carton` | **repack** | 240 → GoM boxes hold 25 | 9 `MarzGuns.44_Box` (225) + 15 loose `SWMG.44_Bullet` |
| `Base.308Bullets` | `SWMG.762x51_Bullet` | 1 → 1 | 1:1 |
| `Base.308Box` | `MarzGuns.762x51_Box` | 20 → 20 | 1:1 |
| `Base.308Carton` | `MarzGuns.762x51_Carton` | 240 → 240 | 1:1 |
| `Base.556Bullets` | `SWMG.556x45_Bullet` | 1 → 1 | 1:1 |
| `Base.556Box` | `MarzGuns.556x45_Box` | 20 → 20 | 1:1 |
| `Base.556Carton` | `MarzGuns.556x45_Carton` | 240 → 240 | 1:1 |
| `Base.3030Bullets` | `SWMG.3030_Bullet` | 1 → 1 | 1:1 |
| `Base.3030Box` | `MarzGuns.3030_Box` | 20 → 20 | 1:1 |
| `Base.3030Carton` | `MarzGuns.3030_Carton` | 240 → 240 | 1:1 |
| `Base.ShotgunShells` | `SWMG.12Gauge_Shell_Buckshot` | 1 → 1 | 1:1 |
| `Base.ShotgunShellsBox` | `MarzGuns.12Gauge_Box_Buckshot` | 25 → 25 | 1:1 |
| `Base.ShotgunShellsCarton` | `MarzGuns.12Gauge_Carton_Buckshot` | 300 → 300 | 1:1 |

Notes:

- **.308 goes to `SWMG.762x51_Bullet`, not `SWMG.308_Bullet`.** This is GoM's own choice.
  `SWMG.308_Bullet` is the weaker "civilian" profile (−25% damage), while `762x51` keeps vanilla
  .308's stats.
- **The .44 box and carton are repacked, not swapped.** A 1:1 swap would turn 20 rounds into 25.
  Repacking gives exactly the same number of rounds.
- **Rounds inside guns and magazines are converted too.** Remap every entry of `AmmoList` and
  `SpentAmmoList` with the round rows above.
- **Player ammo preferences:** remap the bullet types inside `GunworksAmmoPref` on each player
  the same way.
- **Stack state:** ammo items carry little state. Copy favourite, custom name and modData anyway,
  and keep the item in the same container, hotbar slot or floor position.
- **Hot Brass casings** (`HBVCEF.*_Casing`, including `762x39_Casing`) belong to Hot Brass, not
  MarzVanillaGuns, so they stay as they are.
- **Hot Brass Ammo Crafting** has `*_VWP` recipes that make and disassemble `Base.762Bullets`.
  They stop applying once MarzVanillaGuns is gone, which does not affect saved items.
- `MarzGuns.*_Bullet` round scripts are orphans; never convert to them.
- `Base.223Bullets` is registered by MarzVanillaGuns but never defined, so nothing exists to
  convert.
- **Open question:** vanilla weapons MarzVanillaGuns never touched (`Base.Revolver`,
  `Revolver_Long`, `Revolver_Short`) use `.38`/`.357`/`.44` ammo. GoM's `patchAllItemsAmmo`
  registers every item with an ammo type into GoM's ammo families, so those revolvers should
  accept `SWMG` rounds through the framework. Check this in game before relying on it.
### C.4 Attachments: matched by function

**Rule:** every attachment becomes the GoM part that does the same job. The job is read from the
stats each part changes (script modifiers plus `AttachmentCustomStats.lua` in both mods).

1. If the converted gun accepts that part, mount it, together with any parent part GoM requires
   (`AttachmentsRequiredParts.lua`, e.g. `Picatinny_Rail_Up` for rifle optics).
2. If the gun does not accept the first choice, try the next part in the same function list
   that it does accept.
3. If the gun accepts nothing in that function, the first choice goes into the same container as a
   loose item.

Vanilla-ID attachments (`x2Scope`, `Laser`, and so on) are converted too, loose or mounted, so
nothing from the old set remains.

How MVG effects translate: rifle base sight range is 10 and aiming time about 45; pistol base
sight range is 6 and aiming time 25. A +5 aiming time on a rifle is therefore about ×1.1, and a
sight range of 16 is ×1.6.

| MVG part | What it does (MVG) | Function | GoM choices, in order | Loose fallback |
|---|---|---|---|---|
| `x2Scope` | sight range 12 (×1.2), aim +5 (×1.1) | Low-power scope | `LR4X_Scope` (×1.2 range, ×1.1 aim: exact), then `Aimpoint_Sight`, `EXPS1_Sight` | `LR4X_Scope` |
| `x4Scope` | sight range 16 (×1.6), aim +10 (×1.22) | Mid-power scope | `PSO1_Scope` (×1.5, ×1.3), then `LR10X_Scope`, `TA28_Scope`, `EXPS3_Sight` | `PSO1_Scope` |
| `x8Scope` | sight range 22 (×2.2), aim +20 (×1.44) | High-power scope | `LRX12X_Scope` (×2.0, ×1.5), then `LR10X_Scope`, `TR06X_Scope` | `LRX12X_Scope` |
| `RedDot` | aim −10 (×0.78), no magnification | Fast-aim reflex sight | Rifles: `ReflexS2_Sight` (aim ×0.9), then `Kobra_Sight`, `OKP3_Sight`. Pistols: `PS1_Sight` | `ReflexS2_Sight` |
| `TritiumSights` | aim −3, pistol sight | Pistol sight | `PL4_Sight` (+ `Beretta_Mount` / `Colt_Mount` / `Heavy_Pistol_Rail`), then `PS1_Sight` | `PL4_Sight` |
| `Laser` | aim −10, hit +5 | Aiming laser | Pistols: `PX1_Laser`. Rifles/SMGs: `LRX-7_Laser` (aim ×0.9, hit ×1.03) + `Picatinny_Rail_Right`, then `AimRight_Laser` | Pistol: `PX1_Laser`; long gun: `LRX-7_Laser` |
| `GunLight` | flashlight, aim +5 | Weapon light | Pistols: `TL_Light`, then `LP_Light`. Rifles/SMGs: `SR7_Light` + `Picatinny_Rail_Left`, then `BrightPoint-5_Light`. Battery charge and on/off state are copied | Pistol: `TL_Light`; long gun: `SR7_Light` |
| `Pistol_Silencer` | sound ×0.3, damage ×0.9 | Pistol suppressor | 9mm pistols: `Shh9_Suppressor` + `Pistol_Muzzle_Mount_Device`. .45 pistols: `P45_Suppressor` + `45_Muzzle_Mount_Device` | `Shh9_Suppressor` |
| `Heavy_Pistol_Silencer` | sound ×0.3, damage ×0.9, heavy pistol | Heavy pistol suppressor | `P45_Suppressor` + `45_Muzzle_Mount_Device` when the gun accepts it. The SW629 (Pistol3's target) accepts no suppressor | `P45_Suppressor` |
| `AR_Silencer` | sound ×0.3, damage ×0.9 | Rifle suppressor | AR family and MINI_14: `MKI_Suppressor` + `AR_Muzzle_Mount_Device`, then `NDR_Suppressor`. AK47: `PBS-1_Suppressor` + `AK_Muzzle_Mount_Device` | `MKI_Suppressor` |
| `556Muzzle` | sound ×0.99 | Flash hider | `LX_Flashhider` (sound ×0.95) + `AR_Muzzle_Mount_Device` | `LX_Flashhider` |
| `762Muzzle` | sound ×0.99 | Flash hider (AK) | GoM has no AK flash hider, so `AK_Muzzle_Mount_Device` (the AK muzzle device) is mounted; the AK47 accepts nothing else in this function | `LX_Flashhider` |
| `ChokeTubeFull` | spread −0.4, range +2 | Tightens the shot pattern for range | No GoM part changes spread or range on a shotgun. The nearest job is a muzzle device that improves accuracy: `LR2_Compensator`. It mounts only on the AR family, never on a shotgun | `LR2_Compensator` |
| `ChokeTubeImproved` | spread −0.2, range +1 | Milder pattern tightening | Same as above, one step down: `LX_Flashhider` | `LX_Flashhider` |
| `RecoilPad` | recoil delay −2 | Recoil reduction | `Shellholder` (recoil delay ×0.6, the only GoM part that reduces recoil) on DOUBLEBARREL / STEVENS_555 / TOZ34, then `Stub_Foregrip` + `Picatinny_Rail_Down` (recoil control on M14 / PSG1 / AR family) | `Shellholder` |
| `AmmoStraps` | reload −5, ammo carried on the gun | Ammo carrier / sling | DOUBLEBARREL: `Shellholder`. REMINGTON_700: `Rem700_Sling`. MODEL_70: `Model_70_Sling` | Shotguns: `Shellholder`; rifles: `Rem700_Sling` |
| `M9_Bayonet_Attachment` | bayonet | Bayonet | `M9_Bayonet_Attachment` on M16A2 / M16A3 / M14 / MOSSBERG_590 / REMINGTON_870. Condition copied; `GW_BayonetDeployed` kept | `M9_BAYONET` knife, condition copied, `GW_BayonetDeployed = false` |

Conflicts: a gun holds one part per PartType. If two MVG parts map to the same GoM PartType (for
example `AmmoStraps` and `RecoilPad` both becoming `Shellholder` on a DOUBLEBARREL), the one that
maps directly is mounted (`AmmoStraps`) and the other goes loose.

Parent parts that GoM requires (rails and muzzle mount devices) are created new. They add a
little weight; nothing is taken away.

### C.5 Melee, generic and internal parts

| MVG | GoM | Conf | State represented / GoM representation |
|---|---|---|---|
| Base.M9_Bayonet | MarzGuns.M9_BAYONET | H | Real knife; copy condition, sharpness, blood, favourite, name. |
| Base.Attack_Bayonet | MarzGuns.Attack_Bayonet | H (internal) | Transient spear substitute swapped into hands during a bayonet stab; cached in weapon modData GW_CachedBayonetSpear. Should never persist in inventory; if found (crash mid-attack) convert or delete. |
| Base.GenericFakeItem | MarzGuns.FakeItem | internal | Dummy MountOn target for internal parts; never expected in inventories. |
| Base.CloseBolt (MovingBolt) | target's "locked" part: Slide_Lock (pistols), Bolt_Lock (rifles/SMGs/bolt guns/CAMP_CARBINE/MINI_14/SPAS12), Pump_Lock (MOSSBERG_590, SPAS12), Lever_Lock (W1873/W1894) | internal | Action closed / in battery. GoM uses distinct PartTypes Slide/Bolt/Pump/Lever instead of MovingBolt. Remove MVG part; attach target's locked part (GoM required list). |
| Base.OpenBolt (MovingBolt) | target's "open" part: Slide_Fired, Bolt_Fired, Pump_Fired, Lever_Fired | internal | Action open (empty & locked back, or mid-cycle). Safe choice: attach "locked" and let Animations re-evaluate on next shot/rack; or attach *_Fired if !roundChambered && haveChamber && count==0. |
| Base.JS5_Stock_Folded / Deployed (StockIntegrated) | MarzGuns.MP5_Integrated_Stock_Folded / _Deployed | internal | Visual of FoldingStock state; the truth is modData.StockFolded. GoM uses the same framework: copy StockFolded and attach matching part (FoldingStock.RestoreFoldedStockState does it on load/equip). |
| Base.Side_By_Side_Barrel_Close | MarzGuns.DOUBLEBARREL_Barrel_Close | internal/H | Normal-length barrels, action closed. |
| Base.Side_By_Side_Barrel_Open | MarzGuns.DOUBLEBARREL_Barrel_Open | internal/H | Action open (breech broken). Recommend normalizing to _Close (MVG itself converts _Open->_Close on install). |
| Base.Side_By_Side_Barrel_Sawnoff_Close | MarzGuns.DOUBLEBARREL_Barrel_Sawnoff_Close | internal/H | Sawn-off barrels (persistent gun configuration, carries stats) - closed. |
| Base.Side_By_Side_Barrel_Sawnoff_Open | MarzGuns.DOUBLEBARREL_Barrel_Sawnoff_Open | internal/H | Sawn-off, open. |
| MVG magazines mounted as Clip part | GoM magazine type (C.2) mounted as Clip part | internal | Visual of the inserted magazine; truth = weapon.containsClip + weapon.magazineType + modData.MagazineType + currentAmmoCount + AmmoList. Both mods use Clip PartType and framework Magazine.manageMagazineAttachment. |

---

## D. Item state (modData + Java fields)

### D.1 modData keys (grep of getModData/modData across SWMG framework, MVG, GoM, Hot Brass)

| Key | On | Written by | Shape / meaning | Mod-specific values? | Migration action |
|---|---|---|---|---|---|
| AmmoList | weapon, magazine, speedloader | Framework CustomSystemHooks (ISLoadBulletsInMagazine animEvent append; ISInsertMagazine.loadAmmo mag->gun copy (+ keeps chambered round as last); ISEjectMagazine via Ammo.SplitAmmoListOnEject; ISReloadWeaponAction.loadAmmo append (inserted *before* the chambered round); ISUnloadBulletsFromFirearm removes index #-1; ISRackFirearm.removeBullet pops last; attack hook pops last and calls Ammo.AmmoProfileSetter(last)); SpeedLoader.TransferAmmoToGun; Server.lua/Client.lua sync; GoM OnCreate & GiveRandomMagAmmo (fills with ammoType itemKey); HB Tactical Reload (split on eject); HB TimedActionsHooks (pop on rack). MVG OnCreate never writes it. | Lua array (1..n) of bullet item fullType strings, one per round. **Last element = next round to fire** (chambered round on a gun / top round in a mag). On a gun with a chamber: #AmmoList == currentAmmoCount + (roundChambered ? 1 : 0) when fully tracked; may be shorter or nil for rounds that entered untracked (MVG OnCreate, vanilla code) -> framework then falls back to weapon ammoType. nil when empty. | YES - values are item types. MVG AK/mags contain `Base.762Bullets` -> translate to `SWMG.762x39_Bullet`. Vanilla types (Base.Bullets9mm, 556Bullets, 308Bullets, Bullets45, ShotgunShells, Bullets357/38, 3030Bullets) remain valid in GoM families. Base.Bullets44 in a gun/mag mapped to DEAGLE -> not valid, return rounds. | Copy with translation; pad missing entries at the *front* (index 1..) with the weapon's current ammo item key (translated) so length matches count; truncate from the front (returning rounds) if target capacity smaller. |
| SpentAmmoList | weapon (ManuallyRemoveSpentRounds guns: double barrels, revolvers) | Hot Brass TimedActionsHooks attack hook + server `appendSpent`; cleared by ejectSpentRounds | Array of bullet item fullTypes for spent casings still in the gun (used to pick casing type when ejected). | YES (item types; shotguns -> Base.ShotgunShells which is fine) | Copy (translate 762 if ever present); pairs with Java spentRoundCount. |
| MagazineType | weapon | Framework Magazine.SaveMagazineType (on insert), ClearMagazineType (on eject); MVG & GoM OnCreate | String fullType of the currently inserted magazine. Needed because Java magazineType is re-applied from this on load/equip (Magazine.RestoreMagazineType -> setMagazineType + setMaxAmmo(mag MaxAmmo)). Read by ReloadAnim/Visuals and ISEjectMagazine to decide what item pops out. | YES (MVG mag types) | Translate via C.2 host-dependent rule; nil if no clip. |
| MagazineTypeLastIndex | weapon | Magazine.getBestMagazineFromList / SaveMagazineType | Integer index into the weapon's magazine-profile list (round-robin reload preference). | Profile-specific (index meaning changes) | Recompute from new MagazineType in new profile, or nil. |
| ActiveAmmoProfile | weapon | Ammo.AmmoAdjustWeaponStats (on fire/rack) | String ammo stat profile name (e.g. "9x19mmAmmo", "38SpecialAmmo", "762x39mmAmmo"). Drives StatsFactory "Ammo" layer. Cleared for inventory weapons by Ammo.RestoreOnLoad on player create. | Family/profile names; MVG only knew 357MagnumAmmo/38SpecialAmmo (same names exist in GoM) | Set nil (it is rebuilt on the next shot). |
| GW_BayonetDeployed | weapon | MVG & GoM OnCreate, Bayonet.AttachBayonet/RemoveBayonet/Toggle, Server.lua sync, ISToggleIntegratedBayonet | Boolean: bayonet attached (attachable) or deployed (integrated). Melee attack becomes bayonet stab when true. | Generic | Keep true only if the bayonet part is re-attached on the target; else false/nil. |
| GW_CachedBayonetSpear | weapon | Bayonet.BayonetAttack | InventoryItem object (spear substitute) cached at runtime; not meaningful across save. | Object ref | Set nil. |
| GW_BayonetOriginalWeapon | temp spear item | Bayonet.BayonetAttack | Object ref back to the gun (transient). | - | Ignore / nil. |
| StockFolded | weapon | FoldingStock (toggle/set/restore), Server.lua sync | Boolean folded state; nil -> initialState on restore (folded for all MVG/GoM entries). Visual part swapped to match. | Generic | Copy for JS5 -> MP5; for MP5/MP5SD/M4A1 targets choose false (deployed) or nil. |
| BipodDeployed | weapon | FoldingBipod, Server.lua sync | Boolean; nil -> initialState (folded). | Generic | Not in MVG; nil for M24 target. |
| GW_RpmStage | weapon | RateOfFire.SetRpmStageIndex | Integer index into a multi-stage rpm table (GoM BAR only). | Generic | Not in MVG; nil. |
| GWG_FiringExplosiveAmmo | weapon | CustomSystemHooks attack hook; cleared by ExplosivesSystems client | Bullet type string of explosive round being fired (transient). | Item type | nil. |
| shortRackAfterInsert | weapon | ReloadAnim/Timing, consumed by ReloadAnimHooks | Transient bool. | Generic | nil. |
| GW_UBMode, GW_UBWeaponType, GW_UBAttachment, GW_UBModel ("host"/"self"), GW_UBHostSprite, GW_UBHostType, GW_UBHostSnapshot, GW_UBSelfSnapshot | weapon (and GW_UBHostSnapshot on player modData) | Framework Underbarrel (GoM M16A2_M203 only) | Snapshot tables: {type, condition, conditionMax, haveBeenRepaired, weaponSprite, customName, ammo={currentAmmoCount, roundChambered, spentRoundChambered, spentRoundCount, jammed, containsClip, magazineType, maxAmmo, ammoType(itemKey), fireMode, ammoList}, parts=[{type, partType, condition, modData}], modData, preservers}. | YES (item types) but never produced by MVG | Not present in MVG saves; nothing to migrate. Useful as a template of "full weapon state" to copy. |
| customName | weapon modData (Underbarrel only) | Underbarrel snapshot | name when isCustomName | - | Use item:getName()/setName/setCustomName instead. |
| roundsNoJam | weapon | Old HBVCEF VFE override (`media/lua/client/HBVCEF_Overrites_VFE.lua`, legacy) | Integer shots-without-jam counter | Generic | Copy or ignore. |
| GunworksAmmoPref | **player** modData | Ammo.SetReloadPreferenceForFamily | {familyName -> ordered array of bullet fullTypes} reload preference. | Contains bullet types; MVG only had family ".38 .357" with vanilla types (still valid in GoM). | No change needed (entries not in registry are ignored). |
| Gunworks_SpawnerItemType | GoM spawner items | ItemSpawnCore | Selected fullType for a spawner. | GoM only | n/a |
| MarzGuns_ZombieAttachmentsSynced | zombie modData | GoM ZombieAttachmentHooks | bool | GoM only | n/a |
| (MarzGunsSpawnerWeaponType) | spawner items | old "GunsOfMarzPreviousVersion" only | string | - | n/a |

No other keys: StatsFactory keeps base stats from the script (not modData); Animations, Railing, UniversalAttachment, RequiredAttachment, CustomStatsAttachments, PreventRemoval, UpgradeExclusives, ConditionalModel store no modData - their state is purely *which parts are attached*.

### D.2 How loaded ammo is represented

- **Magazine item** (MVG and GoM both WeaponPart/Clip): Java `currentAmmoCount`, `maxAmmo` (script), `ammoType` enum (changed by Ammo.MagazineAmmoProfileSetter when a different bullet is loaded), plus modData.AmmoList (bottom -> top; last = top round). Unload pops the last element into an item of that type.
- **Gun with detachable magazine**: Java `containsClip`, `magazineType` (restored from modData.MagazineType), `maxAmmo` (= magazine MaxAmmo), `currentAmmoCount` (rounds in magazine), `roundChambered`, `spentRoundChambered`, `jammed`, `ammoType` enum (set to the enum of the last-fired bullet via Ammo.AmmoProfileSetter), `fireMode`; plus modData.AmmoList holding magazine rounds followed by the chambered round as the final element; plus the magazine's visual WeaponPart (PartType Clip) of type MagazineType. On eject, SplitAmmoListOnEject keeps only the last element in the gun if chambered and gives the rest to the new magazine item.
- **Tube/internal/revolver/break-action gun**: `currentAmmoCount`, `roundChambered`, `spentRoundCount` / `spentRoundChambered`, AmmoList (reload inserts new rounds below the chambered one), Hot Brass SpentAmmoList for spent shells.
- **Values containing full types that need remapping**: AmmoList entries (Base.762Bullets -> SWMG.762x39_Bullet; .44 into DEAGLE -> return), SpentAmmoList entries, modData.MagazineType (all MVG mag types), Java `magazineType` (set from mapped mag), Java `ammoType` (set target default enum or the enum of the last AmmoList entry via Ammo.GetEnumForBullet), part lists (every mounted part type), GW_UB* snapshots (not present in MVG saves).
- **MVG AmmoType id** `mvgi:bullets_762` is on MVG AK/762 mags; GoM equivalents use `swmg:bullet_762x39`.

### D.3 Checklist of non-modData state to copy on every converted weapon/part

Weapon: condition, conditionMax-relative ratio if different, haveBeenRepaired, name/customName, favourite, bloodLevel, dirtyness/wetness, currentAmmoCount, roundChambered, spentRoundChambered, spentRoundCount, jammed, containsClip, magazineType, maxAmmo, fireMode (only if in target FireModePossibilities; MVG uses "Single"/"Burst"/"Auto", same strings as GoM), ammoType, attached hotbar slot/`attachedSlot`/`attachedSlotType`/`attachedToModel`, equipped hands, container & world position (IsoWorldInventoryObject xyz offsets, vehicle containers, corpses). Parts: per-part condition (bayonet), GunLight battery (`getCurrentUsesFloat`)/activated. After conversion call StatsFactory.ReapplyAllModifiers(weapon) / let Init.lua restore functions run, and in MP use syncHandWeaponFields + Ammo.SyncAmmoListToClient.
