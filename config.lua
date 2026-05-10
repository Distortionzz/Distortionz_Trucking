Config = {}

Config.Script = {
    name    = 'Distortionz Trucking',
    version = '1.1.3',
}

Config.Debug = false

-- ─── Notify integration ─────────────────────────────────────────────
Config.Notify = {
    resource      = 'distortionz_notify',
    title         = 'Trucking',
    defaultLength = 5000,
}

-- ─── Version checker ────────────────────────────────────────────────
Config.VersionCheck = {
    enabled     = true,
    checkOnStart = true,
    url         = 'https://raw.githubusercontent.com/Distortionzz/Distortionz_Trucking/main/version.json',
}
Config.CurrentVersion = '1.1.3'

-- ─── Depot ──────────────────────────────────────────────────────────
-- Where players go to start a trucking run. Default: industrial area
-- behind the LSIA / Cypress Flats freight depot.
Config.Depot = {
    coords = vec4(930.52, -2267.17, 29.51, 90.0),
    model  = 's_m_y_construct_01',
    scenario = 'WORLD_HUMAN_CLIPBOARD',

    targetLabel = 'Talk to Dispatcher',
    targetIcon  = 'fa-solid fa-truck',

    blip = {
        enabled = true,
        sprite  = 477,
        color   = 5,
        scale   = 0.85,
        label   = 'Trucking Depot',
    },
}

-- ─── Truck + Trailer spawn ──────────────────────────────────────────
-- Truck spawns at this spot. Trailer spawns separately and player
-- must back into it to attach.
Config.Spawn = {
    truck   = vec4(924.32, -2270.51, 29.35, 352.77),
    trailer = vec4(922.56, -2288.79, 29.35, 352.43),

    truckModel   = 'phantom',
    trailerModel = 'trailers',

    spawnRadius = 5.0, -- if a vehicle is already this close, abort spawn
}

-- ─── Cargo tiers ────────────────────────────────────────────────────
-- Each tier has a weighted pickup chance, a payout, and a list of
-- possible dropoff zones (use the index of Config.Dropoffs).
Config.Cargo = {
    {
        id          = 'food',
        label       = 'Food Supplies',
        description = 'Perishable goods. Standard freight run.',
        weight      = 50,         -- % chance weight
        basePay     = 350,
        damagePenalty = 0.7,      -- multiplier applied if trailer health < 700
        color       = 'success',  -- notify color
        icon        = '🥫',
    },
    {
        id          = 'electronics',
        label       = 'Electronics',
        description = 'Fragile cargo. Drive carefully — damage hits your pay.',
        weight      = 30,
        basePay     = 600,
        damagePenalty = 0.5,
        color       = 'info',
        icon        = '📦',
    },
    {
        id          = 'hazmat',
        label       = 'Hazardous Materials',
        description = 'High-risk cargo. Top dollar, but watch the cops.',
        weight      = 15,
        basePay     = 950,
        damagePenalty = 0.4,
        color       = 'warning',
        icon        = '☣️',
    },
    {
        id          = 'classified',
        label       = 'Classified Freight',
        description = 'No questions asked. Highest payout in the depot.',
        weight      = 5,
        basePay     = 1500,
        damagePenalty = 0.3,
        color       = 'error',
        icon        = '🔒',
    },
}

-- ─── Dropoffs ───────────────────────────────────────────────────────
Config.Dropoffs = {
    { coords = vec4(154.20, 6633.90, 31.40, 270.0),  label = 'Paleto Bay Warehouse' },
    { coords = vec4(2685.10, 1525.40, 24.50, 0.0),   label = 'Sandy Shores Storage' },
    { coords = vec4(1208.80, -3115.30, 5.50, 90.0),  label = 'LSIA Freight Hub' },
    { coords = vec4(-432.80, 6080.30, 31.40, 315.0), label = 'Paleto Distribution' },
    { coords = vec4(2425.90, 4954.40, 41.80, 95.0),  label = 'Grapeseed Depot' },
    { coords = vec4(40.10, 6390.10, 31.20, 165.0),   label = 'Mount Chiliad Outpost' },
    { coords = vec4(-1145.30, -1992.80, 13.20, 320.0), label = 'Vespucci Cargo' },
    { coords = vec4(1395.00, -2069.40, 51.10, 318.0), label = 'Cypress Flats Yard' },
}

-- ─── Job timing ─────────────────────────────────────────────────────
Config.Job = {
    timeLimitSeconds         = 900,   -- 15 minutes
    minDropoffSpeed          = 8.0,   -- mph max for trigger
    trailerDamageThreshold   = 700.0, -- below this = damage penalty
    abandonDistance          = 150.0, -- if player walks this far from trailer = abandon
    cooldownAfterDeliverySec = 30,    -- between runs
}

-- ─── Cargo manifest item (RP touch) ─────────────────────────────────
-- Server gives the player an ox_inventory item with cargo details when
-- the run starts. The player can show it to police if pulled over.
-- Removed automatically on delivery, abandonment, or cancellation.
--
-- REQUIRED: add this entry to ox_inventory/data/items.lua first:
--   ['cargo_manifest'] = {
--       label       = 'Cargo Manifest',
--       weight      = 50,
--       stack       = false,
--       close       = true,
--       description = 'Official freight manifest paperwork.',
--   },
Config.Manifest = {
    enabled  = true,
    itemName = 'cargo_manifest',
}

-- ─── Police alerts ──────────────────────────────────────────────────
Config.Police = {
    jobNames        = { 'police', 'sheriff', 'sasp' },
    -- Hazmat / classified runs may trigger a routine inspection alert
    alertChance = {
        food        = 0,    -- never
        electronics = 0,    -- never
        hazmat      = 12,   -- 12% on pickup
        classified  = 25,   -- 25% on pickup
    },
}
