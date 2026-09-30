-- Vanguard Business - door locks. Doors are registered with the game's door system; the locked
-- state comes from the server and is re-applied while you are near, so nothing can leave a
-- locked door swinging. Staff lock / unlock with E (or third-eye when Config.DoorsUseTarget).

Doors = { byId = {}, hashes = {}, zones = {}, adopted = {} }

local STATE_UNLOCKED, STATE_LOCKED, STATE_FORCE_LOCKED = 0, 1, 4
local OPEN_TOLERANCE = 0.02 -- open ratio below this counts as shut
local ENFORCE_INTERVAL_MS = 1000
local ENFORCE_RANGE = 30.0
local TOGGLE_COOLDOWN_MS = 600

local busy = false

local function hasKey(door)
    return Client.jobs[door.businessId] ~= nil or Client.admin
end

--- Applies the state the way ox_doorlock does: a forced lock first resets whatever the game or an
--- interior had set for this door, then the real state.
local function applyState(id)
    local door, hash = Doors.byId[id], Doors.hashes[id]
    if not door or not hash then return end
    DoorSystemSetDoorState(hash, STATE_FORCE_LOCKED, false, false)
    DoorSystemSetDoorState(hash, door.locked and STATE_LOCKED or STATE_UNLOCKED, false, false)
    -- a door that was open when it got locked would otherwise stay open until someone shut it
    if door.locked and math.abs(DoorSystemGetOpenRatio(hash)) > OPEN_TOLERANCE then
        DoorSystemSetOpenRatio(hash, 0.0, false, false)
    end
end

--- For placement mode: 'locked' / 'open', or a problem to fix ('no door here', 'not locking').
function Doors.status(id)
    local door, hash = Doors.byId[id], Doors.hashes[id]
    if not door or not hash then return 'not loaded' end
    -- far-away doors aren't streamed in, so they can't be checked from here
    if #(GetEntityCoords(PlayerPedId()) - vector3(door.x, door.y, door.z)) > ENFORCE_RANGE then
        return door.locked and 'locked' or 'open'
    end
    if GetClosestObjectOfType(door.x, door.y, door.z, 1.0, door.model, false, false, false) == 0 then
        return 'NO DOOR HERE - delete and re-add'
    end
    local wanted = door.locked and STATE_LOCKED or STATE_UNLOCKED
    if DoorSystemGetDoorState(hash) ~= wanted then return 'NOT LOCKING - delete and re-add' end
    return door.locked and 'locked' or 'open'
end

--- Where the prompt goes: the middle of the door (or between both halves of a double door).
local function doorCenter(door)
    local entity = GetClosestObjectOfType(door.x, door.y, door.z, 1.0, door.model, false, false, false)
    if entity == 0 then return vector3(door.x, door.y, door.z + 1.0) end
    local min, max = GetModelDimensions(door.model)
    return GetOffsetFromEntityInWorldCoords(entity, (min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2)
end

local function groupCenter(door)
    local center = doorCenter(door)
    local partner = door.pairId and Doors.byId[door.pairId]
    if partner then center = (center + doorCenter(partner)) / 2 end
    return center
end

local function toggle(door)
    if busy then return end
    busy = true
    Client.report(Client.request('toggleDoor', { doorId = door.id }))
    SetTimeout(TOGGLE_COOLDOWN_MS, function() busy = false end)
end

local function clear()
    for id, hash in pairs(Doors.hashes) do
        if Doors.adopted[id] then
            DoorSystemSetDoorState(hash, STATE_UNLOCKED, false, false) -- the game's own door: just unlock it
        elseif IsDoorRegisteredWithSystem(hash) then
            RemoveDoorFromSystem(hash)
        end
    end
    for _, handle in pairs(Doors.zones) do ClientBridge.removeZone(handle) end
    Doors.byId, Doors.hashes, Doors.zones, Doors.adopted = {}, {}, {}, {}
end

function Doors.rebuild(list)
    clear()
    for _, door in ipairs(list) do
        -- Many interior doors are already in the game's door system under their own id; a second
        -- registration of the same door is ignored, so control the existing entry instead.
        local found, existing = DoorSystemFindExistingDoor(door.x, door.y, door.z, door.model)
        local hash
        if found and existing and existing ~= 0 then
            hash = existing
            Doors.adopted[door.id] = true
        else
            hash = GetHashKey(('vbiz_door_%d'):format(door.id))
            AddDoorToSystem(hash, door.model, door.x, door.y, door.z, false, false, false)
        end
        Doors.byId[door.id], Doors.hashes[door.id] = door, hash
        applyState(door.id)
    end

    if not Config.DoorsUseTarget then return end
    for _, door in pairs(Doors.byId) do
        if not door.pairId or door.id < door.pairId then
            Doors.zones[door.id] = ClientBridge.addZone(('vbiz_door_%d'):format(door.id), vector3(door.x, door.y, door.z), 1.2, {
                label = 'Lock / unlock', icon = 'fas fa-key',
                canInteract = function() return hasKey(door) end,
                action = function() toggle(door) end,
            })
        end
    end
end

RegisterNetEvent('vanguard-business:doorState', function(ids, locked)
    for _, id in ipairs(ids) do
        if Doors.byId[id] then
            Doors.byId[id].locked = locked
            applyState(id)
        end
    end
end)

-- Keep nearby doors in the state the server says (interiors and other scripts can reset them).
CreateThread(function()
    while true do
        Wait(ENFORCE_INTERVAL_MS)
        local position = GetEntityCoords(PlayerPedId())
        for id, door in pairs(Doors.byId) do
            if #(position - vector3(door.x, door.y, door.z)) < ENFORCE_RANGE then
                local hash = Doors.hashes[id]
                local wanted = door.locked and STATE_LOCKED or STATE_UNLOCKED
                local swungOpen = door.locked and math.abs(DoorSystemGetOpenRatio(hash)) > OPEN_TOLERANCE
                if DoorSystemGetDoorState(hash) ~= wanted or swungOpen then applyState(id) end
            end
        end
    end
end)

-- E prompt: staff see "[E] Lock" / "[E] Unlock"; everyone else sees "Locked" on a locked door.
CreateThread(function()
    while true do
        local sleep = 500
        if not Config.DoorsUseTarget and next(Doors.byId) then
            local ped = PlayerPedId()
            local position = GetEntityCoords(ped)
            local nearest, nearestCenter, nearestDistance = nil, nil, Config.InteractDistance
            for _, door in pairs(Doors.byId) do
                -- one prompt per door, or per pair of double doors
                if (not door.pairId or door.id < door.pairId or not Doors.byId[door.pairId])
                    and #(position - vector3(door.x, door.y, door.z)) < Config.InteractDistance + 2.0 then
                    local center = groupCenter(door)
                    local distance = #(position - center)
                    if distance < nearestDistance then nearest, nearestCenter, nearestDistance = door, center, distance end
                end
            end

            if nearest and not IsPedInAnyVehicle(ped, false) then
                sleep = 0
                if hasKey(nearest) then
                    ClientBridge.drawText3d(nearestCenter, nearest.locked and '[E] Unlock' or '[E] Lock')
                    if IsControlJustReleased(0, Config.DoorKey) then toggle(nearest) end
                elseif nearest.locked then
                    ClientBridge.drawText3d(nearestCenter, 'Locked')
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clear() end
end)
