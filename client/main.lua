-- Vanguard Business - client core: server requests, the panel, and what we know about our jobs.

Client = {
    jobs = {},    -- businessId -> rank
    admin = false,
    duty = nil,
    world = { stations = {}, doors = {}, blips = {}, businesses = {} },
    page = nil,
}

local REQUEST_TIMEOUT_MS = 10000
local pending, nextId = {}, 0

--- Sends an action to the server and waits for { ok, message, data }.
function Client.request(action, data)
    nextId = nextId + 1
    local id = nextId
    local answer = promise.new()
    pending[id] = answer
    TriggerServerEvent('vanguard-business:request', id, action, data or {})
    SetTimeout(REQUEST_TIMEOUT_MS, function()
        if pending[id] then
            pending[id] = nil
            answer:resolve({ ok = false, message = 'The server did not answer' })
        end
    end)
    return Citizen.Await(answer)
end

RegisterNetEvent('vanguard-business:response', function(id, result)
    local answer = pending[id]
    if not answer then return end
    pending[id] = nil
    answer:resolve(type(result) == 'table' and result or { ok = false })
end)

function Client.notify(message, ok)
    if message then SendNUIMessage({ action = 'toast', message = message, ok = ok ~= false }) end
end

function Client.openPanel(page, payload)
    Client.page = page
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', page = page, payload = payload, brand = Config.Brand })
end

function Client.closePanel()
    Client.page = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

--- Shows a server answer as a toast. Returns result.ok.
function Client.report(result)
    Client.notify(result.message, result.ok)
    return result.ok
end

RegisterNUICallback('close', function(_, cb)
    Client.closePanel()
    cb({})
end)

-- The panel forwards { action, data } for server actions; the server checks everything itself.
RegisterNUICallback('request', function(body, cb)
    if type(body) ~= 'table' or type(body.action) ~= 'string' then return cb({ ok = false }) end
    cb(Client.request(body.action, body.data))
end)

RegisterNetEvent('vanguard-business:jobs', function(payload)
    Client.jobs = {}
    for _, job in ipairs(payload.jobs or {}) do Client.jobs[job.businessId] = job.rank end
    Client.admin = payload.admin == true
    Client.duty = payload.duty
end)

RegisterNetEvent('vanguard-business:world', function(world)
    Client.world = world
    World.rebuild()
end)

RegisterNetEvent('vanguard-business:notify', function(message, ok)
    Client.notify(message, ok)
end)

RegisterCommand(Config.Command, function()
    local result = Client.request('home')
    if not result.ok then return Client.report(result) end
    Client.openPanel('home', result.data)
end, false)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    TriggerServerEvent('vanguard-business:hello')
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and Client.page then SetNuiFocus(false, false) end
end)
