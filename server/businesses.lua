-- Vanguard Business - businesses, balances, fridges and the money log.

Businesses = {}

local cache = {} -- id -> { id, name, type, balance, blip = { x, y, z } | nil }

local function decodeBlip(raw)
    if not raw then return nil end
    local ok, value = pcall(json.decode, raw)
    return ok and Rules.coords(value) or nil
end

function Businesses.load()
    cache = {}
    for _, row in ipairs(MySQL.query.await('SELECT id, name, type, balance, blip FROM vbiz_businesses') or {}) do
        cache[row.id] = { id = row.id, name = row.name, type = row.type, balance = row.balance, blip = decodeBlip(row.blip) }
    end
end

function Businesses.get(id)
    return id and cache[id] or nil
end

function Businesses.all()
    local list = {}
    for _, business in pairs(cache) do list[#list + 1] = business end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Businesses.count()
    local count = 0
    for _ in pairs(cache) do count = count + 1 end
    return count
end

function Businesses.stashId(id)
    return ('vbiz_%d'):format(id)
end

function Businesses.registerStash(business)
    Bridge.registerStash(Businesses.stashId(business.id), ('%s fridge'):format(business.name), Config.Stash.slots, Config.Stash.weight)
end

function Businesses.create(name, typeId)
    local id = MySQL.insert.await('INSERT INTO vbiz_businesses (name, type) VALUES (?, ?)', { name, typeId })
    if not id then return nil end
    cache[id] = { id = id, name = name, type = typeId, balance = 0 }
    Businesses.registerStash(cache[id])
    return cache[id]
end

function Businesses.rename(id, name)
    MySQL.update.await('UPDATE vbiz_businesses SET name = ? WHERE id = ?', { name, id })
    cache[id].name = name
    Businesses.registerStash(cache[id])
end

--- Deletes the business; staff, stations, doors and log rows go with it (foreign keys).
function Businesses.delete(id)
    MySQL.query.await('DELETE FROM vbiz_businesses WHERE id = ?', { id })
    cache[id] = nil
end

--- Adds delta (negative to spend) unless the balance would drop below zero.
--- Atomic in SQL, so two people spending at once can never overdraw.
function Businesses.adjust(id, delta)
    local changed = MySQL.update.await(
        'UPDATE vbiz_businesses SET balance = balance + ? WHERE id = ? AND balance + ? >= 0',
        { delta, id, delta })
    if changed ~= 1 then return false end
    local business = cache[id]
    if business then business.balance = business.balance + delta end
    return true
end

function Businesses.log(id, kind, amount, actor, note)
    MySQL.insert('INSERT INTO vbiz_transactions (business_id, kind, amount, actor, note) VALUES (?, ?, ?, ?, ?)',
        { id, kind, amount, actor, note })
end

function Businesses.history(id, limit)
    return MySQL.query.await(
        'SELECT kind, amount, actor, note, UNIX_TIMESTAMP(created_at) AS time FROM vbiz_transactions WHERE business_id = ? ORDER BY id DESC LIMIT ?',
        { id, limit }) or {}
end

function Businesses.setBlip(id, coords)
    MySQL.update.await('UPDATE vbiz_businesses SET blip = ? WHERE id = ?', { coords and json.encode(coords) or nil, id })
    cache[id].blip = coords
end
