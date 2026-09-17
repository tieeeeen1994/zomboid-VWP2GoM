-- Offline stand-in for the parts of the Build 42 Lua API the migration touches.
-- Item scripts come from the real mod files (see run_tests.py), and the Gunworks
-- framework and Guns of Marz registries are the real files too. Method names mirror the
-- Java API; calling a method that does not exist here is an error, on purpose.

SCRIPTS = SCRIPTS or {}
AMMO_KEYS = AMMO_KEYS or {}
LOG = {}

local nextId = 1000

local function newList(values)
    local list = { values = values or {} }
    function list:size() return #self.values end
    function list:get(i) return self.values[i + 1] end
    function list:add(v) self.values[#self.values + 1] = v end
    function list:contains(v)
        for _, x in ipairs(self.values) do if x == v then return true end end
        return false
    end
    function list:remove(v)
        for i, x in ipairs(self.values) do
            if x == v then table.remove(self.values, i) return true end
        end
        return false
    end
    return list
end
NewJavaList = newList

local strict = {
    __index = function(t, k)
        error("fake API has no method " .. tostring(k) .. " on " .. tostring(rawget(t, "_class")), 2)
    end,
}

local function splitList(s, sep)
    local out = {}
    if not s then return out end
    for part in string.gmatch(s, "[^" .. sep .. "]+") do
        out[#out + 1] = (string.gsub(part, "^%s*(.-)%s*$", "%1"))
    end
    return out
end

local function bool(v, default)
    if v == nil then return default end
    return string.lower(v) == "true"
end

local classOf = {
    ["base:weapon"] = "HandWeapon",
    ["base:weaponpart"] = "WeaponPart",
    ["base:container"] = "InventoryContainer",
    ["base:normal"] = "ComboItem",
    ["base:drainable"] = "DrainableComboItem",
}

local isA = {
    HandWeapon = { HandWeapon = true, InventoryItem = true },
    WeaponPart = { WeaponPart = true, InventoryItem = true },
    InventoryContainer = { InventoryContainer = true, InventoryItem = true },
    ComboItem = { ComboItem = true, InventoryItem = true },
    DrainableComboItem = { DrainableComboItem = true, InventoryItem = true },
}

function instanceof(obj, cls)
    if type(obj) ~= "table" then return false end
    local c = rawget(obj, "_class")
    if not c then return false end
    if isA[c] then return isA[c][cls] == true end
    if c == cls then return true end
    local parents = rawget(obj, "_isa")
    return parents ~= nil and parents[cls] == true
end

local function resolveFunction(name)
    local value = _G
    for part in string.gmatch(name, "[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return type(value) == "function" and value or nil
end

local function ammoTypeObject(id)
    if not id then return nil end
    local key = AMMO_KEYS[string.lower(id)]
    if not key then return nil end
    return setmetatable({ _class = "AmmoType", getItemKey = function() return key end }, strict)
end

local function makeItem(fullType)
    local script = SCRIPTS[fullType]
    if not script then return nil end
    local class = classOf[script.itemtype or "base:normal"] or "ComboItem"
    local item = { _class = class }
    local conditionMax = tonumber(script.conditionmax or "10")
    local state = {
        id = nextId,
        condition = conditionMax,
        conditionMax = conditionMax,
        repaired = 0,
        name = script.displayname or fullType,
        customName = false,
        favorite = false,
        modData = nil,
        attachedSlot = -1,
        attachedSlotType = nil,
        attachedToModel = nil,
        worldZ = 0,
        currentAmmo = 0,
        maxAmmo = tonumber(script.maxammo or "0"),
        ammoType = ammoTypeObject(script.ammotype),
        uses = 0,
        maxUses = tonumber(script.maxuses or "0"),
        activated = false,
        container = nil,
        worldItem = nil,
    }
    nextId = nextId + 1

    function item:getFullType() return fullType end
    function item:getType() return (string.gsub(fullType, "^[^%.]+%.", "")) end
    function item:getID() return state.id end
    function item:getCondition() return state.condition end
    function item:getConditionMax() return state.conditionMax end
    function item:setCondition(v, sound)
        assert(sound ~= nil, "use setCondition(int, boolean)")
        state.condition = math.max(0, math.min(state.conditionMax, v))
    end
    function item:getHaveBeenRepaired() return state.repaired end
    function item:setHaveBeenRepaired(v) state.repaired = v end
    function item:isCustomName() return state.customName end
    function item:setCustomName(v) state.customName = v end
    function item:getName() return state.name end
    function item:setName(v) state.name = v end
    function item:isFavorite() return state.favorite end
    function item:setFavorite(v) state.favorite = v end
    function item:getAttachedSlot() return state.attachedSlot end
    function item:setAttachedSlot(v) state.attachedSlot = v end
    function item:getAttachedSlotType() return state.attachedSlotType end
    function item:setAttachedSlotType(v) state.attachedSlotType = v end
    function item:getAttachedToModel() return state.attachedToModel end
    function item:setAttachedToModel(v) state.attachedToModel = v end
    function item:getWorldZRotation() return state.worldZ end
    function item:setWorldZRotation(v) state.worldZ = v end
    function item:hasModData() return state.modData ~= nil end
    function item:getModData()
        state.modData = state.modData or {}
        return state.modData
    end
    function item:getCurrentAmmoCount() return state.currentAmmo end
    function item:setCurrentAmmoCount(v) state.currentAmmo = v end
    function item:getMaxAmmo() return state.maxAmmo end
    function item:setMaxAmmo(v) state.maxAmmo = v end
    function item:getAmmoType() return state.ammoType end
    function item:getAttachmentType() return script.attachmenttype end
    function item:getMaxUses() return state.maxUses end
    function item:getCurrentUses() return state.uses end
    function item:setCurrentUses(v) state.uses = v end
    function item:isActivated() return state.activated end
    function item:setActivated(v) state.activated = v end
    function item:getContainer() return state.container end
    function item:setContainer(c) state.container = c end
    function item:getWorldItem() return state.worldItem end
    function item:setWorldItem(w) state.worldItem = w end
    function item:copyConditionStatesFrom(other)
        state.condition = math.min(state.conditionMax, other:getCondition())
        state.repaired = other:getHaveBeenRepaired()
        state.favorite = other:isFavorite()
    end

    if class == "WeaponPart" then
        local mountOn = newList(splitList(script.mounton, ";"))
        function item:getPartType() return script.parttype end
        function item:getMountOn() return mountOn end
    end

    if class == "HandWeapon" then
        local parts = newList()
        local magazineType = script.magazinetype
        local haveChamber = bool(script.havechamber, true)
        local fireModes = splitList(script.firemodepossibilities, "/")
        state.fireMode = script.firemode
        state.chambered = false
        state.jammed = false
        state.containsClip = false
        state.spentCount = 0
        state.spentChambered = false
        state.blood = 0

        function item:getAllWeaponParts() return parts end
        function item:getWeaponPart(partType)
            for _, p in ipairs(parts.values) do
                if p:getPartType() == partType then return p end
            end
            return nil
        end
        function item:attachWeaponPart(part, doChange)
            assert(instanceof(part, "WeaponPart"), "attachWeaponPart needs a WeaponPart")
            assert(doChange ~= nil, "use attachWeaponPart(part, boolean)")
            local existing = self:getWeaponPart(part:getPartType())
            if existing then parts:remove(existing) end
            parts:add(part)
        end
        function item:detachWeaponPart(part)
            if type(part) == "string" then part = self:getWeaponPart(part) end
            if part then parts:remove(part) end
        end
        function item:clearWeaponPart(part) parts:remove(part) end
        function item:getMagazineType() return magazineType end
        function item:setMagazineType(v) magazineType = v end
        function item:haveChamber() return haveChamber end
        function item:isRoundChambered() return state.chambered end
        function item:setRoundChambered(v) state.chambered = haveChamber and v end
        function item:isJammed() return state.jammed end
        function item:setJammed(v) state.jammed = v end
        function item:isContainsClip() return state.containsClip end
        function item:setContainsClip(v)
            state.containsClip = (magazineType ~= nil and magazineType ~= "") and v
        end
        function item:getSpentRoundCount() return state.spentCount end
        function item:setSpentRoundCount(v) state.spentCount = v end
        function item:isSpentRoundChambered() return state.spentChambered end
        function item:setSpentRoundChambered(v) state.spentChambered = v end
        function item:getFireMode() return state.fireMode end
        function item:setFireMode(v) state.fireMode = v end
        function item:getFireModePossibilities()
            if #fireModes == 0 then return nil end
            return newList(fireModes)
        end
        function item:getBloodLevel() return state.blood end
        function item:setBloodLevel(v) state.blood = v end
        function item:isRanged() return bool(script.ranged, false) end
        function item:canAttachWeaponPart(part) return true end
    end

    if class == "InventoryContainer" then
        local inner = NewContainer("bag", item)
        function item:getInventory() return inner end
    end

    setmetatable(item, strict)
    if script.oncreate then
        local fn = resolveFunction(script.oncreate)
        if fn then fn(item) end
    end
    return item
end

function instanceItem(fullType)
    return makeItem(fullType)
end

function NewContainer(kind, parent)
    local c = { _class = "ItemContainer" }
    local items = newList()
    function c:getItems() return items end
    function c:AddItem(item)
        if items:contains(item) then return item end
        local old = item:getContainer()
        if old and old ~= c then old:DoRemoveItem(item) end
        items:add(item)
        item:setContainer(c)
        return item
    end
    function c:DoRemoveItem(item)
        items:remove(item)
        if item:getContainer() == c then item:setContainer(nil) end
    end
    function c:getParent() return parent end
    function c:getCharacter()
        if parent and instanceof(parent, "IsoGameCharacter") then return parent end
        if parent and instanceof(parent, "InventoryItem") and parent:getContainer() then
            return parent:getContainer():getCharacter()
        end
        return nil
    end
    function c:contains(item) return items:contains(item) end
    function c:getContainingItem()
        if parent and instanceof(parent, "InventoryItem") then return parent end
        return nil
    end
    function c:getType() return kind end
    function c:getSourceGrid() return nil end
    function c:setDirty() end
    function c:setDrawDirty() end
    return setmetatable(c, strict)
end

function NewCharacter()
    local ch = { _class = "IsoPlayer", _isa = { IsoPlayer = true, IsoGameCharacter = true } }
    local inv = NewContainer("none", ch)
    local attached = {}
    local primary, secondary
    function ch:getInventory() return inv end
    function ch:getPrimaryHandItem() return primary end
    function ch:getSecondaryHandItem() return secondary end
    function ch:setPrimaryHandItem(i) primary = i end
    function ch:setSecondaryHandItem(i) secondary = i end
    function ch:getObjectName() return "Player" end
    function ch:getSquare() return nil end
    function ch:isLocalPlayer() return true end
    function ch:getPlayerNum() return 0 end
    local attachedApi = {}
    function attachedApi:getLocation(item)
        for loc, i in pairs(attached) do if i == item then return loc end end
        return nil
    end
    function attachedApi:remove(item)
        for loc, i in pairs(attached) do if i == item then attached[loc] = nil end end
    end
    function attachedApi:setItem(loc, item) attached[loc] = item end
    function ch:getAttachedItems() return setmetatable(attachedApi, strict) end
    function ch:setAttachedItem(loc, item) attached[loc] = item end
    function ch:removeAttachedItem(item) attachedApi:remove(item) end
    function ch:attachedAt(loc) return attached[loc] end
    return setmetatable(ch, strict)
end

local scriptManager = setmetatable({
    getItem = function(_, fullType) return SCRIPTS[fullType] end,
}, strict)
function getScriptManager() return scriptManager end

function isClient() return false end
SERVER_MODE = false
SENT = {}
function isServer() return SERVER_MODE end
local function record(name)
    return function(...) SENT[#SENT + 1] = { name = name, args = { ... } } end
end
sendReplaceItemInContainer = record("replace")
sendAddItemToContainer = record("add")
sendRemoveItemFromContainer = record("remove")
sendEquip = record("equip")
sendAttachedItem = record("attached")
sendServerCommand = record("serverCommand")
function newrandom()
    return { random = function(_, a, b) if b then return a end return 1 end }
end
function getFileWriter()
    return {
        writeln = function(_, line) LOG[#LOG + 1] = line end,
        close = function() end,
    }
end
function getPlayerHotbar() return nil end
function getSpecificPlayer() return nil end
function getNumActivePlayers() return 0 end

Events = setmetatable({}, {
    __index = function(t, name)
        local e = { Add = function() end, Remove = function() end }
        rawset(t, name, e)
        return e
    end,
})

local realPrint = print
function print(...)
    LOG[#LOG + 1] = table.concat({ ... }, " ")
end
PrintToConsole = realPrint

AmmoType = {
    register = function(id, key)
        return { id = id, getItemKey = function() return key end }
    end,
}
ItemTag = { register = function(id) return id end }
