-- Vanguard Business - pure rules shared by server, client and tests (no game natives in here).

Rules = {}

Rules.RANK = { TRAINEE = 1, STAFF = 2, MANAGER = 3, OWNER = 4 }

local MAP_LIMIT = 20000.0

local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

--- Whole number within [min, max], else nil. Rejects strings, fractions, NaN and infinities.
function Rules.wholeNumber(value, min, max)
    if not isFinite(value) then return nil end
    local int = math.tointeger(value)
    if not int or int < min or int > max then return nil end
    return int
end

--- Trimmed single-line text of at most maxChars UTF-8 characters, or nil when empty.
function Rules.cleanText(value, maxChars)
    if type(value) ~= 'string' then return nil end
    local text = value:gsub('%c', ' ')
    if not utf8.len(text) then text = text:gsub('[\128-\255]', '') end
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if utf8.len(text) > maxChars then text = text:sub(1, utf8.offset(text, maxChars + 1) - 1) end
    if text == '' then return nil end
    return text
end

--- { x, y, z } of finite numbers inside the map, or nil.
function Rules.coords(value)
    if type(value) ~= 'table' then return nil end
    local x, y, z = value.x, value.y, value.z
    if not (isFinite(x) and isFinite(y) and isFinite(z)) then return nil end
    if math.abs(x) > MAP_LIMIT or math.abs(y) > MAP_LIMIT or math.abs(z) > MAP_LIMIT then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

--- Heading wrapped into [0, 360), or nil.
function Rules.heading(value)
    if not isFinite(value) then return nil end
    return (value % 360) + 0.0
end

function Rules.can(rankPermissions, rank, permission)
    local permissions = rank and rankPermissions[rank]
    return permissions ~= nil and permissions[permission] == true
end

--- Staff may only hire, fire or re-rank people strictly below them.
function Rules.canManage(actorRank, targetRank)
    return actorRank ~= nil and targetRank ~= nil and actorRank > targetRank
end

--- Ranks you can hand out: below your own, and never Owner (only server admins set the Owner).
function Rules.canAssignRank(actorRank, newRank)
    return actorRank ~= nil and newRank ~= nil
        and newRank >= Rules.RANK.TRAINEE and newRank < Rules.RANK.OWNER and newRank < actorRank
end

--- ingredients: { item = perUnit }; counts: { item = have }.
--- Returns the ingredients that fall short for `quantity`, sorted by item: { item, need, have }.
function Rules.missingIngredients(ingredients, quantity, counts)
    local missing = {}
    for item, perUnit in pairs(ingredients) do
        local need, have = perUnit * quantity, counts[item] or 0
        if have < need then missing[#missing + 1] = { item = item, need = need, have = have } end
    end
    table.sort(missing, function(a, b) return a.item < b.item end)
    return missing
end

--- catalog: array of { item, label, price, pack }; cart: array of { item, packs }.
--- Returns total, lines ({ item, packs, amount, cost }) or nil, message.
function Rules.cartTotal(catalog, cart, maxPacks)
    if type(cart) ~= 'table' or #cart == 0 then return nil, 'The cart is empty' end

    local byItem = {}
    for _, entry in ipairs(catalog) do byItem[entry.item] = entry end

    local total, lines, seen = 0, {}, {}
    for _, line in ipairs(cart) do
        local entry = type(line) == 'table' and byItem[line.item] or nil
        if not entry then return nil, 'Unknown item in the cart' end
        if seen[entry.item] then return nil, ('%s is listed twice'):format(entry.label) end
        seen[entry.item] = true

        local packs = Rules.wholeNumber(line.packs, 1, maxPacks)
        if not packs then return nil, ('Pick 1-%d packs of %s'):format(maxPacks, entry.label) end

        local cost = packs * entry.price
        total = total + cost
        lines[#lines + 1] = { item = entry.item, packs = packs, amount = packs * entry.pack, cost = cost }
    end
    return total, lines
end

--- Splits a paid bill: returns the business share and the employee commission (rounded down).
function Rules.splitBill(amount, commissionPercent)
    local commission = amount * commissionPercent // 100
    return amount - commission, commission
end

function Rules.cookTime(recipe, quantity)
    return recipe.time * quantity
end
