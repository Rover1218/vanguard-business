-- Vanguard Business - station interactions and map icons.

World = { zones = {}, blips = {} }

local ICONS = {
    fridge = 'fas fa-snowflake', register = 'fas fa-cash-register', boss = 'fas fa-briefcase',
    clockin = 'fas fa-clock', cooking = 'fas fa-fire-burner',
}

local function isStaff(businessId)
    return Client.jobs[businessId] ~= nil
end

--- Stations that only need a server answer (clock-in, fridge).
local function simple(action, station)
    Client.report(Client.request(action, { stationId = station.id }))
end

local function optionFor(station)
    local definition = StationKinds[station.kind]
    if not definition then return nil end

    local option = { canInteract = function() return isStaff(station.businessId) end }
    if definition.cooking then
        option.label, option.icon = ('Use %s'):format(definition.label:lower()), ICONS.cooking
        option.action = function() Cooking.open(station) end
    elseif station.kind == 'fridge' then
        option.label, option.icon = 'Open fridge', ICONS.fridge
        option.action = function() simple('openFridge', station) end
    elseif station.kind == 'register' then
        option.label, option.icon = 'Cash register', ICONS.register
        option.action = function() Panels.openRegister(station) end
    elseif station.kind == 'boss' then
        option.label, option.icon = 'Boss desk', ICONS.boss
        option.action = function() Panels.openBoss(station) end
    elseif station.kind == 'clockin' then
        option.label, option.icon = 'Clock in / out', ICONS.clockin
        option.action = function() simple('clock', station) end
    else
        return nil
    end
    return option
end

local function clear()
    for _, handle in pairs(World.zones) do ClientBridge.removeZone(handle) end
    for _, blip in ipairs(World.blips) do RemoveBlip(blip) end
    World.zones, World.blips = {}, {}
end

function World.rebuild()
    clear()
    for _, station in ipairs(Client.world.stations or {}) do
        local option = optionFor(station)
        if option then
            local name = ('vbiz_station_%d'):format(station.id)
            World.zones[name] = ClientBridge.addZone(name, vector3(station.x, station.y, station.z), 0.9, option)
        end
    end
    for _, info in ipairs(Client.world.blips or {}) do
        local blip = AddBlipForCoord(info.x, info.y, info.z)
        SetBlipSprite(blip, info.sprite)
        SetBlipColour(blip, info.colour)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(info.name)
        EndTextCommandSetBlipName(blip)
        World.blips[#World.blips + 1] = blip
    end
    Doors.rebuild(Client.world.doors or {})
end

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clear() end
end)
