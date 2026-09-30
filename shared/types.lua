-- Vanguard Business - business types, stations, recipes, supplier prices and items.
--
-- Make your own business type: copy an entry in BusinessTypes, give it a new id, and list the
-- cooking stations, recipes and supplier items it uses. New food: add it to Products (what it
-- restores) and Recipes (how it is made). New ingredient: add it to Ingredients and SupplierPrices.
-- hunger / thirst: how much one item restores, 0-100 (100 = completely full).

-- Station kinds that can be placed. Cooking stations only cook recipes tagged with their kind.
StationKinds = {
    fridge   = { label = 'Fridge' },
    register = { label = 'Cash register' },
    boss     = { label = 'Boss desk' },
    clockin  = { label = 'Clock-in point' },
    coffee   = { label = 'Coffee machine', cooking = true, scenario = 'PROP_HUMAN_PARKING_METER' },
    grill    = { label = 'Grill',          cooking = true, scenario = 'PROP_HUMAN_BBQ' },
    fryer    = { label = 'Fryer',          cooking = true, scenario = 'PROP_HUMAN_BBQ' },
    oven     = { label = 'Oven',           cooking = true, scenario = 'PROP_HUMAN_PARKING_METER' },
    drinks   = { label = 'Drinks station', cooking = true, scenario = 'PROP_HUMAN_PARKING_METER' },
    prep     = { label = 'Prep counter',   cooking = true, scenario = 'PROP_HUMAN_PARKING_METER' },
}

BusinessTypes = {
    coffee = {
        label = 'Coffee shop', blip = { sprite = 52, colour = 21 },
        stations = { 'coffee', 'drinks', 'prep' },
        recipes = { 'espresso', 'latte', 'cappuccino', 'hot_chocolate', 'green_tea', 'strawberry_shake', 'croissant', 'cheese_toastie' },
        supplier = { 'coffee_beans', 'milk', 'honey', 'tea_leaves', 'cocoa', 'strawberry', 'ice', 'flour', 'butter', 'cheese' },
    },
    catcafe = {
        label = 'Cat café', blip = { sprite = 52, colour = 8 },
        stations = { 'coffee', 'oven', 'drinks' },
        recipes = { 'kitty_latte', 'latte', 'hot_chocolate', 'green_tea', 'strawberry_shake', 'neko_cake', 'cupcake', 'cookie' },
        supplier = { 'coffee_beans', 'milk', 'honey', 'tea_leaves', 'cocoa', 'strawberry', 'ice', 'flour', 'eggs', 'butter' },
    },
    burger = {
        label = 'Burger bar', blip = { sprite = 52, colour = 17 },
        stations = { 'grill', 'fryer', 'drinks', 'prep' },
        recipes = { 'cheeseburger', 'classic_burger', 'fries', 'cola', 'side_salad' },
        supplier = { 'burger_bun', 'beef_patty', 'cheese', 'lettuce', 'tomato', 'potato', 'soda_syrup', 'ice' },
    },
    pizza = {
        label = 'Pizzeria', blip = { sprite = 52, colour = 1 },
        stations = { 'oven', 'drinks' },
        recipes = { 'pizza_margherita', 'pizza_pepperoni', 'garlic_bread', 'lemonade', 'cola' },
        supplier = { 'pizza_dough', 'tomato', 'cheese', 'pepperoni', 'flour', 'butter', 'lemon', 'honey', 'ice', 'soda_syrup' },
    },
    bakery = {
        label = 'Bakery', blip = { sprite = 52, colour = 5 },
        stations = { 'oven', 'prep', 'coffee' },
        recipes = { 'donut', 'cupcake', 'cookie', 'strawberry_cake', 'croissant', 'espresso', 'latte' },
        supplier = { 'flour', 'eggs', 'butter', 'honey', 'cocoa', 'strawberry', 'coffee_beans', 'milk' },
    },
    bar = {
        label = 'Bar', blip = { sprite = 93, colour = 27 },
        stations = { 'drinks' },
        recipes = { 'pint_beer', 'lemonade', 'cola', 'iced_tea', 'virgin_mojito' },
        supplier = { 'malt', 'lemon', 'honey', 'ice', 'tea_leaves', 'soda_syrup' },
    },
}

-- Ingredients (bought from the supplier). emoji = Fluent Emoji picture used for the item image.
Ingredients = {
    coffee_beans = { label = 'Coffee Beans', weight = 100, emoji = 'Chestnut' },
    milk         = { label = 'Milk',         weight = 250, emoji = 'Glass of milk' },
    honey        = { label = 'Honey',        weight = 150, emoji = 'Honey pot' },
    tea_leaves   = { label = 'Tea Leaves',   weight = 50,  emoji = 'Herb' },
    cocoa        = { label = 'Cocoa Powder', weight = 100, emoji = 'Chocolate bar' },
    flour        = { label = 'Flour',        weight = 200, emoji = 'Sheaf of rice' },
    eggs         = { label = 'Eggs',         weight = 60,  emoji = 'Egg' },
    butter       = { label = 'Butter',       weight = 100, emoji = 'Butter' },
    cheese       = { label = 'Cheese',       weight = 100, emoji = 'Cheese wedge' },
    tomato       = { label = 'Tomato',       weight = 100, emoji = 'Tomato' },
    lettuce      = { label = 'Lettuce',      weight = 100, emoji = 'Leafy green' },
    burger_bun   = { label = 'Burger Bun',   weight = 80,  emoji = 'Bread' },
    beef_patty   = { label = 'Beef Patty',   weight = 150, emoji = 'Cut of meat' },
    potato       = { label = 'Potato',       weight = 150, emoji = 'Potato' },
    pizza_dough  = { label = 'Pizza Dough',  weight = 250, emoji = 'Flatbread' },
    pepperoni    = { label = 'Pepperoni',    weight = 100, emoji = 'Bacon' },
    ice          = { label = 'Ice',          weight = 100, emoji = 'Ice' },
    lemon        = { label = 'Lemon',        weight = 80,  emoji = 'Lemon' },
    strawberry   = { label = 'Strawberries', weight = 80,  emoji = 'Strawberry' },
    soda_syrup   = { label = 'Soda Syrup',   weight = 200, emoji = 'Beverage box' },
    malt         = { label = 'Brewing Malt', weight = 200, emoji = 'Clinking beer mugs' },
}

-- Supplier price per pack (business money) and how many items one pack holds.
SupplierPrices = {
    coffee_beans = { price = 40, pack = 10 }, milk = { price = 20, pack = 10 }, honey = { price = 25, pack = 10 },
    tea_leaves = { price = 20, pack = 10 }, cocoa = { price = 25, pack = 10 }, flour = { price = 15, pack = 10 },
    eggs = { price = 20, pack = 12 }, butter = { price = 20, pack = 10 }, cheese = { price = 25, pack = 10 },
    tomato = { price = 15, pack = 10 }, lettuce = { price = 15, pack = 10 }, burger_bun = { price = 20, pack = 10 },
    beef_patty = { price = 50, pack = 10 }, potato = { price = 20, pack = 20 }, pizza_dough = { price = 30, pack = 10 },
    pepperoni = { price = 35, pack = 10 }, ice = { price = 10, pack = 20 }, lemon = { price = 15, pack = 10 },
    strawberry = { price = 25, pack = 10 }, soda_syrup = { price = 25, pack = 10 }, malt = { price = 40, pack = 10 },
}

-- Food and drink. kind: 'food' | 'drink'; prop: key of ConsumeProps; hunger / thirst: 0-100 restored.
Products = {
    espresso         = { label = 'Espresso',         weight = 150, kind = 'drink', thirst = 20,              prop = 'cup',      emoji = 'Hot beverage' },
    latte            = { label = 'Latte',            weight = 250, kind = 'drink', thirst = 35,              prop = 'cup',      emoji = 'Teacup without handle' },
    cappuccino       = { label = 'Cappuccino',       weight = 250, kind = 'drink', thirst = 30,              prop = 'cup',      emoji = 'Hot beverage' },
    hot_chocolate    = { label = 'Hot Chocolate',    weight = 250, kind = 'drink', thirst = 35, hunger = 5,  prop = 'cup',      emoji = 'Mate' },
    green_tea        = { label = 'Green Tea',        weight = 250, kind = 'drink', thirst = 40,              prop = 'cup',      emoji = 'Teacup without handle' },
    strawberry_shake = { label = 'Strawberry Shake', weight = 300, kind = 'drink', thirst = 60, hunger = 20, prop = 'cup',      emoji = 'Bubble tea' },
    kitty_latte      = { label = 'Kitty Latte',      weight = 250, kind = 'drink', thirst = 45, hunger = 5,  prop = 'cup',      emoji = 'Cat face' },
    croissant        = { label = 'Croissant',        weight = 100, kind = 'food',  hunger = 25,              prop = 'sandwich', emoji = 'Croissant' },
    cheese_toastie   = { label = 'Cheese Toastie',   weight = 200, kind = 'food',  hunger = 35,              prop = 'sandwich', emoji = 'Sandwich' },
    cheeseburger     = { label = 'Cheeseburger',     weight = 300, kind = 'food',  hunger = 45,              prop = 'burger',   emoji = 'Hamburger' },
    classic_burger   = { label = 'Classic Burger',   weight = 320, kind = 'food',  hunger = 70,              prop = 'burger',   emoji = 'Hamburger' },
    fries            = { label = 'Fries',            weight = 150, kind = 'food',  hunger = 25,              prop = 'chips',    emoji = 'French fries' },
    cola             = { label = 'Cola',             weight = 350, kind = 'drink', thirst = 35,              prop = 'cup',      emoji = 'Cup with straw' },
    side_salad       = { label = 'Side Salad',       weight = 150, kind = 'food',  hunger = 15, thirst = 5,  prop = 'sandwich', emoji = 'Green salad' },
    pizza_margherita = { label = 'Pizza Margherita', weight = 400, kind = 'food',  hunger = 60,              prop = 'sandwich', emoji = 'Pizza' },
    pizza_pepperoni  = { label = 'Pepperoni Pizza',  weight = 420, kind = 'food',  hunger = 100,             prop = 'sandwich', emoji = 'Pizza' },
    garlic_bread     = { label = 'Garlic Bread',     weight = 150, kind = 'food',  hunger = 20,              prop = 'sandwich', emoji = 'Baguette bread' },
    lemonade         = { label = 'Lemonade',         weight = 350, kind = 'drink', thirst = 100,             prop = 'cup',      emoji = 'Tumbler glass' },
    donut            = { label = 'Donut',            weight = 100, kind = 'food',  hunger = 20,              prop = 'donut',    emoji = 'Doughnut' },
    cupcake          = { label = 'Cupcake',          weight = 100, kind = 'food',  hunger = 20,              prop = 'donut',    emoji = 'Cupcake' },
    cookie           = { label = 'Cookie',           weight = 60,  kind = 'food',  hunger = 15,              prop = 'donut',    emoji = 'Cookie' },
    strawberry_cake  = { label = 'Strawberry Cake',  weight = 400, kind = 'food',  hunger = 100,             prop = 'sandwich', emoji = 'Shortcake' },
    neko_cake        = { label = 'Neko Cake',        weight = 300, kind = 'food',  hunger = 50,              prop = 'donut',    emoji = 'Birthday cake' },
    iced_tea         = { label = 'Iced Tea',         weight = 350, kind = 'drink', thirst = 100,             prop = 'cup',      emoji = 'Tropical drink' },
    pint_beer        = { label = 'Pint of Beer',     weight = 500, kind = 'drink', thirst = 30,              prop = 'beer',     emoji = 'Beer mug' },
    virgin_mojito    = { label = 'Virgin Mojito',    weight = 350, kind = 'drink', thirst = 50,              prop = 'cup',      emoji = 'Cocktail glass' },
}

-- How each product is made: station kind, ms per item, items made per cook, ingredients per item.
Recipes = {
    espresso         = { station = 'coffee', time = 4000, amount = 1, ingredients = { coffee_beans = 1 } },
    latte            = { station = 'coffee', time = 5000, amount = 1, ingredients = { coffee_beans = 1, milk = 1 } },
    cappuccino       = { station = 'coffee', time = 5000, amount = 1, ingredients = { coffee_beans = 2, milk = 1 } },
    hot_chocolate    = { station = 'coffee', time = 5000, amount = 1, ingredients = { cocoa = 1, milk = 1 } },
    green_tea        = { station = 'coffee', time = 4000, amount = 1, ingredients = { tea_leaves = 1, honey = 1 } },
    kitty_latte      = { station = 'coffee', time = 6000, amount = 1, ingredients = { coffee_beans = 1, milk = 1, honey = 1 } },
    strawberry_shake = { station = 'drinks', time = 5000, amount = 1, ingredients = { strawberry = 2, milk = 1, ice = 1 } },
    croissant        = { station = 'prep',   time = 5000, amount = 1, ingredients = { flour = 1, butter = 1 } },
    cheese_toastie   = { station = 'prep',   time = 6000, amount = 1, ingredients = { flour = 1, cheese = 1, butter = 1 } },
    cheeseburger     = { station = 'grill',  time = 7000, amount = 1, ingredients = { burger_bun = 1, beef_patty = 1, cheese = 1 } },
    classic_burger   = { station = 'grill',  time = 8000, amount = 1, ingredients = { burger_bun = 1, beef_patty = 1, lettuce = 1, tomato = 1 } },
    fries            = { station = 'fryer',  time = 5000, amount = 1, ingredients = { potato = 2 } },
    cola             = { station = 'drinks', time = 3000, amount = 1, ingredients = { soda_syrup = 1, ice = 1 } },
    side_salad       = { station = 'prep',   time = 4000, amount = 1, ingredients = { lettuce = 1, tomato = 1 } },
    pizza_margherita = { station = 'oven',   time = 9000, amount = 1, ingredients = { pizza_dough = 1, tomato = 1, cheese = 1 } },
    pizza_pepperoni  = { station = 'oven',   time = 10000, amount = 1, ingredients = { pizza_dough = 1, tomato = 1, cheese = 1, pepperoni = 1 } },
    garlic_bread     = { station = 'oven',   time = 5000, amount = 1, ingredients = { flour = 1, butter = 1 } },
    lemonade         = { station = 'drinks', time = 4000, amount = 1, ingredients = { lemon = 2, honey = 1, ice = 1 } },
    donut            = { station = 'oven',   time = 6000, amount = 1, ingredients = { flour = 1, honey = 1, eggs = 1 } },
    cupcake          = { station = 'oven',   time = 6000, amount = 1, ingredients = { flour = 1, eggs = 1, butter = 1 } },
    cookie           = { station = 'oven',   time = 5000, amount = 1, ingredients = { flour = 1, cocoa = 1, butter = 1 } },
    strawberry_cake  = { station = 'oven',   time = 10000, amount = 1, ingredients = { flour = 2, eggs = 2, strawberry = 2, butter = 1 } },
    neko_cake        = { station = 'oven',   time = 8000, amount = 1, ingredients = { flour = 1, eggs = 1, strawberry = 1, cocoa = 1 } },
    iced_tea         = { station = 'drinks', time = 4000, amount = 1, ingredients = { tea_leaves = 1, lemon = 1, ice = 1 } },
    pint_beer        = { station = 'drinks', time = 3000, amount = 1, ingredients = { malt = 2 } },
    virgin_mojito    = { station = 'drinks', time = 5000, amount = 1, ingredients = { lemon = 1, honey = 1, ice = 1, tea_leaves = 1 } },
}

-- Props held while eating / drinking, and the animations used.
ConsumeProps = {
    cup = 'p_amb_coffeecup_01', burger = 'prop_cs_burger_01', sandwich = 'prop_sandwich_01',
    donut = 'prop_amb_donut', chips = 'prop_food_bs_chips', beer = 'prop_amb_beer_bottle',
}

ConsumeAnims = {
    food = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' },
    drink = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
}

-- Item pictures default to images/vb_<item>.png (set image = '...' on an entry to use another file).
for id, item in pairs(Products) do item.image = item.image or ('vb_%s.png'):format(id) end
for id, item in pairs(Ingredients) do item.image = item.image or ('vb_%s.png'):format(id) end

-- ---------------------------------------------------------------------------
-- Helpers (pure)
-- ---------------------------------------------------------------------------
Types = {}

local function itemDef(item) return Products[item] or Ingredients[item] end

function Types.itemLabel(item)
    local def = itemDef(item)
    return def and def.label or item
end

function Types.itemImage(item)
    local def = itemDef(item)
    return def and def.image or (item .. '.png')
end

--- Supplier catalogue of a type: array of { item, label, price, pack, image }.
function Types.catalog(typeId)
    local list = {}
    local businessType = BusinessTypes[typeId]
    if not businessType then return list end
    for _, item in ipairs(businessType.supplier) do
        local price = SupplierPrices[item]
        if price then
            list[#list + 1] = { item = item, label = Types.itemLabel(item), price = price.price, pack = price.pack, image = Types.itemImage(item) }
        end
    end
    return list
end

function Types.hasRecipe(typeId, recipeId)
    local businessType = BusinessTypes[typeId]
    if not businessType then return false end
    for _, id in ipairs(businessType.recipes) do
        if id == recipeId then return true end
    end
    return false
end

--- Recipes of a type cooked at one station kind: array of { id, label, time, amount, ingredients, image }.
function Types.recipesFor(typeId, stationKind)
    local list = {}
    local businessType = BusinessTypes[typeId]
    if not businessType then return list end
    for _, id in ipairs(businessType.recipes) do
        local recipe = Recipes[id]
        if recipe and recipe.station == stationKind then
            list[#list + 1] = {
                id = id, label = Types.itemLabel(id), time = recipe.time, amount = recipe.amount,
                ingredients = recipe.ingredients, image = Types.itemImage(id),
            }
        end
    end
    return list
end

--- Station kinds the placement tool offers for a type, in order.
function Types.placeableKinds(typeId)
    local kinds = { 'fridge' }
    local businessType = BusinessTypes[typeId]
    for _, kind in ipairs(businessType and businessType.stations or {}) do kinds[#kinds + 1] = kind end
    for _, kind in ipairs({ 'register', 'boss', 'clockin' }) do kinds[#kinds + 1] = kind end
    return kinds
end
