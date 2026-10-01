-- Vanguard Business - placement mode: aim, click to place stations, doors and the map icon.

Placement = { active = false }

local REACH = 20.0
local PAIR_WINDOW_MS = 60000 -- Shift + click a second door within this time to link a double door
local REMOVE_RADIUS = 1.5
local ROTATE_STEP = 15.0

local KEY = {
    place = 24,     -- left mouse
    wheelDown = 14, wheelUp = 15,
    previous = 174, -- arrow left
    next = 175,     -- arrow right
    remove = 178,   -- Delete
    exit = 194,     -- Backspace
    pause = 200,    -- Esc
    link = 21,      -- Shift (hold while clicking the second half of a double door)
}

local function direction(rotation)
    local z, x = math.rad(rotation.z), math.rad(rotation.x)
    local horizontal = math.abs(math.cos(x))
    return vector3(-math.sin(z) * horizontal, math.cos(z) * horizontal, math.sin(x))
end

--- What the camera is looking at: hit (bool), position, entity.
local function aim()
    local from = GetGameplayCamCoord()
    local to = from + direction(GetGameplayCamRot(2)) * REACH
    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 | 16, PlayerPedId(), 7)
    local _, hit, position, _, entity = GetShapeTestResult(handle)
    return hit == 1, position, entity
end

local function kind()
    return Placement.data.kinds[Placement.index]
end

local function updateBar()
    SendNUIMessage({
        action = 'placement', business = Placement.data.business.name, kind = kind().label,
        index = Placement.index, total = #Placement.data.kinds,
        pairing = Placement.lastDoor ~= nil and kind().id == 'door',
    })
end

local function mine(list)
    local result = {}
    for _, entry in ipairs(list or {}) do
        if entry.businessId == Placement.data.business.id then result[#result + 1] = entry end
    end
    return result
end

local function drawExisting()
    for _, station in ipairs(mine(Client.world.stations)) do
        DrawMarker(28, station.x, station.y, station.z, 0, 0, 0, 0, 0, 0, 0.15, 0.15, 0.15, 245, 158, 11, 160, false, false, 2, false, nil, nil, false)
        ClientBridge.drawText3d(vector3(station.x, station.y, station.z + 0.25), StationKinds[station.kind] and StationKinds[station.kind].label or station.kind)
    end
    for _, door in ipairs(mine(Client.world.doors)) do
        local label = door.pairId and 'Double door' or 'Door'
        ClientBridge.drawText3d(vector3(door.x, door.y, door.z + 1.0), ('%s: %s'):format(label, Doors.status(door.id)))
    end
end

local function place(position)
    local current = kind().id
    local result = Client.request('placeStation', {
        businessId = Placement.data.business.id, kind = current,
        coords = { x = position.x, y = position.y, z = position.z }, heading = Placement.heading,
    })
    Client.report(result)
end

local function addDoor(entity)
    local coords = GetEntityCoords(entity)
    -- Shift + click links this door to the previous one (double doors).
    local pairWith = nil
    if Placement.lastDoor and IsControlPressed(0, KEY.link) and GetGameTimer() - Placement.lastDoor.time < PAIR_WINDOW_MS then
        pairWith = Placement.lastDoor.id
    end
    local result = Client.request('addDoor', {
        businessId = Placement.data.business.id, model = GetEntityModel(entity),
        coords = { x = coords.x, y = coords.y, z = coords.z }, pairWith = pairWith,
        heading = GetEntityHeading(entity), -- add doors while they are shut: this is where a locked door is held
    })
    Client.report(result)
    if result.ok then
        Placement.lastDoor = (not pairWith and result.data) and { id = result.data.id, time = GetGameTimer() } or nil
        updateBar()
    end
end

local function removeNear(position)
    if kind().id == 'blip' then return Client.report(Client.request('removeBlip', { businessId = Placement.data.business.id })) end
    local best, bestDistance, action = nil, REMOVE_RADIUS, nil
    for _, station in ipairs(mine(Client.world.stations)) do
        local distance = #(position - vector3(station.x, station.y, station.z))
        if distance < bestDistance then best, bestDistance, action = station, distance, 'removeStation' end
    end
    for _, door in ipairs(mine(Client.world.doors)) do
        local distance = #(position - vector3(door.x, door.y, door.z))
        if distance < bestDistance then best, bestDistance, action = door, distance, 'removeDoor' end
    end
    if not best then return Client.notify('Aim at a station or door to remove it', false) end
    Client.report(Client.request(action, { id = best.id }))
end

local function highlight(entity)
    if Placement.outlined and Placement.outlined ~= entity then SetEntityDrawOutline(Placement.outlined, false) end
    Placement.outlined = entity
    if entity then
        SetEntityDrawOutlineColor(245, 158, 11, 255)
        SetEntityDrawOutline(entity, true)
    end
end

local function disableControls()
    DisablePlayerFiring(PlayerId(), true)
    for _, control in ipairs({ 24, 25, 14, 15, 16, 17, 140, 141, 142, 200 }) do DisableControlAction(0, control, true) end
end

local function tick()
    disableControls()
    drawExisting()

    local current = kind().id
    local hit, position, entity = aim()
    if current == 'door' then
        local isDoor = hit and entity ~= 0 and GetEntityType(entity) == 3
        highlight(isDoor and entity or nil)
        if isDoor and IsDisabledControlJustReleased(0, KEY.place) then addDoor(entity) end
    else
        highlight(nil)
        if hit then
            DrawMarker(25, position.x, position.y, position.z + 0.02, 0, 0, 0, 0, 0, 0, 0.7, 0.7, 0.7, 245, 158, 11, 170, false, false, 2, false, nil, nil, false)
            DrawMarker(2, position.x, position.y, position.z + 0.4, 0, 0, 0, 90.0, Placement.heading, 0, 0.2, 0.2, 0.2, 255, 255, 255, 200, false, false, 2, false, nil, nil, false)
            if IsDisabledControlJustReleased(0, KEY.place) then place(position) end
        end
    end

    if IsDisabledControlJustReleased(0, KEY.wheelUp) then Placement.heading = (Placement.heading + ROTATE_STEP) % 360 end
    if IsDisabledControlJustReleased(0, KEY.wheelDown) then Placement.heading = (Placement.heading - ROTATE_STEP) % 360 end
    if IsControlJustReleased(0, KEY.next) then Placement.index = Placement.index % #Placement.data.kinds + 1; updateBar() end
    if IsControlJustReleased(0, KEY.previous) then Placement.index = (Placement.index - 2) % #Placement.data.kinds + 1; updateBar() end
    if IsControlJustReleased(0, KEY.remove) and hit then removeNear(position) end
    if IsControlJustReleased(0, KEY.exit) or IsDisabledControlJustReleased(0, KEY.pause) then Placement.stop() end
end

function Placement.start(data)
    if Placement.active then return end
    Placement.active, Placement.data, Placement.index = true, data, 1
    Placement.heading, Placement.lastDoor = GetEntityHeading(PlayerPedId()), nil
    updateBar()
    CreateThread(function()
        while Placement.active do
            tick()
            Wait(0)
        end
    end)
end

function Placement.stop()
    Placement.active = false
    highlight(nil)
    SendNUIMessage({ action = 'placementEnd' })
end

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and Placement.active then highlight(nil) end
end)
