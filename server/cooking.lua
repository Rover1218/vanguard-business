-- Vanguard Business - cooking. Ingredients are taken when cooking starts and the food is given
-- only after the full time has passed at the station; anything interrupted is given back.

Cooking = {}

local FINISH_TOLERANCE_MS = 750
local EXPIRE_AFTER_MS = 60000
local jobs = Pending.new() -- key: server id

--- Returns taken ingredients to the player, or to the business fridge if they can't carry them.
local function giveBack(src, job)
    local station = Stations.get(job.stationId)
    local stashId = Businesses.get(job.businessId) and Businesses.stashId(job.businessId) or nil
    for item, amount in pairs(job.taken) do
        local returned = src and Bridge.addItem(src, item, amount)
        if not returned and stashId then returned = Bridge.addItem(stashId, item, amount) end
        if not returned then
            print(('[vanguard-business] could not return %dx %s from station %s'):format(amount, item, tostring(station and station.id)))
        end
    end
end

Router.on('cookData', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'cooking', permission = 'cook', duty = true })
    if not ctx then return Router.fail(err) end

    local recipes = Types.recipesFor(ctx.business.type, ctx.station.kind)
    local counts, labels = {}, {}
    for _, recipe in ipairs(recipes) do
        for item in pairs(recipe.ingredients) do
            if counts[item] == nil then
                counts[item] = Bridge.itemCount(src, item)
                labels[item] = Types.itemLabel(item)
            end
        end
    end
    return Router.ok(nil, {
        stationId = ctx.station.id,
        station = StationKinds[ctx.station.kind].label,
        business = ctx.business.name,
        recipes = recipes, counts = counts, labels = labels,
        maxQuantity = Config.MaxCookQuantity,
    })
end)

Router.on('cookStart', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'cooking', permission = 'cook', duty = true })
    if not ctx then return Router.fail(err) end
    if jobs:get(src) then return Router.fail('You are already cooking') end

    local recipeId = type(data.recipe) == 'string' and data.recipe or ''
    local recipe = Recipes[recipeId]
    if not recipe or recipe.station ~= ctx.station.kind or not Types.hasRecipe(ctx.business.type, recipeId) then
        return Router.fail('Unknown recipe')
    end
    local quantity = Rules.wholeNumber(data.quantity, 1, Config.MaxCookQuantity)
    if not quantity then return Router.fail(('Pick 1-%d'):format(Config.MaxCookQuantity)) end

    local counts = {}
    for item in pairs(recipe.ingredients) do counts[item] = Bridge.itemCount(src, item) end
    local missing = Rules.missingIngredients(recipe.ingredients, quantity, counts)
    if #missing > 0 then
        local short = missing[1]
        return Router.fail(('You need %d more %s'):format(short.need - short.have, Types.itemLabel(short.item)))
    end

    local taken = {}
    for item, perUnit in pairs(recipe.ingredients) do
        if not Bridge.removeItem(src, item, perUnit * quantity) then
            giveBack(src, { stationId = ctx.station.id, businessId = ctx.business.id, taken = taken })
            return Router.fail('Could not take the ingredients')
        end
        taken[item] = perUnit * quantity
    end

    local duration = Rules.cookTime(recipe, quantity)
    local job = { recipe = recipeId, quantity = quantity, stationId = ctx.station.id, businessId = ctx.business.id, taken = taken }
    local jobId = jobs:start(src, job, GetGameTimer(), duration, duration + EXPIRE_AFTER_MS)
    return Router.ok(nil, {
        jobId = jobId, duration = duration,
        scenario = StationKinds[ctx.station.kind].scenario,
        label = ('Making %dx %s'):format(quantity * recipe.amount, Types.itemLabel(recipeId)),
    })
end)

Router.on('cookFinish', function(src, data)
    local job, reason, expired = jobs:finish(src, data.jobId, GetGameTimer(), FINISH_TOLERANCE_MS)
    if not job then
        if reason == 'too_early' then return Router.fail('Not done yet') end
        if expired then giveBack(src, expired) return Router.fail('Took too long - ingredients returned') end
        return Router.fail('You are not cooking anything')
    end

    local station = Stations.get(job.stationId)
    if not station or Access.distanceTo(src, station.x, station.y, station.z) > Config.InteractDistance + 1.5 then
        giveBack(src, job)
        return Router.fail('You left the station - ingredients returned')
    end

    local amount = Recipes[job.recipe].amount * job.quantity
    local label = Types.itemLabel(job.recipe)
    if Bridge.addItem(src, job.recipe, amount) then return Router.ok(('Made %dx %s'):format(amount, label)) end
    if Businesses.get(job.businessId) and Bridge.addItem(Businesses.stashId(job.businessId), job.recipe, amount) then
        return Router.ok(('Your pockets are full - %dx %s went into the fridge'):format(amount, label))
    end
    giveBack(src, job)
    return Router.fail(('No room for the %s - ingredients returned'):format(label))
end)

Router.on('cookCancel', function(src)
    local job = jobs:cancel(src)
    if not job then return Router.ok() end
    giveBack(src, job)
    return Router.ok('Cancelled - ingredients returned')
end)

--- Player left: ingredients go into the fridge (the player's inventory is already saved).
function Cooking.drop(src)
    local job = jobs:cancel(src)
    if job then giveBack(nil, job) end
end

CreateThread(function()
    while true do
        Wait(30000)
        for _, entry in ipairs(jobs:expire(GetGameTimer())) do
            giveBack(GetPlayerName(entry.key) and entry.key or nil, entry.data)
        end
    end
end)
