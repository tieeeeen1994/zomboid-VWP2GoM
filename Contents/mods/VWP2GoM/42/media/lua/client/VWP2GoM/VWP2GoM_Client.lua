if not isClient() then
    return
end

local MODULE = "VWP2GoM"

local function requestScan()
    local player = getPlayer()
    if player then
        sendClientCommand(player, MODULE, "scanMe", {})
    end
end

local function onServerCommand(module, command)
    if module ~= MODULE or command ~= "refresh" then
        return
    end
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then
            local hotbar = getPlayerHotbar(player:getPlayerNum())
            if hotbar then
                hotbar:refresh()
            end
            player:resetEquippedHandsModels()
        end
    end
    ISInventoryPage.renderDirty = true
end

Events.OnGameStart.Add(requestScan)
Events.OnServerCommand.Add(onServerCommand)
