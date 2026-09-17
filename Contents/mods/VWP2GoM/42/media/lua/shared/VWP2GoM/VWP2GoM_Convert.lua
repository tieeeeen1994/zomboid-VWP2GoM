local Map = require("VWP2GoM/VWP2GoM_Map")
local Ammo = require("WeaponSystems/Utils/Ammo")
local Magazine = require("WeaponSystems/Utils/Magazine")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
local FoldingStock = require("WeaponSystems/Utils/FoldingStock")
local FoldingBipod = require("WeaponSystems/Utils/FoldingBipod")
local Bayonet = require("WeaponSystems/Utils/Bayonet")
local RequiredAttachment = require("WeaponSystems/Utils/RequiredAttachment")
local UpgradeExclusives = require("WeaponSystems/Utils/UpgradeExclusives")
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")

local Convert = {}

Convert.LOG_FILE = "VWP2GoM.log"

function Convert.resetLog(header)
    local writer = getFileWriter(Convert.LOG_FILE, true, false)
    if writer then
        writer:writeln(header)
        writer:close()
    end
end

function Convert.log(line)
    print("[VWP2GoM] " .. line)
    local writer = getFileWriter(Convert.LOG_FILE, true, true)
    if writer then
        writer:writeln(line)
        writer:close()
    end
end

local function copyTable(source)
    if type(source) ~= "table" then
        return source
    end
    local result = {}
    for key, value in pairs(source) do
        result[key] = copyTable(value)
    end
    return result
end

local function scriptExists(fullType)
    return fullType ~= nil and getScriptManager():getItem(fullType) ~= nil
end

local function withoutGoMOnCreate(fn)
    local holder = MarzGuns_OnCreate
    local saved = holder and holder.AttachParts
    if holder then
        holder.AttachParts = function() end
    end
    local ok, result = pcall(fn)
    if holder then
        holder.AttachParts = saved
    end
    if not ok then
        error(result)
    end
    return result
end

function Convert.newItem(fullType)
    if not scriptExists(fullType) then
        return nil
    end
    return withoutGoMOnCreate(function()
        return instanceItem(fullType)
    end)
end

local function isHandgun(item)
    local attachment = item and item:getAttachmentType()
    return attachment ~= nil and string.sub(attachment, 1, 7) == "Holster"
end

local function listToTable(list)
    local result = {}
    if not list then
        return result
    end
    for i = 0, list:size() - 1 do
        result[#result + 1] = list:get(i)
    end
    return result
end

local function ratio(value, maxValue)
    if not maxValue or maxValue <= 0 then
        return 1
    end
    return value / maxValue
end

local function applyCondition(target, sourceCondition, sourceMax)
    local targetMax = target:getConditionMax()
    local condition
    if sourceCondition <= 0 then
        condition = 0
    elseif sourceCondition >= sourceMax then
        condition = targetMax
    else
        condition = math.floor(ratio(sourceCondition, sourceMax) * targetMax + 0.5)
        condition = math.max(1, math.min(targetMax, condition))
    end
    target:setCondition(condition, false)
end

function Convert.captureCommon(item)
    return {
        fullType = item:getFullType(),
        id = item:getID(),
        condition = item:getCondition(),
        conditionMax = item:getConditionMax(),
        repaired = item:getHaveBeenRepaired(),
        customName = item:isCustomName() and item:getName() or nil,
        favorite = item:isFavorite(),
        attachedSlot = item:getAttachedSlot(),
        attachedSlotType = item:getAttachedSlotType(),
        attachedToModel = item:getAttachedToModel(),
        worldZRotation = item:getWorldZRotation(),
        modData = item:hasModData() and copyTable(item:getModData()) or {},
    }
end

function Convert.applyCommon(target, state)
    applyCondition(target, state.condition, state.conditionMax)
    target:setHaveBeenRepaired(state.repaired)
    if state.customName then
        target:setName(state.customName)
        target:setCustomName(true)
    end
    target:setFavorite(state.favorite)
    target:setAttachedSlot(state.attachedSlot)
    target:setAttachedSlotType(state.attachedSlotType)
    target:setAttachedToModel(state.attachedToModel)
    target:setWorldZRotation(state.worldZRotation)
    local modData = target:getModData()
    for key, value in pairs(state.modData) do
        if not Map.TransientModData[key] then
            modData[key] = copyTable(value)
        end
    end
    modData.VWP2GoM = {
        from = state.fullType,
        version = Map.VERSION,
        original = copyTable(state.modData),
    }
end

function Convert.translateRound(roundType)
    return Map.Rounds[roundType] or roundType
end

local function familyForItem(item)
    local family = Ammo.ItemAmmoFamily[item:getFullType()]
    if family then
        return family
    end
    local ammoType = item:getAmmoType()
    local key = ammoType and ammoType:getItemKey()
    if key then
        local _, bulletFamily = Ammo.FindBulletEntry(key)
        return bulletFamily, key
    end
    return nil
end

function Convert.accepts(holder, roundType)
    local family, key = familyForItem(holder)
    if key and key == roundType then
        return true
    end
    return family ~= nil and Ammo.FindBulletIndexInFamily(family, roundType) ~= nil
end

local function sourceRoundType(item)
    local ammoType = item:getAmmoType()
    local key = ammoType and ammoType:getItemKey()
    return key and Convert.translateRound(key) or nil
end

function Convert.roundsOf(item, total)
    local rounds = {}
    local list = item:hasModData() and item:getModData().AmmoList or nil
    if type(list) == "table" then
        for i = 1, #list do
            rounds[#rounds + 1] = Convert.translateRound(list[i])
        end
    end
    local fill = sourceRoundType(item)
    while #rounds > total do
        table.remove(rounds, 1)
    end
    if #rounds < total and fill then
        local padded = {}
        for _ = 1, total - #rounds do
            padded[#padded + 1] = fill
        end
        for i = 1, #rounds do
            padded[#padded + 1] = rounds[i]
        end
        rounds = padded
    end
    return rounds
end

local function looseRounds(extras, rounds)
    for i = 1, #rounds do
        local round = Convert.newItem(rounds[i])
        if round then
            extras[#extras + 1] = round
        end
    end
end

local function setAmmoList(item, rounds)
    if #rounds > 0 then
        item:getModData().AmmoList = rounds
    else
        item:getModData().AmmoList = nil
    end
end

local function splitCompatible(holder, rounds, extras)
    local kept = {}
    local rejected = {}
    for i = 1, #rounds do
        if Convert.accepts(holder, rounds[i]) then
            kept[#kept + 1] = rounds[i]
        else
            rejected[#rejected + 1] = rounds[i]
        end
    end
    looseRounds(extras, rejected)
    return kept
end

local function takeTop(rounds, count)
    local bottom = {}
    local top = {}
    local split = #rounds - count
    for i = 1, #rounds do
        if i <= split then
            bottom[#bottom + 1] = rounds[i]
        else
            top[#top + 1] = rounds[i]
        end
    end
    return top, bottom
end

local function fillMagazine(magazine, rounds, extras)
    local kept = splitCompatible(magazine, rounds, extras)
    local capacity = magazine:getMaxAmmo()
    local inMagazine, surplus = takeTop(kept, math.min(capacity, #kept))
    looseRounds(extras, surplus)
    magazine:setCurrentAmmoCount(#inMagazine)
    setAmmoList(magazine, inMagazine)
end

function Convert.magazine(source)
    local targetType = Map.Magazines[source:getFullType()]
    local target = Convert.newItem(targetType)
    if not target then
        return nil
    end
    local extras = {}
    local state = Convert.captureCommon(source)
    Convert.applyCommon(target, state)
    local rounds = Convert.roundsOf(source, source:getCurrentAmmoCount())
    fillMagazine(target, rounds, extras)
    return target, extras
end

local function mountAllowed(weapon, part)
    local fullType = weapon:getFullType()
    local partType = part:getFullType()
    local bayonetWeapons = Bayonet.BayonetMountableWeapons
    local isBayonet = part:getPartType() == "BayonetKnife"
    if isBayonet then
        local accepted = bayonetWeapons and bayonetWeapons[fullType]
        if not accepted or not accepted[partType] then
            return false
        end
    else
        local mountOn = part:getMountOn()
        local found = false
        if mountOn then
            for i = 0, mountOn:size() - 1 do
                if mountOn:get(i) == fullType then
                    found = true
                    break
                end
            end
        end
        if not found then
            return false
        end
    end
    if weapon:getWeaponPart(part:getPartType()) then
        return false
    end
    if UpgradeExclusives.IsBlockedByExclusive(weapon, part:getFullType()) then
        return false
    end
    if Bayonet.IsBlockedByExclusive and Bayonet.IsBlockedByExclusive(weapon, part:getFullType()) then
        return false
    end
    return true
end

local function installed(weapon, fullType)
    return RequiredAttachment.IsPartInstalledOnWeapon(weapon, fullType)
end

local function attach(weapon, part)
    weapon:attachWeaponPart(part, true)
end

local function tryMount(weapon, partType, depth)
    local part = Convert.newItem(partType)
    if not part or not instanceof(part, "WeaponPart") then
        return nil
    end
    if not mountAllowed(weapon, part) then
        return nil
    end
    local added = {}
    local all = RequiredAttachment.Dependencies and RequiredAttachment.Dependencies[partType]
    local any = RequiredAttachment.AnyDependencies and RequiredAttachment.AnyDependencies[partType]
    if (all or any) and depth > 0 then
        return nil
    end
    local function rollback()
        for i = #added, 1, -1 do
            weapon:detachWeaponPart(added[i])
        end
    end
    if all then
        for parentType in pairs(all) do
            if not installed(weapon, parentType) then
                local parent = tryMount(weapon, parentType, depth + 1)
                if not parent then
                    rollback()
                    return nil
                end
                added[#added + 1] = parent
            end
        end
    end
    if any then
        local satisfied = false
        for parentType in pairs(any) do
            if installed(weapon, parentType) then
                satisfied = true
                break
            end
        end
        if not satisfied then
            for parentType in pairs(any) do
                local parent = tryMount(weapon, parentType, depth + 1)
                if parent then
                    added[#added + 1] = parent
                    satisfied = true
                    break
                end
            end
        end
        if not satisfied then
            rollback()
            return nil
        end
    end
    if not mountAllowed(weapon, part) then
        rollback()
        return nil
    end
    attach(weapon, part)
    return part
end

local function copyPartState(target, source)
    applyCondition(target, source:getCondition(), source:getConditionMax())
    if source:getMaxUses() > 0 and target:getMaxUses() > 0 then
        local uses = math.floor(ratio(source:getCurrentUses(), source:getMaxUses()) * target:getMaxUses() + 0.5)
        target:setCurrentUses(uses)
    end
    target:setActivated(source:isActivated())
    if source:hasModData() then
        local modData = target:getModData()
        for key, value in pairs(source:getModData()) do
            modData[key] = copyTable(value)
        end
    end
    target:getModData().VWP2GoM = { from = source:getFullType(), version = Map.VERSION }
end

function Convert.part(source, hostHint)
    local fullType = source:getFullType()
    local rule = Map.Parts[fullType]
    local targetType
    if rule then
        targetType = rule.loose
        if rule.looseLongGun and hostHint and not isHandgun(hostHint) then
            targetType = rule.looseLongGun
        end
    else
        targetType = Map.LooseOther[fullType]
    end
    local target = Convert.newItem(targetType)
    if not target then
        return nil
    end
    copyPartState(target, source)
    Convert.applyCommonLite(target, source)
    return target, {}
end

function Convert.applyCommonLite(target, source)
    target:setFavorite(source:isFavorite())
    if source:isCustomName() then
        target:setName(source:getName())
        target:setCustomName(true)
    end
end

function Convert.other(source)
    local targetType = Map.LooseOther[source:getFullType()]
    local target = Convert.newItem(targetType)
    if not target then
        return nil
    end
    if instanceof(source, "HandWeapon") and instanceof(target, "HandWeapon") then
        target:copyConditionStatesFrom(source)
        Convert.applyCommon(target, Convert.captureCommon(source))
    else
        copyPartState(target, source)
        Convert.applyCommonLite(target, source)
    end
    return target, {}
end

function Convert.round(source)
    local target = Convert.newItem(Map.Rounds[source:getFullType()])
    if not target then
        return nil
    end
    Convert.applyCommonLite(target, source)
    if source:hasModData() then
        local modData = target:getModData()
        for key, value in pairs(source:getModData()) do
            modData[key] = copyTable(value)
        end
    end
    return target, {}
end

function Convert.ammoPack(source)
    local fullType = source:getFullType()
    local packType = Map.AmmoPacks[fullType]
    if packType then
        local target = Convert.newItem(packType)
        if not target then
            return nil
        end
        Convert.applyCommonLite(target, source)
        return target, {}
    end
    local repack = Map.AmmoRepacks[fullType]
    if not repack or not scriptExists(repack.bullet) or not scriptExists(repack.box) then
        return nil
    end
    local extras = {}
    local boxes = math.floor(repack.rounds / repack.boxRounds)
    local loose = repack.rounds - boxes * repack.boxRounds
    for _ = 1, boxes do
        extras[#extras + 1] = Convert.newItem(repack.box)
    end
    for _ = 1, loose do
        extras[#extras + 1] = Convert.newItem(repack.bullet)
    end
    local main = table.remove(extras, 1)
    if main then
        Convert.applyCommonLite(main, source)
    end
    return main, extras
end

local function requiredParts(sourceType, targetType)
    local ok, table_ = pcall(require, "MarzWeapons/OnCreate/AttachmentPointsTable")
    local entry = ok and table_ and table_.weaponAttachmentTablesAndChances
        and table_.weaponAttachmentTablesAndChances[targetType]
    local list = {}
    local swaps = Map.RequiredPartSwaps[sourceType] or {}
    for _, partType in ipairs(entry and entry.required or {}) do
        list[#list + 1] = swaps[partType] or partType
    end
    return list
end

local function capturePartsByType(weapon)
    local parts = {}
    for _, part in ipairs(listToTable(weapon:getAllWeaponParts())) do
        parts[#parts + 1] = {
            item = part,
            fullType = part:getFullType(),
            partType = part:getPartType(),
        }
    end
    return parts
end

local function findPart(parts, fullType)
    for i = 1, #parts do
        if parts[i].fullType == fullType then
            return parts[i]
        end
    end
    return nil
end

local function mountRequired(target, source, sourceParts)
    local boltOpen = findPart(sourceParts, "Base.OpenBolt") ~= nil
    local barrel
    for i = 1, #sourceParts do
        if Map.Barrels[sourceParts[i].fullType] then
            barrel = Map.Barrels[sourceParts[i].fullType]
        end
    end
    for _, partType in ipairs(requiredParts(source:getFullType(), target:getFullType())) do
        local wanted = partType
        if boltOpen and string.find(wanted, "_Lock$") and not string.find(wanted, "Selector") then
            local fired = string.gsub(wanted, "_Lock$", "_Fired")
            if scriptExists(fired) then
                wanted = fired
            end
        end
        if barrel and string.find(wanted, "_Barrel_") then
            wanted = barrel
        end
        local part = Convert.newItem(wanted) or Convert.newItem(partType)
        if part and instanceof(part, "WeaponPart") and not target:getWeaponPart(part:getPartType()) then
            attach(target, part)
        end
    end
end

local function mountFunctional(target, sourceParts, extras)
    local ordered = {}
    local seen = {}
    for _, fullType in ipairs(Map.PartPriority) do
        local entry = findPart(sourceParts, fullType)
        if entry then
            ordered[#ordered + 1] = entry
            seen[entry] = true
        end
    end
    for i = 1, #sourceParts do
        if not seen[sourceParts[i]] then
            ordered[#ordered + 1] = sourceParts[i]
        end
    end
    local bayonetMounted = false
    for _, entry in ipairs(ordered) do
        local rule = Map.Parts[entry.fullType]
        if rule then
            local mounted
            for _, candidate in ipairs(rule.mount) do
                mounted = tryMount(target, candidate, 0)
                if mounted then
                    break
                end
            end
            if mounted then
                copyPartState(mounted, entry.item)
                if rule.bayonet then
                    bayonetMounted = true
                end
            else
                local loose = Convert.part(entry.item, target)
                if loose then
                    if rule.bayonet and instanceof(loose, "HandWeapon") then
                        loose:getModData().GW_BayonetDeployed = nil
                    end
                    extras[#extras + 1] = loose
                end
            end
        elseif not Map.InternalPartTypes[entry.partType] and not Map.LooseOther[entry.fullType] then
            extras[#extras + 1] = entry.item
        end
    end
    return bayonetMounted
end

local function sourceMagazineType(source)
    if not source:isContainsClip() then
        return nil
    end
    local modData = source:hasModData() and source:getModData() or nil
    return (modData and modData.MagazineType) or source:getMagazineType()
end

local function chooseMagazine(target, mappedType)
    local accepted = Magazine.GetMagazineTypesForGun(target)
    if not accepted or #accepted == 0 then
        local default = target:getMagazineType()
        return default
    end
    for i = 1, #accepted do
        if accepted[i] == mappedType then
            return mappedType
        end
    end
    local best, bestCapacity = nil, -1
    for i = 1, #accepted do
        local candidate = Convert.newItem(accepted[i])
        if candidate and candidate:getMaxAmmo() > bestCapacity then
            best, bestCapacity = accepted[i], candidate:getMaxAmmo()
        end
    end
    return best
end

local function loadWeapon(target, source, extras)
    local count = source:getCurrentAmmoCount()
    local chambered = source:isRoundChambered()
    local total = count + (chambered and 1 or 0)
    local rounds = Convert.roundsOf(source, total)
    local chamberRound
    if chambered and #rounds > 0 then
        chamberRound = table.remove(rounds)
    end
    rounds = splitCompatible(target, rounds, extras)
    if chamberRound and not Convert.accepts(target, chamberRound) then
        looseRounds(extras, { chamberRound })
        chamberRound = nil
    end

    local sourceMag = sourceMagazineType(source)
    local mappedMag = sourceMag and (Map.Magazines[sourceMag] or sourceMag)
    local gunRounds = {}

    if target:getMagazineType() ~= nil and target:getMagazineType() ~= "" then
        if sourceMag then
            local chosen = chooseMagazine(target, mappedMag)
            local chosenItem = chosen and Convert.newItem(chosen)
            if chosenItem then
                local capacity = chosenItem:getMaxAmmo()
                local top, bottom = takeTop(rounds, math.min(capacity, #rounds))
                gunRounds = top
                if chosen ~= mappedMag then
                    local spare = Convert.newItem(mappedMag)
                    if spare then
                        fillMagazine(spare, bottom, extras)
                        extras[#extras + 1] = spare
                    else
                        looseRounds(extras, bottom)
                    end
                else
                    looseRounds(extras, bottom)
                end
                target:setMagazineType(chosen)
                target:setMaxAmmo(capacity)
                target:setContainsClip(true)
                target:getModData().MagazineType = chosen
                Magazine.manageMagazineAttachment(target, chosen)
            else
                looseRounds(extras, rounds)
            end
        else
            looseRounds(extras, rounds)
            target:setContainsClip(false)
        end
    else
        if sourceMag then
            local spare = Convert.newItem(mappedMag)
            if spare then
                spare:setCurrentAmmoCount(0)
                extras[#extras + 1] = spare
            end
        end
        if chamberRound and not target:haveChamber() then
            rounds[#rounds + 1] = chamberRound
            chamberRound = nil
        end
        local capacity = target:getMaxAmmo()
        local top, bottom = takeTop(rounds, math.min(capacity, #rounds))
        gunRounds = top
        looseRounds(extras, bottom)
    end

    if chamberRound then
        if target:haveChamber() then
            target:setRoundChambered(true)
        else
            looseRounds(extras, { chamberRound })
            chamberRound = nil
        end
    end

    target:setCurrentAmmoCount(#gunRounds)
    local ammoList = {}
    for i = 1, #gunRounds do
        ammoList[#ammoList + 1] = gunRounds[i]
    end
    if chamberRound then
        ammoList[#ammoList + 1] = chamberRound
    end
    setAmmoList(target, ammoList)

    target:setJammed(source:isJammed())
    target:setSpentRoundChambered(source:isSpentRoundChambered())
    target:setSpentRoundCount(source:getSpentRoundCount())
    local spent = source:hasModData() and source:getModData().SpentAmmoList or nil
    if type(spent) == "table" then
        local translated = {}
        for i = 1, #spent do
            translated[#translated + 1] = Convert.translateRound(spent[i])
        end
        target:getModData().SpentAmmoList = translated
    end
end

local function applyFireMode(target, fireMode)
    if not fireMode then
        return
    end
    local possible = target:getFireModePossibilities()
    if not possible then
        return
    end
    for i = 0, possible:size() - 1 do
        if possible:get(i) == fireMode then
            target:setFireMode(fireMode)
            return
        end
    end
end

local random = newrandom()
local rerollPools = {}

function Convert.rerollPool(source)
    local round = sourceRoundType(source)
    local _, family = Ammo.FindBulletEntry(round or "")
    local key = tostring(family or round) .. (isHandgun(source) and "|handgun" or "|long")
    if rerollPools[key] then
        return rerollPools[key]
    end
    local pool = {}
    for _, candidateType in ipairs(Map.RerollCandidates) do
        local candidate = Convert.newItem(candidateType)
        if candidate and isHandgun(candidate) == isHandgun(source) and round
            and Convert.accepts(candidate, round) then
            pool[#pool + 1] = candidateType
        end
    end
    rerollPools[key] = pool
    return pool
end

function Convert.weaponTarget(source)
    local fullType = source:getFullType()
    if Map.Weapons[fullType] then
        return Map.Weapons[fullType]
    end
    if Map.RerollWeapons[fullType] then
        local pool = Convert.rerollPool(source)
        if #pool > 0 then
            return pool[random:random(#pool)]
        end
    end
    return nil
end

function Convert.weapon(source)
    local targetType = Convert.weaponTarget(source)
    local target = Convert.newItem(targetType)
    if not target then
        return nil
    end
    local extras = {}
    local state = Convert.captureCommon(source)
    local sourceParts = capturePartsByType(source)

    local folded = state.modData.StockFolded
    if findPart(sourceParts, "Base.JS5_Stock_Deployed") then
        folded = false
    elseif findPart(sourceParts, "Base.JS5_Stock_Folded") then
        folded = true
    end

    mountRequired(target, source, sourceParts)
    local bayonetMounted = mountFunctional(target, sourceParts, extras)
    loadWeapon(target, source, extras)
    applyFireMode(target, source:getFireMode())
    target:setBloodLevel(source:getBloodLevel())
    Convert.applyCommon(target, state)

    local modData = target:getModData()
    modData.VWP2GoM.parts = {}
    for i = 1, #sourceParts do
        modData.VWP2GoM.parts[i] = sourceParts[i].fullType
    end
    if bayonetMounted then
        modData.GW_BayonetDeployed = state.modData.GW_BayonetDeployed ~= false
    end
    if folded ~= nil then
        modData.StockFolded = folded
    end
    if state.modData.BipodDeployed ~= nil then
        modData.BipodDeployed = state.modData.BipodDeployed
    end

    Magazine.RestoreMagazineType(target)
    Underbarrel.RestoreOnLoad(target)
    FoldingStock.RestoreFoldedStockState(target)
    FoldingBipod.RestoreDeployedBipodState(target)
    Bayonet.RestoreIntegratedBayonetState(target)
    StatsFactory.ReapplyAllModifiers(target)
    return target, extras
end

function Convert.item(source, hostHint)
    local fullType = source:getFullType()
    if (Map.Weapons[fullType] or Map.RerollWeapons[fullType]) and instanceof(source, "HandWeapon") then
        return Convert.weapon(source)
    elseif Map.Magazines[fullType] then
        return Convert.magazine(source)
    elseif Map.Rounds[fullType] then
        return Convert.round(source)
    elseif Map.AmmoPacks[fullType] or Map.AmmoRepacks[fullType] then
        return Convert.ammoPack(source)
    elseif Map.Parts[fullType] then
        return Convert.part(source, hostHint)
    elseif Map.LooseOther[fullType] then
        return Convert.other(source)
    end
    return nil
end

function Convert.describe(item)
    local text = item:getFullType()
    if instanceof(item, "HandWeapon") then
        text = text .. string.format(" [cond %d/%d, ammo %d%s%s]", item:getCondition(), item:getConditionMax(),
            item:getCurrentAmmoCount(), item:isRoundChambered() and "+1" or "",
            item:isContainsClip() and ", mag" or "")
    elseif item:getMaxAmmo() > 0 then
        text = text .. string.format(" [ammo %d]", item:getCurrentAmmoCount())
    end
    return text
end

return Convert
