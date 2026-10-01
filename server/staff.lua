-- Vanguard Business - staff lists, ranks and shifts.

StaffList = {}

local members = {} -- businessId -> identifier -> { name, rank }
local duty = {}    -- server id -> businessId (memory only; ends on disconnect, logout or restart)

function StaffList.load()
    members = {}
    for _, row in ipairs(MySQL.query.await('SELECT business_id, identifier, name, `rank` FROM vbiz_staff') or {}) do
        members[row.business_id] = members[row.business_id] or {}
        members[row.business_id][row.identifier] = { name = row.name, rank = row.rank }
    end
end

function StaffList.rankOf(businessId, identifier)
    local list = businessId and members[businessId]
    local entry = list and identifier and list[identifier]
    return entry and entry.rank or nil
end

-- Memory changes first, then the database: every check reads memory, so two requests racing
-- during the database wait (fire vs promote, two hires past the staff limit) see each other.
function StaffList.set(businessId, identifier, name, rank)
    members[businessId] = members[businessId] or {}
    members[businessId][identifier] = { name = name, rank = rank }
    MySQL.query.await(
        'INSERT INTO vbiz_staff (business_id, identifier, name, `rank`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), `rank` = VALUES(`rank`)',
        { businessId, identifier, name, rank })
end

function StaffList.remove(businessId, identifier)
    if members[businessId] then members[businessId][identifier] = nil end
    MySQL.query.await('DELETE FROM vbiz_staff WHERE business_id = ? AND identifier = ?', { businessId, identifier })
end

--- Drops a deleted business from memory (its rows were removed by the foreign key).
function StaffList.forget(businessId)
    members[businessId] = nil
    for src, id in pairs(duty) do
        if id == businessId then duty[src] = nil end
    end
end

--- Array of { identifier, name, rank }, highest rank first.
function StaffList.members(businessId)
    local list = {}
    for identifier, entry in pairs(members[businessId] or {}) do
        list[#list + 1] = { identifier = identifier, name = entry.name, rank = entry.rank }
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.name < b.name
    end)
    return list
end

function StaffList.count(businessId)
    local count = 0
    for _ in pairs(members[businessId] or {}) do count = count + 1 end
    return count
end

--- { [businessId] = rank } for one character.
function StaffList.jobsOf(identifier)
    local jobs = {}
    if not identifier then return jobs end
    for businessId, list in pairs(members) do
        if list[identifier] then jobs[businessId] = list[identifier].rank end
    end
    return jobs
end

function StaffList.ownerOf(businessId)
    for identifier, entry in pairs(members[businessId] or {}) do
        if entry.rank == Rules.RANK.OWNER then return identifier, entry.name end
    end
    return nil
end

--- Makes a character the Owner; the previous Owner becomes a Manager. Returns the previous owner id.
function StaffList.setOwner(businessId, identifier, name)
    local previous = StaffList.ownerOf(businessId)
    if previous and previous ~= identifier then
        StaffList.set(businessId, previous, members[businessId][previous].name, Rules.RANK.MANAGER)
    end
    StaffList.set(businessId, identifier, name, Rules.RANK.OWNER)
    return previous ~= identifier and previous or nil
end

function StaffList.setDuty(src, businessId)
    duty[src] = businessId
end

function StaffList.dutyOf(src)
    return duty[src]
end

--- Copy of { [server id] = businessId } for everyone on shift.
function StaffList.onDuty()
    local copy = {}
    for src, businessId in pairs(duty) do copy[src] = businessId end
    return copy
end

function StaffList.onDutyCount(businessId)
    local count = 0
    for _, id in pairs(duty) do
        if id == businessId then count = count + 1 end
    end
    return count
end
