-- Vanguard Business - paychecks. Every Config.Paycheck.IntervalMinutes on shift, an employee is paid
-- their rank's amount into the bank (from the business account unless FromBusiness = false).
-- Clocking out, logging out or leaving resets the timer.

Payroll = {}

local TICK_MS = 60000
local worked = {} -- server id -> { businessId, minutes }

function Payroll.reset(src)
    worked[src] = nil
end

local function pay(src, businessId)
    local business = Businesses.get(businessId)
    local rank = StaffList.rankOf(businessId, Bridge.identifier(src))
    if not business or not rank then return end

    local amount = Rules.paycheckFor(Config.Paycheck.Amounts, rank)
    if amount <= 0 then return end
    local rankLabel = Config.Ranks[rank].label
    local fromBusiness = Config.Paycheck.FromBusiness

    if fromBusiness and not Businesses.adjust(businessId, -amount) then
        Access.notify(src, ('%s couldn\'t afford your $%d paycheck - tell the owner'):format(business.name, amount), false)
        return
    end
    if not Bridge.addMoney(src, 'bank', amount, 'vanguard-business paycheck') then
        if fromBusiness then Businesses.adjust(businessId, amount) end
        return
    end
    if fromBusiness then
        Businesses.log(businessId, 'pay', -amount, Bridge.characterName(src), rankLabel)
    end
    Access.notify(src, ('Paycheck: $%d from %s (%s)'):format(amount, business.name, rankLabel))
end

CreateThread(function()
    while true do
        Wait(TICK_MS)
        if Bridge.ready and Config.Paycheck.Enabled then
            local due = {}
            for src, businessId in pairs(StaffList.onDuty()) do
                local entry = worked[src]
                if not entry or entry.businessId ~= businessId then
                    entry = { businessId = businessId, minutes = 0 }
                    worked[src] = entry
                end
                entry.minutes = entry.minutes + 1
                if entry.minutes >= Config.Paycheck.IntervalMinutes then
                    entry.minutes = 0
                    due[#due + 1] = { src = src, businessId = businessId }
                end
            end
            for src in pairs(worked) do
                if not StaffList.dutyOf(src) then worked[src] = nil end
            end
            for _, entry in ipairs(due) do pay(entry.src, entry.businessId) end
        end
    end
end)
