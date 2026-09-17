TEST_FAILURES = 0

local function check(cond, message)
    if cond then
        PrintToConsole("  ok   " .. message)
    else
        TEST_FAILURES = TEST_FAILURES + 1
        PrintToConsole("  FAIL " .. message)
    end
end

local function test(name, fn)
    PrintToConsole(name)
    local ok, err = pcall(fn)
    if not ok then
        TEST_FAILURES = TEST_FAILURES + 1
        PrintToConsole("  FAIL (error) " .. tostring(err))
    end
end

require("MarzWeapons/Registries/Ammunition")
require("MarzWeapons/Registries/Magazines")
require("MarzWeapons/Registries/AttachmentsRequiredParts")
require("MarzWeapons/Registries/UpgradeExclusives")
require("MarzWeapons/Registries/Bayonets")
require("MarzWeapons/Registries/Stocks")
require("MarzWeapons/Registries/Bipods")
require("MarzWeapons/OnCreate/CustomWeaponOnCreate")
require("MarzWeapons/OnCreate/VanillaReplacer")

local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")
local FoldingBipod = require("WeaponSystems/Utils/FoldingBipod")
local Bayonet = require("WeaponSystems/Utils/Bayonet")
StatsFactory.ReapplyAllModifiers = function() end
Underbarrel.RestoreOnLoad = function() end
FoldingBipod.RestoreDeployedBipodState = function() end
Bayonet.RestoreIntegratedBayonetState = function() end

local tickHandlers = {}
Events.OnTick = { Add = function(fn) tickHandlers[#tickHandlers + 1] = fn end, Remove = function() end }
local function tick(n)
    for _ = 1, n do
        for _, fn in ipairs(tickHandlers) do fn() end
    end
end

require("VWP2GoM/VWP2GoM_Server")
local Map = require("VWP2GoM/VWP2GoM_Map")

local ROUND_ITEMS = {}
for _, v in pairs(Map.Rounds) do ROUND_ITEMS[v] = true end
for k in pairs(Map.Rounds) do ROUND_ITEMS[k] = true end

local function items(container)
    local out = {}
    local list = container:getItems()
    for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    return out
end

local function ofType(container, fullType)
    local out = {}
    for _, item in ipairs(items(container)) do
        if item:getFullType() == fullType then out[#out + 1] = item end
    end
    return out
end

local function partTypes(weapon)
    local set = {}
    local list = weapon:getAllWeaponParts()
    for i = 0, list:size() - 1 do set[list:get(i):getFullType()] = true end
    return set
end

local function roundsIn(container)
    local total = 0
    for _, item in ipairs(items(container)) do
        local t = item:getFullType()
        if ROUND_ITEMS[t] then
            total = total + 1
        elseif instanceof(item, "HandWeapon") then
            total = total + item:getCurrentAmmoCount() + (item:isRoundChambered() and 1 or 0)
        elseif item:getMaxAmmo() > 0 then
            total = total + item:getCurrentAmmoCount()
        end
    end
    return total
end

local function noSources(container)
    for _, item in ipairs(items(container)) do
        if Map.IsSource(item:getFullType()) then return false end
    end
    return true
end

local function mvgWeapon(fullType, opts)
    local w = instanceItem(fullType)
    assert(w, "no script for " .. fullType)
    opts = opts or {}
    for _, p in ipairs(opts.parts or {}) do
        w:attachWeaponPart(instanceItem(p), false)
    end
    if opts.mag then
        w:setMagazineType(opts.mag)
        w:setContainsClip(true)
        w:getModData().MagazineType = opts.mag
        w:attachWeaponPart(instanceItem(opts.mag), false)
    end
    w:setCurrentAmmoCount(opts.count or 0)
    w:setRoundChambered(opts.chambered or false)
    if opts.ammoList then w:getModData().AmmoList = opts.ammoList end
    if opts.condition then w:setCondition(opts.condition, false) end
    return w
end

local function repeatList(value, n)
    local t = {}
    for i = 1, n do t[i] = value end
    return t
end

test("Glock in hand with silencer, laser, tritium sights and a loaded magazine", function()
    local player = NewCharacter()
    local inv = player:getInventory()
    local glock = mvgWeapon("Base.PistolGlock", {
        parts = { "Base.Pistol_Silencer", "Base.Laser", "Base.TritiumSights", "Base.CloseBolt" },
        mag = "Base.9mmClip", count = 12, chambered = true,
        ammoList = repeatList("Base.Bullets9mm", 5), condition = 7,
    })
    glock:setFavorite(true)
    glock:setName("Old Faithful")
    glock:setCustomName(true)
    glock:getModData().SomeOtherMod = { keep = 1 }
    inv:AddItem(glock)
    player:setPrimaryHandItem(glock)
    player:setAttachedItem("Holster Right", glock)
    local before = roundsIn(inv)

    VWP2GoM.scanPlayer(player)

    local guns = ofType(inv, "MarzGuns.M92FS")
    check(#guns == 1, "one M92FS")
    local gun = guns[1]
    local parts = partTypes(gun)
    check(parts["MarzGuns.Shh9_Suppressor"] and parts["MarzGuns.Pistol_Muzzle_Mount_Device"], "suppressor mounted with its muzzle device")
    check(parts["MarzGuns.PX1_Laser"], "pistol laser mounted")
    check(parts["MarzGuns.PL4_Sight"] and parts["MarzGuns.Beretta_Mount"], "pistol sight mounted on Beretta mount")
    check(parts["MarzGuns.Slide_Lock"], "slide part present")
    check(parts["MarzGuns.9x19Magazine15_M92FS"], "magazine visual part present")
    check(gun:isContainsClip() and gun:getMagazineType() == "MarzGuns.9x19Magazine15_M92FS", "magazine inserted")
    check(gun:getCurrentAmmoCount() == 12 and gun:isRoundChambered(), "12 in magazine plus chambered")
    check(#gun:getModData().AmmoList == 13 and gun:getModData().AmmoList[13] == "SWMG.9x19_Bullet", "AmmoList padded and translated")
    check(gun:getCondition() == 7, "condition 7/10 kept")
    check(gun:isFavorite() and gun:getName() == "Old Faithful", "favourite and custom name kept")
    check(gun:getModData().SomeOtherMod and gun:getModData().SomeOtherMod.keep == 1, "other modData kept")
    check(gun:getModData().VWP2GoM.from == "Base.PistolGlock", "origin recorded")
    check(player:getPrimaryHandItem() == gun, "still in hand")
    check(player:attachedAt("Holster Right") == gun, "still in holster slot")
    check(roundsIn(inv) == before, "rounds conserved (" .. before .. ")")
    check(noSources(inv), "no MarzVanillaGuns items left")
    check(#items(inv) == 1, "no loose items needed")
end)

test("AK-47 on the back with a 75-round drum, suppressor, x4 scope and bayonet", function()
    local player = NewCharacter()
    local inv = player:getInventory()
    local ak = mvgWeapon("Base.AssaultRifleAK47", {
        parts = { "Base.AR_Silencer", "Base.x4Scope", "Base.M9_Bayonet_Attachment", "Base.OpenBolt" },
        mag = "Base.762Clip_75", count = 60, chambered = true,
        ammoList = repeatList("Base.762Bullets", 61),
    })
    ak:getModData().GW_BayonetDeployed = true
    inv:AddItem(ak)
    player:setAttachedItem("Back", ak)
    local before = roundsIn(inv)

    VWP2GoM.scanPlayer(player)

    local gun = ofType(inv, "MarzGuns.AK47")[1]
    check(gun ~= nil, "AK47 created")
    local parts = partTypes(gun)
    check(parts["MarzGuns.PBS-1_Suppressor"] and parts["MarzGuns.AK_Muzzle_Mount_Device"], "AK suppressor mounted")
    check(parts["MarzGuns.PSO1_Scope"] and parts["MarzGuns.AK_Mount"], "x4 scope became PSO-1 on AK mount")
    check(parts["MarzGuns.Bolt_Fired"], "open bolt kept as fired bolt")
    check(gun:getMagazineType() == "MarzGuns.762x39Magazine75" and gun:getCurrentAmmoCount() == 60, "drum with 60 rounds")
    check(#ofType(inv, "MarzGuns.M9_BAYONET") == 1, "bayonet returned as knife")
    check(player:attachedAt("Back") == gun, "still on back")
    check(roundsIn(inv) == before, "rounds conserved (" .. before .. ")")
    check(noSources(inv), "no MarzVanillaGuns items left")
end)

test("SR-25 with 18 rounds in a 20-round magazine becomes a PSG1", function()
    local crate = NewContainer("crate", nil)
    local sr = mvgWeapon("Base.SR25_Rifle", { mag = "Base.308Clip_20", count = 18, chambered = true })
    crate:AddItem(sr)
    local before = roundsIn(crate)

    VWP2GoM.scanContainer(crate)

    local gun = ofType(crate, "MarzGuns.PSG1")[1]
    check(gun ~= nil, "PSG1 created")
    check(gun:getMagazineType() == "MarzGuns.762x51Magazine5_PSG1" and gun:getCurrentAmmoCount() == 5, "PSG1 magazine holds 5")
    check(gun:isRoundChambered(), "chambered round kept")
    local spare = ofType(crate, "MarzGuns.762x51Magazine20_M14")
    check(#spare == 1 and spare[1]:getCurrentAmmoCount() == 13, "13 surplus rounds in a loose M14 magazine")
    check(roundsIn(crate) == before, "rounds conserved (" .. before .. ")")
end)

test("Desert Eagle .44 with a loaded magazine becomes an SW629", function()
    local crate = NewContainer("crate", nil)
    local de = mvgWeapon("Base.Pistol3", { mag = "Base.44Clip", count = 8, chambered = true, parts = { "Base.TritiumSights" } })
    crate:AddItem(de)
    local before = roundsIn(crate)

    VWP2GoM.scanContainer(crate)

    local gun = ofType(crate, "MarzGuns.SW629")[1]
    check(gun ~= nil, "SW629 created")
    check(gun:getCurrentAmmoCount() + (gun:isRoundChambered() and 1 or 0) <= 6, "cylinder not overfilled")
    check(#ofType(crate, "MarzGuns.50Magazine8_DEAGLE") == 1, "magazine returned as an empty heavy pistol magazine")
    check(partTypes(gun)["MarzGuns.PL4_Sight"], "sight mounted")
    check(roundsIn(crate) == before, "rounds conserved (" .. before .. ")")
    check(noSources(crate), "no MarzVanillaGuns items left")
end)

test("Double barrel with ammo straps, recoil pad and choke tube", function()
    local crate = NewContainer("crate", nil)
    local db = mvgWeapon("Base.DoubleBarrelShotgunSawnoff", {
        parts = { "Base.RecoilPad", "Base.AmmoStraps", "Base.ChokeTubeFull" }, count = 2,
    })
    crate:AddItem(db)
    local before = roundsIn(crate)

    VWP2GoM.scanContainer(crate)

    local gun = ofType(crate, "MarzGuns.DOUBLEBARREL")[1]
    check(gun ~= nil, "DOUBLEBARREL created")
    local parts = partTypes(gun)
    check(parts["MarzGuns.DOUBLEBARREL_Barrel_Sawnoff_Close"], "sawn-off barrels")
    check(parts["MarzGuns.Shellholder"], "ammo straps became the shell holder")
    check(#ofType(crate, "MarzGuns.Shellholder") == 1, "recoil pad returned as a loose shell holder")
    check(#ofType(crate, "MarzGuns.LR2_Compensator") == 1, "choke tube returned as a loose compensator")
    check(gun:getCurrentAmmoCount() == 2, "two shells kept")
    check(roundsIn(crate) == before, "rounds conserved (" .. before .. ")")
end)

test("Side by side with open sawn-off barrels and spent shells", function()
    local crate = NewContainer("crate", nil)
    local sxs = mvgWeapon("Base.Side_By_Side", { parts = { "Base.Side_By_Side_Barrel_Sawnoff_Open" }, count = 1 })
    sxs:getModData().SpentAmmoList = { "Base.ShotgunShells" }
    sxs:setSpentRoundCount(1)
    crate:AddItem(sxs)

    VWP2GoM.scanContainer(crate)

    local gun = ofType(crate, "MarzGuns.DOUBLEBARREL")[1]
    check(gun ~= nil and partTypes(gun)["MarzGuns.DOUBLEBARREL_Barrel_Sawnoff_Close"], "sawn-off barrels kept")
    check(gun:getModData().SpentAmmoList[1] == "SWMG.12Gauge_Shell_Buckshot", "spent shell list translated")
    check(gun:getSpentRoundCount() == 1, "spent count kept")
end)

test("JS5 with the stock deployed becomes an MP5 with the stock deployed", function()
    local crate = NewContainer("crate", nil)
    crate:AddItem(mvgWeapon("Base.JS5_smg", { parts = { "Base.JS5_Stock_Deployed" }, mag = "Base.JS5_Clip", count = 30 }))

    VWP2GoM.scanContainer(crate)

    local gun = ofType(crate, "MarzGuns.MP5")[1]
    check(gun ~= nil, "MP5 created")
    check(gun:getModData().StockFolded == false, "stock deployed")
    check(partTypes(gun)["MarzGuns.MP5_Integrated_Stock_Deployed"], "deployed stock part")
    check(gun:getCurrentAmmoCount() == 30, "30 rounds kept")
end)

test("Ammo boxes, cartons, loose magazines and parts in a bag inside a crate", function()
    local crate = NewContainer("crate", nil)
    local bag = instanceItem("Base.Bag_ALICEpack_Army") or instanceItem("Base.Bag_Schoolbag")
    local inner = crate
    if bag then
        crate:AddItem(bag)
        inner = bag:getInventory()
    end
    inner:AddItem(instanceItem("Base.Bullets44Carton"))
    inner:AddItem(instanceItem("Base.762Box"))
    inner:AddItem(instanceItem("Base.Bullets9mm"))
    local drum = instanceItem("Base.9mmClip_40")
    drum:setCurrentAmmoCount(35)
    inner:AddItem(drum)
    inner:AddItem(instanceItem("Base.x2Scope"))
    inner:AddItem(instanceItem("Base.GunLight"))

    VWP2GoM.scanContainer(crate)

    check(#ofType(inner, "MarzGuns.44_Box") == 9 and #ofType(inner, "SWMG.44_Bullet") == 15, ".44 carton repacked to 9 boxes + 15 rounds")
    check(#ofType(inner, "MarzGuns.762x39_Box") == 1, "7.62x39 box converted")
    check(#ofType(inner, "SWMG.9x19_Bullet") == 1, "loose 9mm round converted")
    local mags = ofType(inner, "MarzGuns.9x19Magazine60_MP5")
    check(#mags == 1 and mags[1]:getCurrentAmmoCount() == 35, "40-round magazine became a 60 with 35 rounds")
    check(#ofType(inner, "MarzGuns.LR4X_Scope") == 1, "x2 scope converted")
    check(#ofType(inner, "MarzGuns.TL_Light") == 1, "gun light converted")
    check(noSources(inner), "no MarzVanillaGuns items left")
end)

test("GoM random replacement is deferred and not applied to loaded items", function()
    local item = instanceItem("Base.Pistol")
    check(item ~= nil, "vanilla pistol instanced")
    check(MarzGuns_OnCreate.VWP2GoMWrapped == true, "GoM VanillaReplace is wrapped")
    MarzGuns_OnCreate.VanillaReplace(item)
    local crate = NewContainer("crate", nil)
    crate:AddItem(item)
    VWP2GoM.scanContainer(crate)
    check(#ofType(crate, "MarzGuns.M92FS") == 1, "deterministic conversion to M92FS")
end)

test("M16A2 keeps its mounted bayonet, red dot and laser", function()
    local crate = NewContainer("crate", nil)
    local rifle = mvgWeapon("Base.AssaultRifle", {
        parts = { "Base.M9_Bayonet_Attachment", "Base.RedDot", "Base.Laser" },
        mag = "Base.556Clip", count = 25, chambered = false,
    })
    rifle:getModData().GW_BayonetDeployed = true
    crate:AddItem(rifle)
    local before = roundsIn(crate)

    VWP2GoM.scanContainer(crate)

    local gun = ofType(crate, "MarzGuns.M16A2")[1]
    check(gun ~= nil, "M16A2 created")
    local parts = partTypes(gun)
    check(parts["MarzGuns.M9_Bayonet_Attachment"], "bayonet mounted (quoted MountOn handled)")
    check(gun:getModData().GW_BayonetDeployed == true, "bayonet flag kept")
    check(parts["MarzGuns.ReflexS2_Sight"] and parts["MarzGuns.Picatinny_Rail_Up"], "red dot on top rail")
    check(parts["MarzGuns.LRX-7_Laser"] and parts["MarzGuns.Picatinny_Rail_Right"], "rifle laser on right rail")
    check(gun:getFireMode() == "Burst", "burst fire mode kept")
    check(roundsIn(crate) == before, "rounds conserved (" .. before .. ")")
    check(#items(crate) == 1, "nothing loose")
end)

test("MP5 with a gun light gets a rifle light on the left rail", function()
    local crate = NewContainer("crate", nil)
    local smg = mvgWeapon("Base.MP5_SMG", { parts = { "Base.GunLight" }, mag = "Base.9mmClip_30", count = 30, chambered = true })
    smg:getWeaponPart("Canon"):setActivated(true)
    crate:AddItem(smg)
    local before = roundsIn(crate)

    VWP2GoM.scanContainer(crate)

    local gun = ofType(crate, "MarzGuns.MP5")[1]
    local parts = partTypes(gun)
    check(parts["MarzGuns.SR7_Light"] and parts["MarzGuns.Picatinny_Rail_Left"], "rifle light on left rail")
    check(gun:getWeaponPart("LightRifle"):isActivated(), "light still switched on")
    check(gun:getMagazineType() == "MarzGuns.9x19Magazine30_MP5" and gun:getCurrentAmmoCount() == 30, "30-round magazine")
    check(roundsIn(crate) == before, "rounds conserved (" .. before .. ")")
end)

test("L92 carbine with 10 rounds becomes a 9-round W1873", function()
    local crate = NewContainer("crate", nil)
    crate:AddItem(mvgWeapon("Base.L92_Carbine", { count = 10, chambered = false }))
    local before = roundsIn(crate)

    VWP2GoM.scanContainer(crate)

    local gun = ofType(crate, "MarzGuns.W1873")[1]
    check(gun ~= nil, "W1873 created")
    check(roundsIn(crate) == before, "rounds conserved (" .. before .. ")")
    check(#ofType(crate, "SWMG.357_Bullet") == before - gun:getCurrentAmmoCount() - (gun:isRoundChambered() and 1 or 0), "surplus as loose .357")
end)

test("Vanilla revolvers reroll to a GoM handgun of the same caliber", function()
    local Convert = require("VWP2GoM/VWP2GoM_Convert")
    local crate = NewContainer("crate", nil)
    local long = instanceItem("Base.Revolver_Long")
    long:setCurrentAmmoCount(6)
    local short = instanceItem("Base.Revolver_Short")
    short:setCurrentAmmoCount(5)
    local magnum = instanceItem("Base.Revolver")
    magnum:setCurrentAmmoCount(6)
    local pool = Convert.rerollPool(magnum)
    local names = {}
    for i = 1, #pool do names[i] = pool[i] end
    table.sort(names)
    check(table.concat(names, ",") == "MarzGuns.DETECTIVE_38,MarzGuns.MP412,MarzGuns.PYTHON,MarzGuns.RHINO",
        ".357/.38 pool is the four GoM .38/.357 revolvers (" .. table.concat(names, ",") .. ")")
    check(#Convert.rerollPool(long) == 1 and Convert.rerollPool(long)[1] == "MarzGuns.SW629", ".44 pool is the SW629")
    crate:AddItem(long)
    crate:AddItem(short)
    crate:AddItem(magnum)
    local before = roundsIn(crate)

    VWP2GoM.scanContainer(crate)

    check(#ofType(crate, "MarzGuns.SW629") == 1, ".44 revolver became an SW629")
    check(noSources(crate), "no vanilla revolvers left")
    check(roundsIn(crate) == before, "rounds conserved (" .. before .. ")")
end)

test("Dedicated server: packets for player inventory, hands and nested bags", function()
    SERVER_MODE = true
    SENT = {}
    local function sent(name)
        local out = {}
        for _, s in ipairs(SENT) do if s.name == name then out[#out + 1] = s end end
        return out
    end

    local player = NewCharacter()
    local inv = player:getInventory()
    local pistol = mvgWeapon("Base.Pistol", { mag = "Base.9mmClip", count = 15 })
    inv:AddItem(pistol)
    player:setPrimaryHandItem(pistol)
    VWP2GoM.scanPlayer(player)
    local gun = ofType(inv, "MarzGuns.M92FS")[1]
    check(#sent("replace") == 1, "replace sent for the player inventory")
    check(#sent("equip") == 0, "equip not sent in the same tick as the replace")
    tick(20)
    check(#sent("equip") == 1 and player:getPrimaryHandItem() == gun, "equip sent a few ticks later with the new gun in hand")
    check(#sent("serverCommand") == 1, "client told to refresh")

    SENT = {}
    local crate = NewContainer("crate", nil)
    local bag = instanceItem("Base.Bag_Schoolbag")
    if bag then
        crate:AddItem(bag)
        bag:getInventory():AddItem(instanceItem("Base.762Box"))
        VWP2GoM.scanContainer(crate)
        local removes, adds = sent("remove"), sent("add")
        local resent = false
        for _, r in ipairs(removes) do
            if r.args[1] == crate and r.args[2] == bag then resent = true end
        end
        check(resent and #adds >= 1, "bag nested in a crate is re-sent whole")
    else
        check(false, "no bag script available for the test")
    end

    SENT = {}
    local backpack = instanceItem("Base.Bag_Schoolbag")
    inv:AddItem(backpack)
    backpack:getInventory():AddItem(instanceItem("Base.762Box"))
    VWP2GoM.scanPlayer(player)
    check(#sent("remove") == 0, "bag in a player inventory is not re-sent (the replace reaches the owner)")
    SERVER_MODE = false
end)

PrintToConsole(string.format("\n%d failure(s)", TEST_FAILURES))
