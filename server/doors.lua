-- Vanguard Business - door locks: staff of the business (and server admins) can lock / unlock.

Router.on('toggleDoor', function(src, data)
    local door = Stations.getDoor(Rules.wholeNumber(data.doorId, 1, 2 ^ 31))
    if not door then return Router.fail('That door no longer exists') end
    if Access.distanceTo(src, door.x, door.y, door.z) > Config.InteractDistance + 1.5 then
        return Router.fail('You are too far from the door')
    end

    local rank = StaffList.rankOf(door.businessId, Bridge.identifier(src))
    if not Rules.can(Config.RankPermissions, rank, 'doors') and not Access.isAdmin(src) then
        return Router.fail('You don\'t have the key')
    end

    local locked = not door.locked
    local changed = Stations.setDoorLocked(door.id, locked)
    TriggerClientEvent('vanguard-business:doorState', -1, changed, locked)
    return Router.ok(locked and 'Locked' or 'Unlocked')
end)
