-- Vanguard Business - door locks. Two layers keep a locked door shut for everyone (staff too):
--   1. the game's door system (locked state from the server, re-applied while you are near), and
--   2. the door object itself is turned back to its closed heading and frozen while locked - this
--      also holds doors that an interior or the game's own door list won't let the door system lock.
-- Staff lock / unlock with E (or third-eye when Config.DoorsUseTarget).

Doors = { byId = {}, hashes = {}, zones = {}, adopted = {} }

local STATE_UNLOCKED, STATE_LOCKED, STATE_FORCE_LOCKED = 0, 1, 4
local OPEN_TOLERANCE = 0.02     -- open ratio below this counts as shut
local HEADING_TOLERANCE = 1.0   -- degrees off the closed heading before a locked door is turned back
local SLIDE_TOLERANCE = 0.3     -- metres a sliding door / shutter may be off its saved spot and still count as shut
local ENFORCE_INTERVAL_MS = 250
local ENFORCE_RANGE = 30.0
local TOGGLE_COOLDOWN_MS = 600

local busy = false
local frozen = {}       -- door id -> door object we froze
local lastHandle = {}   -- door id -> object handle last seen; false = seen streamed out; nil = not looked yet
local spawnHeading = {} -- door id -> heading the door object had when it streamed in (its real shut position)

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

local function doorEntity(door)
    return GetClosestObjectOfType(door.x, door.y, door.z, 1.0, door.model, false, false, false)
end

--- Remembers the door's shut heading. Building doors always stream in shut, at their original
--- rotation, so the heading of a freshly streamed-in door object is its true closed position. A door
--- that was already on screen when we started watching could be open, so it teaches nothing.
local function learn(door, entity)
    if lastHandle[door.id] == entity then return end
    if lastHandle[door.id] == false then spawnHeading[door.id] = GetEntityHeading(entity) end
    lastHandle[door.id] = entity
end

--- Where a locked door is held: its streamed-in heading, else the heading saved when it was added.
--- Unknown = nil: then the door is never frozen (the door system alone keeps it locked).
local function closedHeading(door)
    return spawnHeading[door.id] or door.heading
end

local function release(id)
    if frozen[id] and DoesEntityExist(frozen[id]) then FreezeEntityPosition(frozen[id], false) end
    frozen[id] = nil
end

--- Layer 2: turn a locked door back to shut and freeze it; let an unlocked door move freely.
local function hold(door)
    local entity = doorEntity(door)
    if entity == 0 then
        frozen[door.id], lastHandle[door.id] = nil, false
        return
    end
    learn(door, entity)
    if not door.locked then return release(door.id) end
    -- Sliding doors and roll-up shutters move instead of turning: only freeze them once the door
    -- system has brought them back to their shut position, never while still raised / open.
    if #(GetEntityCoords(entity) - vector3(door.x, door.y, door.z)) > SLIDE_TOLERANCE then
        release(door.id)
        DoorSystemSetOpenRatio(Doors.hashes[door.id], 0.0, false, false)
        return
    end

    local heading = closedHeading(door)
    if not heading then return end
    local off = math.abs((GetEntityHeading(entity) - heading + 180.0) % 360.0 - 180.0)
    if off > HEADING_TOLERANCE then SetEntityHeading(entity, heading) end
    if frozen[door.id] ~= entity then
        FreezeEntityPosition(entity, true)
        frozen[door.id] = entity
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
    if door.locked and frozen[id] then return 'locked' end
    local wanted = door.locked and STATE_LOCKED or STATE_UNLOCKED
    if DoorSystemGetDoorState(hash) ~= wanted then return 'NOT LOCKING - delete and re-add (while shut)' end
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
    for id in pairs(frozen) do release(id) end
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
            hold(Doors.byId[id])
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
                hold(door)
            elseif lastHandle[id] ~= false then
                -- out of range: once the object has streamed out, its next appearance is a fresh, shut door
                if doorEntity(door) == 0 then frozen[id], lastHandle[id] = nil, false end
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
