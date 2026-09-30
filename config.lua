Config = {}

-- ---------------------------------------------------------------------------
-- General
-- ---------------------------------------------------------------------------
Config.Brand = { Title = 'VANGUARD', Subtitle = 'BUSINESS', Accent = '#f59e0b' }

Config.Command = 'business'                -- /business: your jobs, and the admin panel for admins
Config.AdminAce = 'vanguard.business.admin' -- server.cfg: add_ace group.admin vanguard.business.admin allow
Config.OwnersCanPlace = false              -- true = business Owners may place their own stations

Config.UseTarget = true -- use ox_target / qb-target (Left Alt) when running; false = always [E] prompts
Config.PromptKey = 38   -- E, for the [E] prompts

-- ---------------------------------------------------------------------------
-- Rules
-- ---------------------------------------------------------------------------
Config.RequireDuty = true       -- must be clocked in to cook, open the fridge or use the register
Config.InteractDistance = 2.0   -- metres from a station or door
Config.BillDistance = 5.0       -- customer must be this close to the register
Config.BillTimeout = 60         -- seconds a customer has to answer a bill
Config.MaxBill = 50000
Config.CommissionPercent = 10   -- share of each paid bill for the employee who made it
Config.MaxTransaction = 1000000 -- max single deposit / withdraw
Config.MaxStaff = 30
Config.MaxBusinesses = 100
Config.MaxCookQuantity = 10
Config.MaxPacksPerLine = 50
Config.Stash = { slots = 50, weight = 250000 } -- fridge size (weight in grams)
Config.ConsumeTime = 5000       -- ms to eat / drink (QBCore + qb-inventory; ox_inventory uses its item settings)

-- ---------------------------------------------------------------------------
-- Ranks (fixed four; rename them freely)
-- Permissions: cook, fridge, doors, register, supplier, hire (hire / fire / re-rank lower ranks),
-- log (see the balance and money log), withdraw. Every staff member may deposit.
-- ---------------------------------------------------------------------------
Config.Ranks = {
    { label = 'Trainee' },
    { label = 'Staff' },
    { label = 'Manager' },
    { label = 'Owner' },
}

Config.RankPermissions = {
    [1] = { cook = true, fridge = true, doors = true },
    [2] = { cook = true, fridge = true, doors = true, register = true },
    [3] = { cook = true, fridge = true, doors = true, register = true, supplier = true, hire = true, log = true },
    [4] = { cook = true, fridge = true, doors = true, register = true, supplier = true, hire = true, log = true, withdraw = true },
}
