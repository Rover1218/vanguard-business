Config = {}

-- ---------------------------------------------------------------------------
-- General
-- ---------------------------------------------------------------------------
Config.Brand = { Title = 'VANGUARD', Subtitle = 'BUSINESS', Accent = '#f59e0b' }

Config.Command = 'business'                -- /business: your jobs, and the admin panel for admins
Config.AdminAce = 'vanguard.business.admin' -- server.cfg: add_ace group.admin vanguard.business.admin allow
Config.OwnersCanPlace = false              -- true = business Owners may place their own stations

Config.UseTarget = true        -- stations: ox_target / qb-target (Left Alt) when running; false = [E] prompts
Config.DoorsUseTarget = false  -- doors: false = walk up and press E to lock / unlock; true = third-eye
Config.PromptKey = 38          -- E, for station prompts
Config.DoorKey = 38            -- E, for doors

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
Config.MaxStationsPerBusiness = 40
Config.MaxDoorsPerBusiness = 20
Config.OwnerDoorRadius = 40.0   -- Owners (when allowed to place) may only add doors this close to their own stations
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

-- Paychecks: every IntervalMinutes on shift (clocked in), each employee gets their rank's amount in
-- the bank. FromBusiness = true pays it out of the business account (skipped, with a message, when
-- the business can't afford it); false = the server pays it (free money, like a city job).
Config.Paycheck = {
    Enabled = true,
    IntervalMinutes = 15,
    FromBusiness = true,
    Amounts = {
        [1] = 1500, -- Trainee
        [2] = 2000, -- Staff
        [3] = 3000, -- Manager
        [4] = 4000, -- Owner
    },
}

Config.RankPermissions = {
    [1] = { cook = true, fridge = true, doors = true },
    [2] = { cook = true, fridge = true, doors = true, register = true },
    [3] = { cook = true, fridge = true, doors = true, register = true, supplier = true, hire = true, log = true },
    [4] = { cook = true, fridge = true, doors = true, register = true, supplier = true, hire = true, log = true, withdraw = true },
}
