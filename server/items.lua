-- Vanguard Business - item setup and eating / drinking.
-- QBCore + qb-inventory: items are added at start (existing ones are kept) and made usable here.
-- ox_inventory (Qbox / ESX): paste install/ox_inventory_items.lua into ox_inventory; ox handles eating.

Items = {}

local FINISH_TOLERANCE_MS = 750
local eating = Pending.new() -- key: server id

local function definition(name, item, usable)
    return {
        name = name, label = item.label, weight = item.weight, type = 'item', image = item.image,
        unique = false, useable = usable, shouldClose = true,
        description = usable and ('Made fresh. Restores %s.'):format(item.kind == 'drink' and 'thirst' or 'hunger') or 'Ingredient',
    }
end

function Items.register()
    if Bridge.inventory ~= 'qb' then
        local missing = 0
        for name in pairs(Ingredients) do if not Bridge.itemExists(name) then missing = missing + 1 end end
        for name in pairs(Products) do if not Bridge.itemExists(name) then missing = missing + 1 end end
        if missing > 0 then
            print(('^3[vanguard-business] %d items are missing from ox_inventory: paste install/ox_inventory_items.lua into ox_inventory/data/items.lua^0'):format(missing))
        end
        return
    end

    local added, kept = 0, 0
    for name, item in pairs(Ingredients) do
        if Bridge.addItemDefinition(name, definition(name, item, false)) then added = added + 1 else kept = kept + 1 end
    end
    for name, item in pairs(Products) do
        if Bridge.addItemDefinition(name, definition(name, item, true)) then
            added = added + 1
            Bridge.createUsable(name, function(src) Items.use(src, name) end)
        else
            kept = kept + 1
        end
    end
    print(('[vanguard-business] items: %d added, %d already existed and were kept'):format(added, kept))
end

function Items.use(src, name)
    local product = Products[name]
    if not product or Bridge.itemCount(src, name) < 1 then return end
    local id = eating:start(src, name, GetGameTimer(), Config.ConsumeTime, Config.ConsumeTime + 15000)
    if not id then return end
    TriggerClientEvent('vanguard-business:consume', src, {
        id = id, label = product.label, kind = product.kind, prop = product.prop, duration = Config.ConsumeTime,
    })
end

Router.on('consumeFinish', function(src, data)
    local name, reason = eating:finish(src, data.id, GetGameTimer(), FINISH_TOLERANCE_MS)
    if not name then return Router.fail(reason == 'too_early' and 'Not finished yet' or nil) end
    if not Bridge.removeItem(src, name, 1) then return Router.fail('You no longer have it') end
    local product = Products[name]
    Bridge.addNeeds(src, product.hunger or 0, product.thirst or 0)
    return Router.ok()
end)

Router.on('consumeCancel', function(src)
    eating:cancel(src)
    return Router.ok()
end)

function Items.drop(src)
    eating:cancel(src)
end

CreateThread(function()
    while true do
        Wait(30000)
        eating:expire(GetGameTimer())
    end
end)
