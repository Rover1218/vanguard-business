-- Vanguard Business - server bridge: one small interface over QBCore / Qbox / ESX and
-- qb-inventory / ox_inventory. Nothing else in the resource knows framework names.

Bridge = { framework = nil, inventory = nil, ready = false }

local core = nil
local stashes = {} -- id -> { label, slots, weight } (qb-inventory needs the size again on every use)

local function started(name)
    return GetResourceState(name) == 'started'
end

--- Detects the framework and inventory. Returns true, or false + reason.
function Bridge.init()
    if started('qbx_core') then
        Bridge.framework = 'qbx'
    elseif started('qb-core') then
        Bridge.framework = 'qb'
        core = exports['qb-core']:GetCoreObject()
    elseif started('es_extended') then
        Bridge.framework = 'esx'
        core = exports['es_extended']:getSharedObject()
    else
        return false, 'no supported framework is running (qbx_core, qb-core or es_extended)'
    end

    if started('ox_inventory') then
        Bridge.inventory = 'ox'
    elseif started('qb-inventory') and Bridge.framework == 'qb' then
        Bridge.inventory = 'qb'
    else
        return false, 'no supported inventory is running (ox_inventory, or qb-inventory on QBCore)'
    end

    if not started('oxmysql') then return false, 'oxmysql is not running' end
    if Bridge.inventory == 'ox' then Bridge.guardStashes() end
    return true
end

--- QBCore hands out a copy of its core object; take a fresh one after items or jobs change.
function Bridge.refreshCore()
    if Bridge.framework == 'qb' then core = exports['qb-core']:GetCoreObject() end
end

AddEventHandler('QBCore:Server:UpdateObject', function()
    if source == '' then Bridge.refreshCore() end
end)

-- ---------------------------------------------------------------------------
-- Players
-- ---------------------------------------------------------------------------

local function player(src)
    if Bridge.framework == 'qbx' then return exports.qbx_core:GetPlayer(src) end
    if Bridge.framework == 'qb' then return core.Functions.GetPlayer(src) end
    return core.GetPlayerFromId(src)
end

--- Character id (citizenid / ESX identifier), or nil before character selection.
function Bridge.identifier(src)
    local p = player(src)
    if not p then return nil end
    if Bridge.framework == 'esx' then return p.identifier end
    return p.PlayerData.citizenid
end

function Bridge.characterName(src)
    local p = player(src)
    if not p then return GetPlayerName(src) or 'Unknown' end
    if Bridge.framework == 'esx' then return p.getName() end
    local info = p.PlayerData.charinfo or {}
    local name = ('%s %s'):format(info.firstname or '', info.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or (GetPlayerName(src) or 'Unknown')
end

--- Server id of an online character, or nil.
function Bridge.sourceFromIdentifier(identifier)
    if not identifier then return nil end
    if Bridge.framework == 'qbx' then
        local p = exports.qbx_core:GetPlayerByCitizenId(identifier)
        return p and p.PlayerData.source or nil
    end
    if Bridge.framework == 'qb' then
        local p = core.Functions.GetPlayerByCitizenId(identifier)
        return p and p.PlayerData.source or nil
    end
    local p = core.GetPlayerFromIdentifier(identifier)
    return p and p.source or nil
end

-- ---------------------------------------------------------------------------
-- Money ('cash' | 'bank')
-- ---------------------------------------------------------------------------

local ESX_ACCOUNTS = { cash = 'money', bank = 'bank' }

function Bridge.getMoney(src, account)
    local p = player(src)
    if not p then return 0 end
    if Bridge.framework == 'esx' then
        local data = p.getAccount(ESX_ACCOUNTS[account])
        return data and data.money or 0
    end
    return p.PlayerData.money[account] or 0
end

function Bridge.removeMoney(src, account, amount, reason)
    local p = player(src)
    if not p or Bridge.getMoney(src, account) < amount then return false end
    if Bridge.framework == 'esx' then
        p.removeAccountMoney(ESX_ACCOUNTS[account], amount, reason)
        return true
    end
    return p.Functions.RemoveMoney(account, amount, reason) ~= false
end

function Bridge.addMoney(src, account, amount, reason)
    local p = player(src)
    if not p then return false end
    if Bridge.framework == 'esx' then
        p.addAccountMoney(ESX_ACCOUNTS[account], amount, reason)
        return true
    end
    return p.Functions.AddMoney(account, amount, reason) ~= false
end

-- ---------------------------------------------------------------------------
-- Items (target = player server id or stash id)
-- ---------------------------------------------------------------------------

local function ensureQbStash(target)
    local stash = type(target) == 'string' and stashes[target]
    if stash then
        exports['qb-inventory']:CreateInventory(target, { label = stash.label, slots = stash.slots, maxweight = stash.weight })
    end
end

function Bridge.itemExists(item)
    if Bridge.inventory == 'ox' then return exports.ox_inventory:Items(item) ~= nil end
    return core.Shared.Items[item] ~= nil
end

function Bridge.itemCount(src, item)
    if Bridge.inventory == 'ox' then return exports.ox_inventory:Search(src, 'count', item) or 0 end
    return exports['qb-inventory']:GetItemCount(src, item) or 0
end

function Bridge.addItem(target, item, amount)
    if not Bridge.itemExists(item) then return false end
    if Bridge.inventory == 'ox' then
        if not exports.ox_inventory:CanCarryItem(target, item, amount) then return false end
        return (exports.ox_inventory:AddItem(target, item, amount)) == true
    end
    ensureQbStash(target)
    local added = exports['qb-inventory']:AddItem(target, item, amount, false, false, 'vanguard-business')
    if added and type(target) == 'number' then
        TriggerClientEvent('qb-inventory:client:ItemBox', target, core.Shared.Items[item], 'add', amount)
    end
    return added == true
end

function Bridge.removeItem(target, item, amount)
    if Bridge.inventory == 'ox' then return (exports.ox_inventory:RemoveItem(target, item, amount)) == true end
    ensureQbStash(target)
    local removed = exports['qb-inventory']:RemoveItem(target, item, amount, false, 'vanguard-business')
    if removed and type(target) == 'number' then
        TriggerClientEvent('qb-inventory:client:ItemBox', target, core.Shared.Items[item], 'remove', amount)
    end
    return removed == true
end

-- ---------------------------------------------------------------------------
-- Stashes (business fridges)
-- ---------------------------------------------------------------------------

function Bridge.registerStash(id, label, slots, weight)
    stashes[id] = { label = label, slots = slots, weight = weight }
    if Bridge.inventory == 'ox' then
        exports.ox_inventory:RegisterStash(id, label, slots, weight)
    else
        ensureQbStash(id)
    end
end

-- ox_inventory lets clients ask to open any registered stash by name, so business fridges only
-- open right after the server allowed it (openFridge checks station, rank and shift first).
local STASH_GRANT_MS = 3000
local stashGrants = {} -- server id -> { id, expires }

function Bridge.guardStashes()
    exports.ox_inventory:registerHook('openInventory', function(payload)
        local grant = stashGrants[payload.source]
        return grant ~= nil and grant.id == payload.inventoryId and GetGameTimer() <= grant.expires
    end, { inventoryFilter = { '^vbiz_%d+$' } })
end

AddEventHandler('playerDropped', function()
    stashGrants[source] = nil
end)

function Bridge.openStash(src, id)
    if Bridge.inventory == 'ox' then
        stashGrants[src] = { id = id, expires = GetGameTimer() + STASH_GRANT_MS }
        exports.ox_inventory:forceOpenInventory(src, 'stash', id)
        return
    end
    local stash = stashes[id]
    exports['qb-inventory']:OpenInventory(src, id, stash and { label = stash.label, slots = stash.slots, maxweight = stash.weight } or nil)
end

-- ---------------------------------------------------------------------------
-- QBCore items and eating (ox_inventory handles both itself, see install/)
-- ---------------------------------------------------------------------------

--- Adds an item definition unless it already exists. Returns true when added.
function Bridge.addItemDefinition(name, definition)
    if Bridge.inventory ~= 'qb' or core.Shared.Items[name] then return false end
    return (exports['qb-core']:AddItem(name, definition)) == true
end

--- The item definition QBCore currently has for name (nil if none, or not QBCore).
function Bridge.existingItem(name)
    if Bridge.inventory ~= 'qb' then return nil end
    return core.Shared.Items[name]
end

function Bridge.createUsable(name, callback)
    core.Functions.CreateUseableItem(name, function(src) callback(src) end)
end

--- Adds hunger / thirst (0-100) and updates the HUD.
function Bridge.addNeeds(src, hunger, thirst)
    local p = player(src)
    if not p or Bridge.framework == 'esx' then return end
    local metadata = p.PlayerData.metadata
    local newHunger = math.min(100, (metadata.hunger or 0) + hunger)
    local newThirst = math.min(100, (metadata.thirst or 0) + thirst)
    p.Functions.SetMetaData('hunger', newHunger)
    p.Functions.SetMetaData('thirst', newThirst)
    TriggerClientEvent('hud:client:UpdateNeeds', src, newHunger, newThirst)
end
