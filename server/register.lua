-- Vanguard Business - cash register bills. One open bill per customer; the customer pays with
-- cash or bank, the business gets the money and the employee who billed gets a commission.

Register = {}

local NOTE_MAX = 60
local bills = Pending.new() -- key: customer server id

local function billerOnline(bill)
    return GetPlayerName(bill.from) ~= nil and Bridge.identifier(bill.from) == bill.fromIdentifier
end

local function tellBiller(bill, message, ok)
    if billerOnline(bill) then Access.notify(bill.from, message, ok) end
end

Router.on('billCreate', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'register', permission = 'register', duty = true })
    if not ctx then return Router.fail(err) end
    local station = ctx.station

    local target = Rules.wholeNumber(data.target, 1, 2 ^ 31)
    if not target or target == src or not GetPlayerName(target) then return Router.fail('Pick a customer') end
    if Access.distanceTo(target, station.x, station.y, station.z) > Config.BillDistance then
        return Router.fail('The customer must be at the register')
    end
    if not Bridge.identifier(target) then return Router.fail('That customer has no character loaded') end

    local amount = Rules.wholeNumber(data.amount, 1, Config.MaxBill)
    if not amount then return Router.fail(('Enter an amount from $1 to $%d'):format(Config.MaxBill)) end
    local note = Rules.cleanText(data.note, NOTE_MAX)

    local bill = {
        businessId = ctx.business.id, businessName = ctx.business.name,
        from = src, fromIdentifier = ctx.identifier, fromName = Bridge.characterName(src),
        amount = amount, note = note,
    }
    local billId = bills:start(target, bill, GetGameTimer(), 0, Config.BillTimeout * 1000)
    if not billId then return Router.fail('That customer already has an open bill') end

    TriggerClientEvent('vanguard-business:bill', target, {
        id = billId, business = bill.businessName, from = bill.fromName,
        amount = amount, note = note, timeout = Config.BillTimeout,
    })
    return Router.ok(('Bill for $%d sent'):format(amount))
end)

Router.on('billAnswer', function(src, data)
    local method = data.method
    if method ~= 'cash' and method ~= 'bank' and method ~= 'decline' then return Router.fail('Pick how to pay') end

    local bill, reason, expired = bills:finish(src, data.billId, GetGameTimer(), 0)
    if not bill then
        if expired then tellBiller(expired, 'The bill expired', false) end
        return Router.fail(expired and 'That bill expired' or 'That bill is no longer open')
    end

    if method == 'decline' then
        tellBiller(bill, ('%s declined the bill'):format(Bridge.characterName(src)), false)
        return Router.ok('Bill declined')
    end

    if not Businesses.get(bill.businessId) then return Router.fail('That business no longer exists') end
    if not Bridge.removeMoney(src, method, bill.amount, 'vanguard-business bill') then
        tellBiller(bill, ('%s couldn\'t pay'):format(Bridge.characterName(src)), false)
        return Router.fail(('You don\'t have $%d in %s'):format(bill.amount, method))
    end

    local share, commission = Rules.splitBill(bill.amount, Config.CommissionPercent)
    if commission == 0 or not billerOnline(bill) or not Bridge.addMoney(bill.from, 'bank', commission, 'vanguard-business commission') then
        share, commission = bill.amount, 0
    end
    Businesses.adjust(bill.businessId, share)
    Businesses.log(bill.businessId, 'sale', share, bill.fromName, bill.note)

    tellBiller(bill, commission > 0
        and ('%s paid $%d (your commission: $%d)'):format(Bridge.characterName(src), bill.amount, commission)
        or ('%s paid $%d'):format(Bridge.characterName(src), bill.amount))
    return Router.ok(('Paid $%d to %s'):format(bill.amount, bill.businessName))
end)

--- A player left: close their own bill, and any bill they sent that is still open.
function Register.drop(src)
    bills:cancel(src)
    local closed = {}
    bills:each(function(customer, bill)
        if bill.from == src then closed[#closed + 1] = customer end
    end)
    for _, customer in ipairs(closed) do
        bills:cancel(customer)
        TriggerClientEvent('vanguard-business:billClosed', customer)
    end
end

CreateThread(function()
    while true do
        Wait(5000)
        for _, entry in ipairs(bills:expire(GetGameTimer())) do
            TriggerClientEvent('vanguard-business:billClosed', entry.key)
            tellBiller(entry.data, 'The bill expired', false)
        end
    end
end)
