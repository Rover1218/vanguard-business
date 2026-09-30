-- Vanguard Business - who may do what. Every request goes through these checks.

Access = {}

local DISTANCE_SLACK = 1.0 -- server positions lag a little behind the client

function Access.isAdmin(src)
    return IsPlayerAceAllowed(src, Config.AdminAce)
end

function Access.distanceTo(src, x, y, z)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - vector3(x, y, z))
end

--- Server admins always; business Owners too when Config.OwnersCanPlace is on.
function Access.canPlace(src, businessId)
    if Access.isAdmin(src) then return true end
    return Config.OwnersCanPlace and StaffList.rankOf(businessId, Bridge.identifier(src)) == Rules.RANK.OWNER
end

--- Checks the player stands at a station and may use it.
--- opts.kind: station kind, or 'cooking' for any cooking station; opts.permission: rank permission;
--- opts.duty: must be on shift at this business (when Config.RequireDuty).
--- Returns { station, business, identifier, rank } or nil, message.
function Access.atStation(src, stationId, opts)
    local station = Stations.get(tonumber(stationId))
    if not station then return nil, 'That station no longer exists' end

    local definition = StationKinds[station.kind]
    if opts.kind == 'cooking' then
        if not (definition and definition.cooking) then return nil, 'That is not a cooking station' end
    elseif opts.kind and station.kind ~= opts.kind then
        return nil, 'Wrong station'
    end

    local business = Businesses.get(station.businessId)
    if not business then return nil, 'That business no longer exists' end
    if Access.distanceTo(src, station.x, station.y, station.z) > Config.InteractDistance + DISTANCE_SLACK then
        return nil, 'You are too far away'
    end

    local identifier = Bridge.identifier(src)
    if not identifier then return nil, 'Load your character first' end
    local rank = StaffList.rankOf(business.id, identifier)
    if not rank then return nil, ('You don\'t work at %s'):format(business.name) end
    if opts.permission and not Rules.can(Config.RankPermissions, rank, opts.permission) then
        return nil, 'Your rank can\'t do that'
    end
    if opts.duty and Config.RequireDuty and StaffList.dutyOf(src) ~= business.id then
        return nil, 'Clock in first'
    end
    return { station = station, business = business, identifier = identifier, rank = rank }
end

--- What the client needs to know about this player's jobs.
function Access.jobsPayload(src)
    local jobs = {}
    for businessId, rank in pairs(StaffList.jobsOf(Bridge.identifier(src))) do
        local business = Businesses.get(businessId)
        if business then
            jobs[#jobs + 1] = { businessId = businessId, name = business.name, rank = rank, rankLabel = Config.Ranks[rank].label }
        end
    end
    table.sort(jobs, function(a, b) return a.name < b.name end)
    return { jobs = jobs, admin = Access.isAdmin(src), duty = StaffList.dutyOf(src) }
end

function Access.sendJobs(src)
    TriggerClientEvent('vanguard-business:jobs', src, Access.jobsPayload(src))
end

function Access.sendJobsTo(identifier)
    local src = Bridge.sourceFromIdentifier(identifier)
    if src then Access.sendJobs(src) end
end

function Access.notify(src, message, ok)
    TriggerClientEvent('vanguard-business:notify', src, message, ok ~= false)
end
