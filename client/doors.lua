-- Vanguard Business - doors registered with the game's door system; locked state comes from the server.

Doors = { hashes = {}, zones = {}, byId = {} }

local LOCKED, UNLOCKED = 1, 0

local function setState(id, locked)
    local hash = Doors.hashes[id]
    if hash then DoorSystemSetDoorState(hash, locked and LOCKED or UNLOCKED, false, true) end
end

local function clear()
    for _, hash in pairs(Doors.hashes) do
        if IsDoorRegisteredWithSystem(hash) then RemoveDoorFromSystem(hash) end
    end
    for _, handle in pairs(Doors.zones) do ClientBridge.removeZone(handle) end
    Doors.hashes, Doors.zones, Doors.byId = {}, {}, {}
end

function Doors.rebuild(list)
    clear()
    for _, door in ipairs(list) do
        local hash = GetHashKey(('vbiz_door_%d'):format(door.id))
        AddDoorToSystem(hash, door.model, door.x, door.y, door.z, false, false, false)
        Doors.hashes[door.id], Doors.byId[door.id] = hash, door
        setState(door.id, door.locked)

        -- One lock / unlock point per door, or per pair of double doors.
        if not door.pairId or door.id < door.pairId then
            local name = ('vbiz_door_%d'):format(door.id)
            Doors.zones[door.id] = ClientBridge.addZone(name, vector3(door.x, door.y, door.z), 1.2, {
                label = 'Lock / unlock', icon = 'fas fa-key',
                canInteract = function() return Client.jobs[door.businessId] ~= nil or Client.admin end,
                action = function() Client.report(Client.request('toggleDoor', { doorId = door.id })) end,
            })
        end
    end
end

RegisterNetEvent('vanguard-business:doorState', function(ids, locked)
    for _, id in ipairs(ids) do
        if Doors.byId[id] then Doors.byId[id].locked = locked end
        setState(id, locked)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clear() end
end)
