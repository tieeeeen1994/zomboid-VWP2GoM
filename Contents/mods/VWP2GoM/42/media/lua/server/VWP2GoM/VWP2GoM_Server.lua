if isClient() then
    return
end

local Map = require("VWP2GoM/VWP2GoM_Map")
local Convert = require("VWP2GoM/VWP2GoM_Convert")

local Migrate = {}
VWP2GoM = Migrate

Migrate.converted = 0
Migrate.failed = 0

local function ready()
    if Migrate.isReady ~= nil then
        return Migrate.isReady
    end
    Migrate.isReady = getScriptManager():getItem("MarzGuns.M92FS") ~= nil
        and getScriptManager():getItem("SWMG.9x19_Bullet") ~= nil
    if not Migrate.isReady then
        Convert.log("Guns of Marz or Gunworks is not loaded; nothing will be converted.")
    end
    return Migrate.isReady
end

local function describeContainer(container)
    local where = tostring(container:getType())
    local parent = container:getParent()
    local item = container:getContainingItem()
    if item then
        where = where .. " in " .. item:getFullType()
        local outer = item:getContainer()
        if outer then
            return where .. " / " .. describeContainer(outer)
        end
        return where
    end
    if parent then
        where = where .. " on " .. tostring(parent:getObjectName())
        local square = parent:getSquare()
        if square then
            where = string.format("%s at %d,%d,%d", where, square:getX(), square:getY(), square:getZ())
        end
    end
    return where
end

local function report(source, target, extras, where)
    local parts = {}
    for i = 1, #extras do
        parts[#parts + 1] = extras[i]:getFullType()
    end
    Convert.log(string.format("%s -> %s%s | %s", Convert.describe(source),
        target and Convert.describe(target) or "(nothing)",
        #parts > 0 and (" + " .. table.concat(parts, ", ")) or "", where))
end

local function attachedLocation(owner, item)
    if not (instanceof(owner, "IsoGameCharacter") or instanceof(owner, "IsoDeadBody")) then
        return nil
    end
    local attached = owner:getAttachedItems()
    return attached and attached:getLocation(item) or nil
end

local pendingEquips = {}
local EQUIP_DELAY_TICKS = 15

local function queueEquip(character, item, primary, secondary)
    pendingEquips[#pendingEquips + 1] = {
        character = character,
        item = item,
        primary = primary,
        secondary = secondary,
        ticks = EQUIP_DELAY_TICKS,
    }
end

local function processEquips()
    if #pendingEquips == 0 then
        return
    end
    local remaining = {}
    for _, entry in ipairs(pendingEquips) do
        entry.ticks = entry.ticks - 1
        if entry.ticks > 0 then
            remaining[#remaining + 1] = entry
        elseif entry.character:getInventory():contains(entry.item) then
            if entry.primary then
                entry.character:setPrimaryHandItem(entry.item)
            end
            if entry.secondary then
                entry.character:setSecondaryHandItem(entry.item)
            end
            sendEquip(entry.character)
        end
    end
    pendingEquips = remaining
end

local function refreshLocalHotbar(character)
    if isServer() or not instanceof(character, "IsoPlayer") or not character:isLocalPlayer() then
        return
    end
    if getPlayerHotbar then
        local hotbar = getPlayerHotbar(character:getPlayerNum())
        if hotbar then
            hotbar:refresh()
        end
    end
end

function Migrate.replaceInContainer(container, source, target, extras)
    local owner = container:getParent()
    local character = instanceof(owner, "IsoGameCharacter") and owner or nil
    local primary = character and character:getPrimaryHandItem() == source
    local secondary = character and character:getSecondaryHandItem() == source
    local location = attachedLocation(owner, source)

    local added
    if target then
        added = container:AddItem(target)
        if not added then
            error("container refused " .. target:getFullType())
        end
    end
    for i = 1, #extras do
        local extra = container:AddItem(extras[i])
        if extra and isServer() then
            sendAddItemToContainer(container, extra)
        end
    end

    if location then
        if character then
            character:removeAttachedItem(source)
        else
            owner:getAttachedItems():remove(source)
        end
    end
    container:DoRemoveItem(source)
    if isServer() then
        if added then
            sendReplaceItemInContainer(container, source, added)
        else
            sendRemoveItemFromContainer(container, source)
        end
    end

    if added and character and (primary or secondary) then
        if isServer() and instanceof(character, "IsoPlayer") then
            queueEquip(character, added, primary, secondary)
        else
            if primary then
                character:setPrimaryHandItem(added)
            end
            if secondary then
                character:setSecondaryHandItem(added)
            end
        end
    end
    if added and location then
        if character then
            character:setAttachedItem(location, added)
            if isServer() then
                sendAttachedItem(character, location, added)
            end
        else
            owner:getAttachedItems():setItem(location, added)
        end
    elseif location and not added then
        source:setAttachedSlot(-1)
    end

    container:setDrawDirty(true)
    container:setDirty(true)
    if character then
        refreshLocalHotbar(character)
    end
end

function Migrate.replaceOnFloor(worldObject, source, target, extras)
    local square = worldObject:getSquare()
    local x, y, z = worldObject:getWorldPosX(), worldObject:getWorldPosY(), worldObject:getWorldPosZ()
    local offX = x - square:getX()
    local offY = y - square:getY()
    local offZ = z - square:getZ()
    for i = 1, #extras do
        square:AddWorldInventoryItem(extras[i], offX, offY, offZ, true)
    end
    if target then
        worldObject:swapItem(target)
    else
        square:transmitRemoveItemFromSquare(worldObject)
        worldObject:removeFromWorld()
        worldObject:removeFromSquare()
    end
end

local function convert(source, hostHint)
    local ok, target, extras = pcall(Convert.item, source, hostHint)
    if not ok then
        Migrate.failed = Migrate.failed + 1
        Convert.log("FAILED, left unchanged: " .. tostring(source:getFullType()) .. " (" .. tostring(target) .. ")")
        return nil
    end
    if not target and (not extras or #extras == 0) then
        Migrate.failed = Migrate.failed + 1
        Convert.log("FAILED, left unchanged: " .. tostring(source:getFullType()) .. " (no target item)")
        return nil
    end
    return target, extras or {}
end

function Migrate.scanContainer(container, depth, skip)
    if not container or not ready() then
        return 0
    end
    local changed = 0
    depth = depth or 0
    local items = {}
    local list = container:getItems()
    for i = 0, list:size() - 1 do
        items[#items + 1] = list:get(i)
    end
    for _, item in ipairs(items) do
        if skip and skip[item] then
            item = nil
        elseif Map.IsSource(item:getFullType()) then
            local target, extras = convert(item)
            if target or (extras and #extras > 0) then
                local ok, err = pcall(Migrate.replaceInContainer, container, item, target, extras)
                if ok then
                    changed = changed + 1
                    Migrate.converted = Migrate.converted + 1
                    pcall(function()
                        report(item, target, extras, describeContainer(container))
                    end)
                else
                    Migrate.failed = Migrate.failed + 1
                    Convert.log("FAILED while placing " .. item:getFullType() .. ": " .. tostring(err))
                end
            end
        elseif instanceof(item, "InventoryContainer") and depth < 8 then
            local inner = Migrate.scanContainer(item:getInventory(), depth + 1, skip)
            if inner > 0 then
                changed = changed + inner
                if isServer() and not container:getCharacter() then
                    sendRemoveItemFromContainer(container, item)
                    sendAddItemToContainer(container, item)
                end
            end
        end
    end
    return changed
end

function Migrate.scanSquare(square)
    if not square or not ready() then
        return
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object then
            for c = 0, object:getContainerCount() - 1 do
                Migrate.scanContainer(object:getContainerByIndex(c))
            end
        end
    end

    local worldObjects = {}
    local list = square:getWorldObjects()
    for i = 0, list:size() - 1 do
        worldObjects[#worldObjects + 1] = list:get(i)
    end
    for _, worldObject in ipairs(worldObjects) do
        local item = worldObject:getItem()
        if item and Map.IsSource(item:getFullType()) then
            local target, extras = convert(item)
            if target or (extras and #extras > 0) then
                local ok, err = pcall(Migrate.replaceOnFloor, worldObject, item, target, extras)
                if ok then
                    Migrate.converted = Migrate.converted + 1
                    pcall(report, item, target, extras,
                        string.format("floor at %d,%d,%d", square:getX(), square:getY(), square:getZ()))
                else
                    Migrate.failed = Migrate.failed + 1
                    Convert.log("FAILED while placing " .. item:getFullType() .. ": " .. tostring(err))
                end
            end
        elseif item and instanceof(item, "InventoryContainer") then
            Migrate.scanContainer(item:getInventory(), 1)
        end
    end

    local moving = square:getStaticMovingObjects()
    for i = 0, moving:size() - 1 do
        local body = moving:get(i)
        if instanceof(body, "IsoDeadBody") then
            Migrate.scanContainer(body:getContainer())
        end
    end
end

function Migrate.scanChunk(chunk)
    if not chunk or not ready() then
        return
    end
    for z = chunk:getMinLevel(), chunk:getMaxLevel() do
        for x = 0, 7 do
            for y = 0, 7 do
                Migrate.scanSquare(chunk:getGridSquare(x, y, z))
            end
        end
    end
end

function Migrate.scanVehicle(vehicle)
    if not vehicle or not ready() then
        return
    end
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if part and part:getItemContainer() then
            Migrate.scanContainer(part:getItemContainer())
        end
    end
end

function Migrate.scanPlayer(player)
    if not player or not ready() then
        return
    end
    local before = Migrate.converted
    Migrate.scanContainer(player:getInventory())
    if isServer() and Migrate.converted > before then
        sendServerCommand(player, "VWP2GoM", "refresh", {})
    end
end

local function onClientCommand(module, command, player)
    if module == "VWP2GoM" and command == "scanMe" then
        Migrate.scanPlayer(player)
    end
end

local function scanPlayers()
    if isServer() then
        local players = getOnlinePlayers()
        if players then
            for i = 0, players:size() - 1 do
                Migrate.scanPlayer(players:get(i))
            end
        end
    else
        for i = 0, getNumActivePlayers() - 1 do
            Migrate.scanPlayer(getSpecificPlayer(i))
        end
    end
end

local pendingGoM = {}
local freshLoot = {}

local function wrapGoMReplacement()
    if not MarzGuns_OnCreate or not MarzGuns_OnCreate.VanillaReplace or MarzGuns_OnCreate.VWP2GoMWrapped then
        return
    end
    local original = MarzGuns_OnCreate.VanillaReplace
    MarzGuns_OnCreate.VWP2GoMOriginalVanillaReplace = original
    MarzGuns_OnCreate.VanillaReplace = function(item)
        if item then
            pendingGoM[item] = true
        end
    end
    MarzGuns_OnCreate.VWP2GoMWrapped = true
end

local function releasePending()
    if next(pendingGoM) == nil then
        return
    end
    local original = MarzGuns_OnCreate and MarzGuns_OnCreate.VWP2GoMOriginalVanillaReplace
    for item in pairs(pendingGoM) do
        if freshLoot[item] and original then
            original(item)
        end
    end
    pendingGoM = {}
    freshLoot = {}
end

local function onFillContainer(_, _, container)
    if not container or not ready() then
        return
    end
    local list = container:getItems()
    for i = 0, list:size() - 1 do
        local item = list:get(i)
        if pendingGoM[item] then
            freshLoot[item] = true
        end
    end
    Migrate.scanContainer(container, 0, freshLoot)
end

wrapGoMReplacement()

Events.OnInitGlobalModData.Add(wrapGoMReplacement)
Events.OnTick.Add(releasePending)
Events.OnTick.Add(processEquips)
Events.LoadChunk.Add(Migrate.scanChunk)
Events.OnSpawnVehicleEnd.Add(Migrate.scanVehicle)
Events.OnFillContainer.Add(onFillContainer)
Events.OnCreatePlayer.Add(function(_, player)
    Migrate.scanPlayer(player)
end)
Events.OnGameStart.Add(scanPlayers)
Events.EveryOneMinute.Add(scanPlayers)
Events.OnClientCommand.Add(onClientCommand)

return Migrate
