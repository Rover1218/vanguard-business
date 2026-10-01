-- Vanguard Business - /business home screen and server-admin actions (create, owners, placement).

local NAME_MAX = 40
local PLACE_REACH = 30.0     -- you must stand within this distance of what you place or remove
local DOOR_DUPLICATE = 0.3   -- metres: the same door can't be added twice

local function businessView(business)
    local _, ownerName = StaffList.ownerOf(business.id)
    local placed = Stations.forBusiness(business.id)
    local first = placed.stations[1]
    return {
        id = business.id, name = business.name, type = business.type,
        typeLabel = (BusinessTypes[business.type] or {}).label or business.type,
        balance = business.balance, owner = ownerName, staff = StaffList.count(business.id),
        onDuty = StaffList.onDutyCount(business.id), stations = #placed.stations, doors = #placed.doors,
        hasBlip = business.blip ~= nil,
        teleport = (first and { x = first.x, y = first.y, z = first.z }) or business.blip,
    }
end

local function typesView()
    local list = {}
    for id, businessType in pairs(BusinessTypes) do list[#list + 1] = { id = id, label = businessType.label } end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

local function adminBusiness(src, id)
    if not Access.isAdmin(src) then return nil, 'Admins only' end
    local business = Businesses.get(Rules.wholeNumber(id, 1, 2 ^ 31))
    if not business then return nil, 'That business no longer exists' end
    return business
end

local function nearEnough(src, coords)
    return Access.distanceTo(src, coords.x, coords.y, coords.z) <= PLACE_REACH
end

Router.on('home', function(src)
    local view = Access.jobsPayload(src)
    if view.admin then
        view.businesses = {}
        for _, business in ipairs(Businesses.all()) do view.businesses[#view.businesses + 1] = businessView(business) end
        view.types = typesView()
    end
    return Router.ok(nil, view)
end)

Router.on('adminCreate', function(src, data)
    if not Access.isAdmin(src) then return Router.fail('Admins only') end
    local name = Rules.cleanText(data.name, NAME_MAX)
    if not name then return Router.fail('Type a name') end
    if type(data.type) ~= 'string' or not BusinessTypes[data.type] then return Router.fail('Pick a business type') end
    if Businesses.count() >= Config.MaxBusinesses then return Router.fail('Business limit reached') end

    local business = Businesses.create(name, data.type)
    if not business then return Router.fail('Could not save the business') end
    Router.log(src, ('created business %d "%s" (%s)'):format(business.id, name, data.type))
    Stations.broadcast()
    return Router.ok(('Created %s'):format(name))
end)

Router.on('adminRename', function(src, data)
    local business, err = adminBusiness(src, data.id)
    if not business then return Router.fail(err) end
    local name = Rules.cleanText(data.name, NAME_MAX)
    if not name then return Router.fail('Type a name') end
    Businesses.rename(business.id, name)
    Stations.broadcast()
    for _, member in ipairs(StaffList.members(business.id)) do Access.sendJobsTo(member.identifier) end
    return Router.ok(('Renamed to %s'):format(name))
end)

Router.on('adminDelete', function(src, data)
    local business, err = adminBusiness(src, data.id)
    if not business then return Router.fail(err) end
    local formerStaff = StaffList.members(business.id)

    Businesses.delete(business.id)
    StaffList.forget(business.id)
    Stations.forget(business.id)
    Router.log(src, ('deleted business %d "%s"'):format(business.id, business.name))

    Stations.broadcast()
    for _, member in ipairs(formerStaff) do Access.sendJobsTo(member.identifier) end
    return Router.ok(('Deleted %s'):format(business.name))
end)

Router.on('adminSetOwner', function(src, data)
    local business, err = adminBusiness(src, data.id)
    if not business then return Router.fail(err) end
    local target = Rules.wholeNumber(data.target, 1, 2 ^ 31)
    if not target or not GetPlayerName(target) then return Router.fail('No player with that server ID') end
    local identifier = Bridge.identifier(target)
    if not identifier then return Router.fail('That player has no character loaded') end

    local name = Rules.cleanText(Bridge.characterName(target), 64) or 'Unknown'
    local previous = StaffList.setOwner(business.id, identifier, name)
    Businesses.log(business.id, 'owner', 0, 'Server admin', name)
    Router.log(src, ('made %s owner of business %d'):format(name, business.id))

    Access.sendJobs(target)
    if previous then Access.sendJobsTo(previous) end
    Access.notify(target, ('You are now the Owner of %s'):format(business.name))
    return Router.ok(('%s is now the Owner of %s'):format(name, business.name))
end)

-- ---------------------------------------------------------------------------
-- Placement
-- ---------------------------------------------------------------------------

local function placeableBusiness(src, id)
    local business = Businesses.get(Rules.wholeNumber(id, 1, 2 ^ 31))
    if not business then return nil, 'That business no longer exists' end
    if not Access.canPlace(src, business.id) then return nil, 'You can\'t place stations here' end
    return business
end

Router.on('placementData', function(src, data)
    local business, err = placeableBusiness(src, data.businessId)
    if not business then return Router.fail(err) end
    local kinds = {}
    for _, kind in ipairs(Types.placeableKinds(business.type)) do
        kinds[#kinds + 1] = { id = kind, label = StationKinds[kind].label }
    end
    kinds[#kinds + 1] = { id = 'door', label = 'Door' }
    kinds[#kinds + 1] = { id = 'blip', label = 'Map icon' }
    return Router.ok(nil, { business = { id = business.id, name = business.name }, kinds = kinds })
end)

Router.on('placeStation', function(src, data)
    local business, err = placeableBusiness(src, data.businessId)
    if not business then return Router.fail(err) end
    local coords, heading = Rules.coords(data.coords), Rules.heading(data.heading)
    if not coords or not heading then return Router.fail('Bad position') end
    if not nearEnough(src, coords) then return Router.fail('Stand closer to where you place it') end

    if data.kind == 'blip' then
        Businesses.setBlip(business.id, coords)
        Stations.broadcast()
        return Router.ok('Map icon placed')
    end

    local allowed = false
    for _, kind in ipairs(Types.placeableKinds(business.type)) do
        if kind == data.kind then allowed = true end
    end
    if not allowed then return Router.fail('This business can\'t have that station') end
    if #Stations.forBusiness(business.id).stations >= Config.MaxStationsPerBusiness then
        return Router.fail(('Station limit reached (%d)'):format(Config.MaxStationsPerBusiness))
    end

    if not Stations.add(business.id, data.kind, coords, heading) then return Router.fail('Could not save the station') end
    Stations.broadcast()
    return Router.ok(('%s placed'):format(StationKinds[data.kind].label))
end)

Router.on('removeStation', function(src, data)
    local station = Stations.get(Rules.wholeNumber(data.id, 1, 2 ^ 31))
    if not station then return Router.fail('That station no longer exists') end
    if not Access.canPlace(src, station.businessId) then return Router.fail('You can\'t remove stations here') end
    if not nearEnough(src, station) then return Router.fail('Stand closer to it') end
    Stations.remove(station.id)
    Stations.broadcast()
    return Router.ok(('%s removed'):format(StationKinds[station.kind] and StationKinds[station.kind].label or 'Station'))
end)

Router.on('removeBlip', function(src, data)
    local business, err = placeableBusiness(src, data.businessId)
    if not business then return Router.fail(err) end
    Businesses.setBlip(business.id, nil)
    Stations.broadcast()
    return Router.ok('Map icon removed')
end)

Router.on('addDoor', function(src, data)
    local business, err = placeableBusiness(src, data.businessId)
    if not business then return Router.fail(err) end
    local coords = Rules.coords(data.coords)
    local model = Rules.wholeNumber(data.model, -2 ^ 31, 2 ^ 31 - 1)
    if not coords or not model then return Router.fail('Aim at a door') end
    if not nearEnough(src, coords) then return Router.fail('Stand closer to the door') end

    local placed = Stations.forBusiness(business.id)
    if #placed.doors >= Config.MaxDoorsPerBusiness then
        return Router.fail(('Door limit reached (%d)'):format(Config.MaxDoorsPerBusiness))
    end
    local position = vector3(coords.x, coords.y, coords.z)
    for _, door in ipairs(placed.doors) do
        if door.model == model and #(vector3(door.x, door.y, door.z) - position) < DOOR_DUPLICATE then
            return Router.fail('That door is already added')
        end
    end

    -- Owners may only lock doors of their own place, never someone else's (e.g. the hospital).
    if not Access.isAdmin(src) then
        local nearOwnStation = false
        for _, station in ipairs(placed.stations) do
            if #(vector3(station.x, station.y, station.z) - position) <= Config.OwnerDoorRadius then nearOwnStation = true end
        end
        if not nearOwnStation then return Router.fail('Place your stations first - doors must be near them') end
    end

    local pairId = nil
    if data.pairWith ~= nil then
        local partner = Stations.getDoor(Rules.wholeNumber(data.pairWith, 1, 2 ^ 31))
        if partner and partner.businessId == business.id and not partner.pairId then pairId = partner.id end
    end

    local door = Stations.addDoor(business.id, model, coords, pairId, Rules.heading(data.heading))
    if not door then return Router.fail('Could not save the door') end
    Stations.broadcast()
    return Router.ok(pairId and 'Double door linked and locked' or 'Door added and locked', { id = door.id })
end)

Router.on('removeDoor', function(src, data)
    local door = Stations.getDoor(Rules.wholeNumber(data.id, 1, 2 ^ 31))
    if not door then return Router.fail('That door no longer exists') end
    if not Access.canPlace(src, door.businessId) then return Router.fail('You can\'t remove doors here') end
    if not nearEnough(src, door) then return Router.fail('Stand closer to the door') end
    Stations.removeDoor(door.id)
    Stations.broadcast()
    return Router.ok('Door removed')
end)
