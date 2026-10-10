-- Vanguard Business - paychecks. Every Config.Paycheck.IntervalMinutes on shift, an employee is paid
-- their rank's amount into the bank (from the business account when FromBusiness = true, else by the city).
-- Clocking out, logging out or leaving resets the timer; restarting this resource does not.

Payroll = {}

local RESOURCE = GetCurrentResourceName()
local TICK_MS = 60000
local worked = {} -- server id -> { businessId, minutes }

function Payroll.reset(src)
    worked[src] = nil
end

local function log(message, ...)
    print(('[%s] ' .. message):format(RESOURCE, ...))
end

local function pay(src, businessId)
    local business = Businesses.get(businessId)
    local rank = StaffList.rankOf(businessId, Bridge.identifier(src))
    if not business or not rank then return end

    local amount = Rules.paycheckFor(Config.Paycheck.Amounts, rank)
    if amount <= 0 then return end
    local rankLabel = Config.Ranks[rank].label
    local name = Bridge.characterName(src)
    local fromBusiness = Config.Paycheck.FromBusiness

    if fromBusiness and not Businesses.adjust(businessId, -amount, ('Paycheck: %s'):format(name)) then
        log('paycheck $%d for %s (%s) skipped: %s can\'t afford it', amount, name, src, business.name)
        Access.notify(src, ('%s couldn\'t afford your $%d paycheck - tell the owner'):format(business.name, amount), false)
        return
    end
    if not Bridge.addMoney(src, 'bank', amount, 'vanguard-business paycheck') then
        if fromBusiness then Businesses.adjust(businessId, amount, 'Paycheck refund') end
        log('paycheck $%d for %s (%s) failed: the framework refused the payment', amount, name, src)
        return
    end
    if fromBusiness then
        Businesses.log(businessId, 'pay', -amount, name, rankLabel)
    end
    log('paycheck $%d paid to %s (%s), %s at %s, by %s', amount, name, src, rankLabel, business.name,
        fromBusiness and 'the business' or 'the city')
    Access.notify(src, ('Paycheck: $%d from %s (%s)'):format(amount, business.name, rankLabel))
end

local function tick()
    local due = {}
    for src, businessId in pairs(StaffList.onDuty()) do
        local entry = worked[src]
        if not entry or entry.businessId ~= businessId then
            -- after a resource restart the minutes already worked come back from the player's state
            entry = { businessId = businessId, minutes = tonumber(StaffList.recall(src, 'vbizShiftMinutes')) or 0 }
            worked[src] = entry
        end
        entry.minutes = entry.minutes + 1
        if entry.minutes >= Config.Paycheck.IntervalMinutes then
            entry.minutes = 0
            due[#due + 1] = { src = src, businessId = businessId }
        end
        StaffList.remember(src, 'vbizShiftMinutes', entry.minutes)
    end
    for src in pairs(worked) do
        if not StaffList.dutyOf(src) then worked[src] = nil end
    end
    for _, entry in ipairs(due) do
        local ok, err = pcall(pay, entry.src, entry.businessId)
        if not ok then log('paycheck for %s failed: %s', entry.src, tostring(err)) end
    end
end

CreateThread(function()
    while true do
        Wait(TICK_MS)
        if Bridge.ready and Config.Paycheck.Enabled then tick() end
    end
end)
