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
    Items.syncTo(src)
    Stations.broadcast(src)
    Access.sendJobs(src)
end)

--- Ends everything tied to the current character: shift, cooking (ingredients go to the fridge),
--- bills and eating. Runs on disconnect and on character logout, so nothing carries to another character.
local function endSession(src)
    StaffList.setDuty(src, nil)
    Cooking.drop(src)
    Register.drop(src)
    Items.drop(src)
end

AddEventHandler('playerDropped', function()
    local src = source
    lastHello[src] = nil
    endSession(src)
end)

-- Character logout without disconnecting (multicharacter). Raised by the framework on the server;
-- a player can at most end their own session.
local function isOwnLogout(eventSource, src)
    return tonumber(src) ~= nil and (eventSource == '' or tonumber(eventSource) == tonumber(src))
end
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    if isOwnLogout(source, src) then endSession(tonumber(src)) end
end)

AddEventHandler('esx:playerLogout', function(src)
    if isOwnLogout(source, src) then endSession(tonumber(src)) end
end)
