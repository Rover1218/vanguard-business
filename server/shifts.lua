-- Vanguard Business - leaving work on shift. Someone clocked in who goes further than
-- Config.AutoClockOutDistance from every station of their business is clocked out automatically.

local RESOURCE = GetCurrentResourceName()
local CHECK_MS = 15000

--- How far the player is from the closest station of the business; nil when that can't be told
--- (no ped yet, or the business has no stations).
local function distanceFromWork(src, businessId)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local pos = GetEntityCoords(ped)
    return Rules.nearestDistance({ x = pos.x, y = pos.y, z = pos.z }, Stations.forBusiness(businessId).stations)
end

local function clockOut(src, businessId, distance)
    StaffList.setDuty(src, nil)
    Payroll.reset(src)
    Access.sendJobs(src)
    local business = Businesses.get(businessId)
    local name = business and business.name or 'work'
    Access.notify(src, ('Clocked out of %s - you went more than %g km away'):format(name, Config.AutoClockOutDistance / 1000), false)
    print(('[%s] %s (%s) clocked out of %s automatically: %.0f m away'):format(
        RESOURCE, Bridge.characterName(src), src, name, distance))
end

local function check()
    local limit = Config.AutoClockOutDistance
    for src, businessId in pairs(StaffList.onDuty()) do
        local distance = distanceFromWork(src, businessId)
        if distance and distance > limit then
            local ok, err = pcall(clockOut, src, businessId, distance)
            if not ok then print(('[%s] auto clock-out for %s failed: %s'):format(RESOURCE, src, tostring(err))) end
        end
    end
end

CreateThread(function()
    while true do
        Wait(CHECK_MS)
        if Bridge.ready and (Config.AutoClockOutDistance or 0) > 0 then check() end
    end
end)
