-- Vanguard Business - boss desk, cash register, bills and the admin panel's client-side buttons.

Panels = {}

function Panels.openBoss(station)
    local result = Client.request('bossData', { stationId = station.id })
    if not result.ok then return Client.report(result) end
    Client.openPanel('boss', result.data)
end

function Panels.openRegister(station)
    local result = Client.request('nearbyPlayers', { stationId = station.id })
    if not result.ok then return Client.report(result) end
    Client.openPanel('register', { stationId = station.id, players = result.data.players, maxBill = Config.MaxBill })
end

-- A staff member sent us a bill.
RegisterNetEvent('vanguard-business:bill', function(bill)
    Client.openPanel('bill', bill)
end)

RegisterNetEvent('vanguard-business:billClosed', function()
    if Client.page == 'bill' then
        Client.closePanel()
        Client.notify('The bill was closed', false)
    end
end)

-- Placement mode, from the admin panel or the boss desk.
RegisterNUICallback('placeStart', function(body, cb)
    cb({})
    local result = Client.request('placementData', { businessId = type(body) == 'table' and body.businessId or nil })
    if not result.ok then return Client.report(result) end
    Client.closePanel()
    Placement.start(result.data)
end)

-- Admin teleport to a business (the button only shows for admins).
RegisterNUICallback('teleport', function(body, cb)
    cb({})
    if not Client.admin or type(body) ~= 'table' then return end
    local x, y, z = tonumber(body.x), tonumber(body.y), tonumber(body.z)
    if not (x and y and z) then return end
    Client.closePanel()
    SetEntityCoords(PlayerPedId(), x, y, z + 0.5, false, false, false, false)
end)
