-- Vanguard Business - where business money lives. With Vanguard Bank running it is the business's
-- Business account in the bank; without it, the balance column in vbiz_businesses (as before).

BankLink = {}

local BANK = 'vanguard-bank'
local RESOURCE = GetCurrentResourceName()

function BankLink.active()
    return GetResourceState(BANK) == 'started'
end

function BankLink.balance(business)
    local ok, value = pcall(function() return exports[BANK]:getBusinessBalance(business.id) end)
    return ok and tonumber(value) or 0
end

function BankLink.adjust(business, delta, note)
    local ok, changed = pcall(function()
        return exports[BANK]:adjustBusiness(business.id, delta, nil, 'Vanguard Business', note, business.name)
    end)
    if not ok then print(('[%s] bank adjust failed: %s'):format(RESOURCE, tostring(changed))) end
    return ok and changed == true
end

--- Moves money still in the balance column into the bank account (first start with Vanguard Bank).
function BankLink.moveBalances()
    if not BankLink.active() then return end
    for _, business in ipairs(Businesses.all()) do
        local amount = business.balance or 0
        if amount > 0 and MySQL.update.await('UPDATE vbiz_businesses SET balance = 0 WHERE id = ? AND balance = ?', { business.id, amount }) == 1 then
            if BankLink.adjust(business, amount, 'Moved from Vanguard Business') then
                business.balance = 0
                Businesses.log(business.id, 'bank', 0, 'Vanguard Bank', ('$%d moved to the bank account'):format(amount))
            else
                MySQL.update.await('UPDATE vbiz_businesses SET balance = balance + ? WHERE id = ?', { amount, business.id })
            end
        end
    end
end

exports('bankRoles', function(citizenid)
    local list = {}
    for businessId, rank in pairs(StaffList.jobsOf(citizenid)) do
        local business = Businesses.get(businessId)
        if business then list[#list + 1] = { id = businessId, name = business.name, rank = rank } end
    end
    return list
end)

exports('noteBankMovement', function(businessId, kind, amount, actor, note)
    if Businesses.get(businessId) then Businesses.log(businessId, 'bank', amount, actor, note or kind) end
end)
