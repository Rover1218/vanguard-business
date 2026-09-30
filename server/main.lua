-- Vanguard Business - start-up and player lifecycle.

local HELLO_COOLDOWN_MS = 2000
local lastHello = {}

CreateThread(function()
    local ok, reason = Bridge.init()
    if not ok then
        print(('^1[vanguard-business] not started: %s^0'):format(reason))
        return
    end

    DB.init()
    Businesses.load()
    StaffList.load()
    Stations.load()
    for _, business in ipairs(Businesses.all()) do Businesses.registerStash(business) end
    Items.register()

    Bridge.ready = true
    Stations.broadcast()
    for _, id in ipairs(GetPlayers()) do Access.sendJobs(tonumber(id)) end
    print(('[vanguard-business] ready (%s + %s), %d businesses'):format(Bridge.framework, Bridge.inventory, Businesses.count()))
end)

-- Clients say hello when they start and when their character loads.
RegisterNetEvent('vanguard-business:hello', function()
    local src = source
    local now = GetGameTimer()
    if not Bridge.ready or (lastHello[src] and now - lastHello[src] < HELLO_COOLDOWN_MS) then return end
    lastHello[src] = now
    Stations.broadcast(src)
    Access.sendJobs(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastHello[src] = nil
    StaffList.setDuty(src, nil)
    Cooking.drop(src)
    Register.drop(src)
    Items.drop(src)
end)
