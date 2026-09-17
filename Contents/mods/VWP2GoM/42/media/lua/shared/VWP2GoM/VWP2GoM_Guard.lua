if isClient() then
    return
end

local Convert = require("VWP2GoM/VWP2GoM_Convert")

local function onInitWorld()
    local world = getWorld()
    local name = world and world:getWorld() or "?"
    Convert.resetLog(string.format("VWP2GoM log for world \"%s\" (%s)", tostring(name),
        isServer() and "dedicated server" or "single player"))

    if getDebug() then
        local message = "Debug mode is on. VWP2GoM closed the game before the world loaded, so nothing was "
            .. "loaded or saved. In debug mode the game can reject saved items it would otherwise keep. "
            .. "Restart without -debug to load this world."
        Convert.log("STOPPED: " .. message)
        if getPlayer() then
            getCore():quitToDesktop()
        else
            getCore():quit()
        end
    end
end

Events.OnInitWorld.Add(onInitWorld)
