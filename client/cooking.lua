-- Vanguard Business - cooking at a station and eating / drinking (QBCore + qb-inventory).

Cooking = { busy = false, station = nil }
Consume = { busy = false }

local CANCEL_KEY = 73 -- X
local LOAD_TIMEOUT_MS = 3000

--- Waits while the action runs. Returns true if it ran to the end, false if cancelled.
--- keepNear: optional position the player must stay close to.
local function runTimed(duration, keepNear)
    local ped = PlayerPedId()
    local finishAt = GetGameTimer() + duration
    while GetGameTimer() < finishAt do
        Wait(0)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        if IsControlJustReleased(0, CANCEL_KEY) or IsEntityDead(ped) then return false end
        if keepNear and #(GetEntityCoords(ped) - keepNear) > Config.InteractDistance + 1.0 then return false end
    end
    return true
end

local function loadWithTimeout(request, isLoaded)
    request()
    local giveUp = GetGameTimer() + LOAD_TIMEOUT_MS
    while not isLoaded() and GetGameTimer() < giveUp do Wait(10) end
    return isLoaded()
end

function Cooking.open(station)
    local result = Client.request('cookData', { stationId = station.id })
    if not result.ok then return Client.report(result) end
    Cooking.station = station
    Client.openPanel('cook', result.data)
end

function Cooking.run(station, recipe, quantity)
    if Cooking.busy or Consume.busy then return end
    local start = Client.request('cookStart', { stationId = station.id, recipe = recipe, quantity = quantity })
    if not start.ok then return Client.report(start) end

    Cooking.busy = true
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, start.data.scenario, 0, true)
    SendNUIMessage({ action = 'progress', label = start.data.label, duration = start.data.duration })

    local finished = runTimed(start.data.duration, vector3(station.x, station.y, station.z))

    ClearPedTasks(ped)
    SendNUIMessage({ action = 'progressEnd' })
    Client.report(finished and Client.request('cookFinish', { jobId = start.data.jobId }) or Client.request('cookCancel'))
    Cooking.busy = false
end

RegisterNUICallback('cook', function(body, cb)
    cb({})
    local station = Cooking.station
    if not station or type(body) ~= 'table' then return end
    Client.closePanel()
    Cooking.run(station, body.recipe, body.quantity)
end)

-- Eating / drinking an item from this resource (the server starts it when the item is used).
RegisterNetEvent('vanguard-business:consume', function(info)
    if Cooking.busy or Consume.busy then
        Client.request('consumeCancel')
        return
    end
    Consume.busy = true

    local ped = PlayerPedId()
    local anim = ConsumeAnims[info.kind] or ConsumeAnims.food
    local model = GetHashKey(ConsumeProps[info.prop] or ConsumeProps.cup)
    local hasAnim = loadWithTimeout(function() RequestAnimDict(anim.dict) end, function() return HasAnimDictLoaded(anim.dict) end)
    local hasModel = loadWithTimeout(function() RequestModel(model) end, function() return HasModelLoaded(model) end)

    local prop = nil
    if hasModel then
        local position = GetEntityCoords(ped)
        prop = CreateObject(model, position.x, position.y, position.z + 0.2, true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 18905), 0.12, 0.028, 0.001, 10.0, 175.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(model)
    end
    if hasAnim then TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 49, 0, false, false, false) end
    SendNUIMessage({ action = 'progress', label = ('%s %s'):format(info.kind == 'drink' and 'Drinking' or 'Eating', info.label), duration = info.duration })

    local finished = runTimed(info.duration)

    StopAnimTask(ped, anim.dict, anim.clip, 1.0)
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    SendNUIMessage({ action = 'progressEnd' })
    local result = finished and Client.request('consumeFinish', { id = info.id }) or Client.request('consumeCancel')
    if not result.ok then Client.report(result) end
    Consume.busy = false
end)
