local T = require('tests.lib.t')
Config = {}
dofile(ROOT .. '/config.lua')
dofile(ROOT .. '/shared/types.lua')

local function contains(list, value)
    for _, entry in ipairs(list) do if entry == value then return true end end
    return false
end

T.describe('default data', function()
    T.it('every business type is complete', function()
        for id, businessType in pairs(BusinessTypes) do
            T.eq(type(businessType.label), 'string', id .. ' label')
            T.eq(type(businessType.blip.sprite), 'number', id .. ' blip sprite')
            T.eq(type(businessType.blip.colour), 'number', id .. ' blip colour')
            T.eq(#businessType.stations > 0, true, id .. ' stations')
            T.eq(#businessType.recipes > 0, true, id .. ' recipes')
            T.eq(#businessType.supplier > 0, true, id .. ' supplier')
        end
    end)

    T.it('type stations are cooking stations and each one has a recipe', function()
        for id, businessType in pairs(BusinessTypes) do
            for _, kind in ipairs(businessType.stations) do
                T.eq(StationKinds[kind] ~= nil and StationKinds[kind].cooking, true, id .. ' station ' .. kind)
                T.eq(#Types.recipesFor(id, kind) > 0, true, id .. ' has nothing to cook at ' .. kind)
            end
        end
    end)

    T.it('every recipe of a type can be cooked there and bought from its supplier', function()
        for id, businessType in pairs(BusinessTypes) do
            for _, recipeId in ipairs(businessType.recipes) do
                local recipe = Recipes[recipeId]
                T.eq(recipe ~= nil, true, id .. ' recipe ' .. recipeId)
                T.eq(contains(businessType.stations, recipe.station), true, id .. ' has no ' .. recipe.station .. ' for ' .. recipeId)
                for item in pairs(recipe.ingredients) do
                    T.eq(contains(businessType.supplier, item), true, id .. ' supplier lacks ' .. item .. ' for ' .. recipeId)
                end
            end
        end
    end)

    T.it('recipes are well formed', function()
        for id, recipe in pairs(Recipes) do
            T.eq(Products[id] ~= nil, true, id .. ' product')
            T.eq(math.tointeger(recipe.time) ~= nil and recipe.time > 0, true, id .. ' time')
            T.eq(math.tointeger(recipe.amount) ~= nil and recipe.amount > 0, true, id .. ' amount')
            for item, count in pairs(recipe.ingredients) do
                T.eq(Ingredients[item] ~= nil, true, id .. ' ingredient ' .. item)
                T.eq(math.tointeger(count) ~= nil and count > 0, true, id .. ' count ' .. item)
            end
        end
    end)

    T.it('supplier items are priced ingredients', function()
        for id, businessType in pairs(BusinessTypes) do
            for _, item in ipairs(businessType.supplier) do
                T.eq(Ingredients[item] ~= nil, true, id .. ' supplier ' .. item)
                T.eq(SupplierPrices[item] ~= nil, true, id .. ' price ' .. item)
            end
        end
    end)

    T.it('products and ingredients have what the inventory and eating need', function()
        for id, product in pairs(Products) do
            T.eq(product.kind == 'food' or product.kind == 'drink', true, id .. ' kind')
            T.eq(ConsumeProps[product.prop] ~= nil, true, id .. ' prop')
            T.eq((product.hunger or 0) >= 0 and (product.hunger or 0) <= 100, true, id .. ' hunger')
            T.eq((product.thirst or 0) >= 0 and (product.thirst or 0) <= 100, true, id .. ' thirst')
            T.eq(type(product.emoji), 'string', id .. ' emoji')
            T.eq(product.image, ('vb_%s.png'):format(id), id .. ' image')
            T.eq(math.tointeger(product.weight) ~= nil, true, id .. ' weight')
        end
        for id, ingredient in pairs(Ingredients) do
            T.eq(type(ingredient.emoji), 'string', id .. ' emoji')
            T.eq(ingredient.image, ('vb_%s.png'):format(id), id .. ' image')
            T.eq(Products[id], nil, id .. ' is both a product and an ingredient')
        end
    end)
end)

T.describe('Types helpers', function()
    T.it('placeableKinds lists fridge, the cooking stations, then register, boss and clock-in', function()
        T.eq(Types.placeableKinds('coffee'), { 'fridge', 'coffee', 'drinks', 'prep', 'register', 'boss', 'clockin' })
        T.eq(Types.placeableKinds('nope'), { 'fridge', 'register', 'boss', 'clockin' })
    end)

    T.it('catalog carries label, price, pack and picture', function()
        local first = Types.catalog('coffee')[1]
        T.eq(first, { item = 'coffee_beans', label = 'Coffee Beans', price = 40, pack = 10, image = 'vb_coffee_beans.png' })
        T.eq(Types.catalog('nope'), {})
    end)

    T.it('recipesFor filters by station', function()
        for _, recipe in ipairs(Types.recipesFor('burger', 'fryer')) do T.eq(recipe.id, 'fries') end
        T.eq(Types.recipesFor('nope', 'grill'), {})
    end)

    T.it('hasRecipe checks the type menu', function()
        T.eq(Types.hasRecipe('burger', 'fries'), true)
        T.eq(Types.hasRecipe('coffee', 'fries'), false)
        T.eq(Types.hasRecipe('nope', 'fries'), false)
    end)

    T.it('itemLabel falls back to the item name', function()
        T.eq(Types.itemLabel('latte'), 'Latte')
        T.eq(Types.itemLabel('unknown_item'), 'unknown_item')
    end)
end)
