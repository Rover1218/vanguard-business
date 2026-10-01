-- Vanguard Business - boss desk (money, staff), clock-in point and fridge.

local LOG_LIMIT = 50
local NEARBY_RANGE = 10.0
local NAME_MAX = 64

local function rankLabels()
    local labels = {}
    for index, rank in ipairs(Config.Ranks) do labels[index] = rank.label end
    return labels
end

--- Team list. Character ids are only sent to ranks that can hire / fire (they need them to act).
local function staffView(businessId, viewer, canManage)
    local list = StaffList.members(businessId)
    for _, member in ipairs(list) do
        local src = Bridge.sourceFromIdentifier(member.identifier)
        member.online = src ~= nil
        member.onDuty = src ~= nil and StaffList.dutyOf(src) == businessId
        member.isMe = member.identifier == viewer
        if not canManage then member.identifier = nil end
    end
    return list
end

Router.on('bossData', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'boss' })
    if not ctx then return Router.fail(err) end
    local permissions = Config.RankPermissions[ctx.rank] or {}
    local business = ctx.business
    return Router.ok(nil, {
        stationId = ctx.station.id,
        business = {
            id = business.id, name = business.name,
            typeLabel = (BusinessTypes[business.type] or {}).label or business.type,
            balance = permissions.log and business.balance or nil,
        },
        rank = ctx.rank,
        permissions = permissions,
        ranks = rankLabels(),
        staff = staffView(business.id, ctx.identifier, permissions.hire == true),
        onDuty = StaffList.onDutyCount(business.id),
        log = permissions.log and Businesses.history(business.id, LOG_LIMIT) or nil,
        catalog = permissions.supplier and Types.catalog(business.type) or nil,
        maxPacks = Config.MaxPacksPerLine,
        maxTransaction = Config.MaxTransaction,
        canPlace = Access.canPlace(src, business.id),
        paychecks = Config.Paycheck.Enabled and {
            amounts = Config.Paycheck.Amounts,
            minutes = Config.Paycheck.IntervalMinutes,
            fromBusiness = Config.Paycheck.FromBusiness,
        } or nil,
    })
end)

--- Players near a boss desk (for hiring) or a register (for billing).
Router.on('nearbyPlayers', function(src, data)
    local station = Stations.get(tonumber(data.stationId))
    local isRegister = station and station.kind == 'register'
    local ctx, err = Access.atStation(src, data.stationId, {
        kind = isRegister and 'register' or 'boss',
        permission = isRegister and 'register' or 'hire',
        duty = isRegister,
    })
    if not ctx then return Router.fail(err) end

    local range = isRegister and Config.BillDistance or NEARBY_RANGE
    local players = {}
    for _, id in ipairs(GetPlayers()) do
        local playerId = tonumber(id)
        if playerId ~= src and Access.distanceTo(playerId, ctx.station.x, ctx.station.y, ctx.station.z) <= range then
            players[#players + 1] = { id = playerId, name = Bridge.characterName(playerId) }
        end
    end
    table.sort(players, function(a, b) return a.id < b.id end)
    return Router.ok(nil, { players = players })
end)

-- ---------------------------------------------------------------------------
-- Money
-- ---------------------------------------------------------------------------

Router.on('deposit', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'boss' })
    if not ctx then return Router.fail(err) end
    local amount = Rules.wholeNumber(data.amount, 1, Config.MaxTransaction)
    if not amount then return Router.fail(('Enter an amount from $1 to $%d'):format(Config.MaxTransaction)) end

    if not Bridge.removeMoney(src, 'cash', amount, 'vanguard-business deposit') then
        return Router.fail('You don\'t have that much cash')
    end
    if not Businesses.adjust(ctx.business.id, amount) then
        Bridge.addMoney(src, 'cash', amount, 'vanguard-business deposit refund')
        return Router.fail('Could not deposit, your cash was returned')
    end
    Businesses.log(ctx.business.id, 'deposit', amount, Bridge.characterName(src), nil)
    return Router.ok(('Deposited $%d'):format(amount))
end)

Router.on('withdraw', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'boss', permission = 'withdraw' })
    if not ctx then return Router.fail(err) end
    local amount = Rules.wholeNumber(data.amount, 1, Config.MaxTransaction)
    if not amount then return Router.fail(('Enter an amount from $1 to $%d'):format(Config.MaxTransaction)) end

    if not Businesses.adjust(ctx.business.id, -amount) then return Router.fail('The business doesn\'t have that much') end
    if not Bridge.addMoney(src, 'cash', amount, 'vanguard-business withdraw') then
        Businesses.adjust(ctx.business.id, amount)
        return Router.fail('Could not pay you, the money stays in the business')
    end
    Businesses.log(ctx.business.id, 'withdraw', -amount, Bridge.characterName(src), nil)
    return Router.ok(('Withdrew $%d'):format(amount))
end)

-- ---------------------------------------------------------------------------
-- Staff
-- ---------------------------------------------------------------------------

Router.on('hire', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'boss', permission = 'hire' })
    if not ctx then return Router.fail(err) end
    local business = ctx.business

    local target = Rules.wholeNumber(data.target, 1, 2 ^ 31)
    if not target or not GetPlayerName(target) then return Router.fail('No player with that server ID') end
    if target == src then return Router.fail('You already work here') end
    local station = ctx.station
    if Access.distanceTo(target, station.x, station.y, station.z) > NEARBY_RANGE then
        return Router.fail('The new hire must be here at the boss desk')
    end
    local identifier = Bridge.identifier(target)
    if not identifier then return Router.fail('That player has no character loaded') end
    if StaffList.rankOf(business.id, identifier) then return Router.fail('They already work here') end
    if StaffList.count(business.id) >= Config.MaxStaff then return Router.fail('The staff list is full') end

    local rank = Rules.wholeNumber(data.rank, 1, #Config.Ranks)
    if not Rules.canAssignRank(ctx.rank, rank) then return Router.fail('You can\'t hire at that rank') end

    local name = Rules.cleanText(Bridge.characterName(target), NAME_MAX) or 'Unknown'
    StaffList.set(business.id, identifier, name, rank)
    Businesses.log(business.id, 'hire', 0, Bridge.characterName(src), ('%s as %s'):format(name, Config.Ranks[rank].label))
    Access.sendJobs(target)
    Access.notify(target, ('You were hired at %s as %s'):format(business.name, Config.Ranks[rank].label))
    return Router.ok(('Hired %s as %s'):format(name, Config.Ranks[rank].label))
end)

local function managedMember(ctx, identifier)
    if type(identifier) ~= 'string' or #identifier > 64 then return nil, 'Pick a staff member' end
    if identifier == ctx.identifier then return nil, 'You can\'t change your own job' end
    local rank = StaffList.rankOf(ctx.business.id, identifier)
    if not rank then return nil, 'They no longer work here' end
    if not Rules.canManage(ctx.rank, rank) then return nil, 'Their rank is not below yours' end
    return rank
end

Router.on('setRank', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'boss', permission = 'hire' })
    if not ctx then return Router.fail(err) end
    local _, memberErr = managedMember(ctx, data.identifier)
    if memberErr then return Router.fail(memberErr) end

    local rank = Rules.wholeNumber(data.rank, 1, #Config.Ranks)
    if not Rules.canAssignRank(ctx.rank, rank) then return Router.fail('You can\'t give that rank') end

    local member
    for _, entry in ipairs(StaffList.members(ctx.business.id)) do
        if entry.identifier == data.identifier then member = entry end
    end
    StaffList.set(ctx.business.id, data.identifier, member.name, rank)
    Businesses.log(ctx.business.id, 'rank', 0, Bridge.characterName(src), ('%s is now %s'):format(member.name, Config.Ranks[rank].label))
    Access.sendJobsTo(data.identifier)
    return Router.ok(('%s is now %s'):format(member.name, Config.Ranks[rank].label))
end)

Router.on('fire', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'boss', permission = 'hire' })
    if not ctx then return Router.fail(err) end
    local _, memberErr = managedMember(ctx, data.identifier)
    if memberErr then return Router.fail(memberErr) end

    local name = 'Unknown'
    for _, entry in ipairs(StaffList.members(ctx.business.id)) do
        if entry.identifier == data.identifier then name = entry.name end
    end
    StaffList.remove(ctx.business.id, data.identifier)
    Businesses.log(ctx.business.id, 'fire', 0, Bridge.characterName(src), name)

    local target = Bridge.sourceFromIdentifier(data.identifier)
    if target then
        if StaffList.dutyOf(target) == ctx.business.id then StaffList.setDuty(target, nil) end
        Access.sendJobs(target)
        Access.notify(target, ('You no longer work at %s'):format(ctx.business.name), false)
    end
    return Router.ok(('%s was let go'):format(name))
end)

-- ---------------------------------------------------------------------------
-- Clock-in point and fridge
-- ---------------------------------------------------------------------------

Router.on('clock', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'clockin' })
    if not ctx then return Router.fail(err) end
    local message
    if StaffList.dutyOf(src) == ctx.business.id then
        StaffList.setDuty(src, nil)
        message = ('Clocked out of %s'):format(ctx.business.name)
    else
        StaffList.setDuty(src, ctx.business.id)
        message = ('Clocked in at %s'):format(ctx.business.name)
    end
    Access.sendJobs(src)
    return Router.ok(message)
end)

Router.on('openFridge', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'fridge', permission = 'fridge', duty = true })
    if not ctx then return Router.fail(err) end
    Bridge.openStash(src, Businesses.stashId(ctx.business.id))
    return Router.ok()
end)
