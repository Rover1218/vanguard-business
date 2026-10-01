-- Vanguard Business - placed stations and doors, and the world data every client receives.

Stations = {}

local stations = {} -- id -> { id, businessId, kind, x, y, z, heading }
local doors = {}    -- id -> { id, businessId, model, x, y, z, pairId, locked }

function Stations.load()
    stations, doors = {}, {}
    for _, row in ipairs(MySQL.query.await('SELECT id, business_id, kind, x, y, z, heading FROM vbiz_stations') or {}) do
        stations[row.id] = { id = row.id, businessId = row.business_id, kind = row.kind, x = row.x, y = row.y, z = row.z, heading = row.heading }
    end
    for _, row in ipairs(MySQL.query.await('SELECT id, business_id, model, x, y, z, pair_id, locked, heading FROM vbiz_doors') or {}) do
        doors[row.id] = {
            id = row.id, businessId = row.business_id, model = row.model, x = row.x, y = row.y, z = row.z,
            pairId = row.pair_id, locked = row.locked == 1 or row.locked == true, heading = row.heading,
        }
    end
end

function Stations.get(id)
    return id and stations[id] or nil
end

function Stations.getDoor(id)
    return id and doors[id] or nil
end

function Stations.add(businessId, kind, coords, heading)
    local id = MySQL.insert.await('INSERT INTO vbiz_stations (business_id, kind, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?)',
        { businessId, kind, coords.x, coords.y, coords.z, heading })
    if not id then return nil end
    stations[id] = { id = id, businessId = businessId, kind = kind, x = coords.x, y = coords.y, z = coords.z, heading = heading }
    return stations[id]
end

function Stations.remove(id)
    MySQL.query.await('DELETE FROM vbiz_stations WHERE id = ?', { id })
    stations[id] = nil
end

--- Adds a door (locked). pairId links it to an existing door of the same business (double doors);
--- heading is the door's closed heading (where a locked door is held).
function Stations.addDoor(businessId, model, coords, pairId, heading)
    local id = MySQL.insert.await('INSERT INTO vbiz_doors (business_id, model, x, y, z, pair_id, locked, heading) VALUES (?, ?, ?, ?, ?, ?, 1, ?)',
        { businessId, model, coords.x, coords.y, coords.z, pairId, heading })
    if not id then return nil end
    doors[id] = {
        id = id, businessId = businessId, model = model, x = coords.x, y = coords.y, z = coords.z,
        pairId = pairId, locked = true, heading = heading,
    }
    if pairId and doors[pairId] then
        MySQL.update.await('UPDATE vbiz_doors SET pair_id = ?, locked = 1 WHERE id = ?', { id, pairId })
        doors[pairId].pairId = id
        doors[pairId].locked = true
    end
    return doors[id]
end

function Stations.removeDoor(id)
    local door = doors[id]
    if not door then return end
    MySQL.query.await('DELETE FROM vbiz_doors WHERE id = ?', { id })
    doors[id] = nil
    local partner = door.pairId and doors[door.pairId]
    if partner then
        MySQL.update.await('UPDATE vbiz_doors SET pair_id = NULL WHERE id = ?', { partner.id })
        partner.pairId = nil
    end
end

--- Locks / unlocks a door and its linked door. Returns the ids that changed.
function Stations.setDoorLocked(id, locked)
    local changed = {}
    local door = doors[id]
    if not door then return changed end
    for _, doorId in ipairs({ door.id, door.pairId }) do
        local target = doors[doorId]
        if target then
            target.locked = locked
            changed[#changed + 1] = doorId
            MySQL.update('UPDATE vbiz_doors SET locked = ? WHERE id = ?', { locked and 1 or 0, doorId })
        end
    end
    return changed
end

--- Drops a deleted business's stations and doors from memory (rows went with the business).
function Stations.forget(businessId)
    for id, station in pairs(stations) do
        if station.businessId == businessId then stations[id] = nil end
    end
    for id, door in pairs(doors) do
        if door.businessId == businessId then doors[id] = nil end
    end
end

function Stations.forBusiness(businessId)
    local result = { stations = {}, doors = {} }
    for _, station in pairs(stations) do
        if station.businessId == businessId then result.stations[#result.stations + 1] = station end
    end
    for _, door in pairs(doors) do
        if door.businessId == businessId then result.doors[#result.doors + 1] = door end
    end
    return result
end

--- World data for clients: every station, door, map icon and business name.
function Stations.snapshot()
    local world = { stations = {}, doors = {}, blips = {}, businesses = {} }
    for _, station in pairs(stations) do world.stations[#world.stations + 1] = station end
    for _, door in pairs(doors) do world.doors[#world.doors + 1] = door end
    for _, business in ipairs(Businesses.all()) do
        world.businesses[#world.businesses + 1] = { id = business.id, name = business.name, type = business.type }
        if business.blip then
            local blip = (BusinessTypes[business.type] or {}).blip or { sprite = 52, colour = 0 }
            world.blips[#world.blips + 1] = {
                businessId = business.id, name = business.name, sprite = blip.sprite, colour = blip.colour,
                x = business.blip.x, y = business.blip.y, z = business.blip.z,
            }
        end
    end
    return world
end

--- Sends the world data to one player, or everyone.
function Stations.broadcast(target)
    TriggerClientEvent('vanguard-business:world', target or -1, Stations.snapshot())
end
