-- =====================================================================
--  Distortionz Trucking · server.lua
-- =====================================================================

local activeJobs = {}    -- src -> { cargo, dropoff, startedAt }
local cooldowns  = {}    -- src -> os.time when next allowed

local function Debug(msg)
    if Config.Debug then print(('[distortionz_trucking] %s'):format(msg)) end
end

-- ─── Notify helper ──────────────────────────────────────────────────

local function Notify(src, message, notifyType, duration, title)
    notifyType = notifyType or 'primary'
    duration   = tonumber(duration) or Config.Notify.defaultLength
    title      = title or Config.Notify.title

    if notifyType == 'inform' then notifyType = 'info' end

    if GetResourceState(Config.Notify.resource) == 'started' then
        TriggerClientEvent('distortionz_notify:client:notify', src, {
            title    = title,
            message  = message,
            type     = notifyType,
            duration = duration,
        })
        return
    end

    if GetResourceState('ox_lib') == 'started' then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = title,
            description = message,
            type        = notifyType,
            duration    = duration,
        })
    end
end

-- ─── Helpers ────────────────────────────────────────────────────────

local function PickCargo()
    local total = 0
    for _, c in ipairs(Config.Cargo) do total = total + (c.weight or 1) end

    local roll = math.random() * total
    local acc = 0
    for _, c in ipairs(Config.Cargo) do
        acc = acc + (c.weight or 1)
        if roll <= acc then return c end
    end
    return Config.Cargo[#Config.Cargo]
end

local function PickDropoff()
    return Config.Dropoffs[math.random(1, #Config.Dropoffs)]
end

local function CooldownLeft(src)
    if not cooldowns[src] then return 0 end
    local left = cooldowns[src] - os.time()
    return left > 0 and left or 0
end

local function MaybePoliceAlert(coords, cargoId, label)
    local chance = Config.Police.alertChance[cargoId] or 0
    if chance <= 0 then return end
    if math.random(1, 100) > chance then return end

    -- Send to all on-duty cops (filtered client-side by job)
    TriggerClientEvent('distortionz_trucking:client:policeAlert', -1, {
        coords = { x = coords.x, y = coords.y, z = coords.z },
        label  = label,
    })
end

-- ─── Manifest helpers ───────────────────────────────────────────────

local function GenerateManifestId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local out = ''
    for _ = 1, 6 do
        local i = math.random(1, #chars)
        out = out .. chars:sub(i, i)
    end
    return 'DZ-FRT-' .. out
end

local function GenerateContainerNumber()
    -- ISO 6346-style format: 4 letters + 7 digits (e.g., MSCU1234567)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local out = ''
    for _ = 1, 4 do
        local i = math.random(1, #chars)
        out = out .. chars:sub(i, i)
    end
    out = out .. tostring(math.random(1000000, 9999999))
    return out
end

local SHIPPERS = {
    'Maze Bank Logistics',
    'Los Santos Customs Freight',
    'Vinewood Imports Inc.',
    'Bilkinton Research',
    'Redwood Cigarettes Co.',
    'Cluckin\' Bell Distribution',
    'Sprunk Beverage Co.',
    'Whiz Wireless',
    'Globe Oil',
    'Fleeca Trade Co.',
}

local CONSIGNEES = {
    'Ammu-Nation Wholesale',
    'Burger Shot Supply Chain',
    'Pisswasser Brewing',
    'Schlongberg Sachs',
    'Bean Machine Coffee Co.',
    'Discount Store Group',
    'Up-n-Atom Burger Inc.',
    'eCola Distribution',
    'Liberty Tree Imports',
    'Heritage Holdings LLC',
}

local function PickRandom(t)
    return t[math.random(1, #t)]
end

local function GenerateWeight(cargoId)
    -- Realistic weight ranges per cargo type (in kg)
    if cargoId == 'food'        then return math.random(8000, 14000) end
    if cargoId == 'electronics' then return math.random(3000, 6000)  end
    if cargoId == 'hazmat'      then return math.random(5000, 9000)  end
    if cargoId == 'classified'  then return math.random(2000, 4500)  end
    return math.random(5000, 10000)
end

local function GiveManifest(src, cargo, dropoff)
    if not Config.Manifest.enabled then return nil end
    if GetResourceState('ox_inventory') ~= 'started' then return nil end

    local manifestId      = GenerateManifestId()
    local containerNumber = GenerateContainerNumber()
    local shipper         = PickRandom(SHIPPERS)
    local consignee       = PickRandom(CONSIGNEES)
    local weightKg        = GenerateWeight(cargo.id)
    local issuedAt        = os.date('%Y-%m-%d %H:%M')

    -- ox_inventory shows each metadata key as its own row in the tooltip.
    -- NOTE: 'weight' is RESERVED by ox_inventory (overrides item weight) so
    -- we use 'gross_weight' instead. Keys are humanized in the tooltip.
    local metadata = {
        description  = ('Official freight paperwork for shipment %s.'):format(manifestId),
        manifest     = manifestId,
        container    = containerNumber,
        cargo        = cargo.label,
        gross_weight = ('%d kg'):format(weightKg),
        shipper      = shipper,
        consignee    = consignee,
        destination  = dropoff.label,
        issued       = issuedAt,
        carrier      = 'San Andreas Freight Co.',
    }

    local ok, err = pcall(function()
        exports.ox_inventory:AddItem(src, Config.Manifest.itemName, 1, metadata)
    end)
    if not ok then
        Debug(('Manifest grant failed: %s'):format(tostring(err)))
        return nil
    end

    return {
        id        = manifestId,
        container = containerNumber,
        weight    = ('%d kg'):format(weightKg),
        shipper   = shipper,
        consignee = consignee,
        issued    = issuedAt,
        carrier   = 'San Andreas Freight Co.',
    }
end

local function RemoveManifest(src)
    if not Config.Manifest.enabled then return end
    if GetResourceState('ox_inventory') ~= 'started' then return end

    pcall(function()
        exports.ox_inventory:RemoveItem(src, Config.Manifest.itemName, 1)
    end)
end

-- ─── Job request callback ───────────────────────────────────────────

lib.callback.register('distortionz_trucking:server:requestJob', function(source)
    local src = source

    if activeJobs[src] then
        return { success = false, reason = 'You already have an active run.' }
    end

    local cdLeft = CooldownLeft(src)
    if cdLeft > 0 then
        return { success = false, reason = ('Wait %d seconds before another run.'):format(cdLeft) }
    end

    local cargo   = PickCargo()
    local dropoff = PickDropoff()

    -- Issue cargo manifest item (RP touch — players can show it to police)
    -- Returns full manifest table with all generated fields for the HUD.
    local manifest = GiveManifest(src, cargo, dropoff)

    activeJobs[src] = {
        cargo     = cargo,
        dropoff   = dropoff,
        manifest  = manifest,
        startedAt = os.time(),
    }

    Debug(('Job assigned: src=%s cargo=%s dropoff=%s pay=%s manifest=%s')
        :format(src, cargo.id, dropoff.label, cargo.basePay, manifest and manifest.id or 'none'))

    -- Maybe alert police on pickup (hazmat / classified)
    local Player = exports.qbx_core:GetPlayer(src)
    if Player then
        local coords = GetEntityCoords(GetPlayerPed(src))
        MaybePoliceAlert(coords, cargo.id, ('%s pickup'):format(cargo.label))
    end

    return {
        success = true,
        job = {
            cargo = {
                id         = cargo.id,
                label      = cargo.label,
                description = cargo.description,
                basePay    = cargo.basePay,
                color      = cargo.color,
                icon       = cargo.icon,
            },
            dropoff = {
                coords = { x = dropoff.coords.x, y = dropoff.coords.y, z = dropoff.coords.z, w = dropoff.coords.w },
                label  = dropoff.label,
            },
            manifest = manifest,
        }
    }
end)

-- ─── Deliver callback ───────────────────────────────────────────────

lib.callback.register('distortionz_trucking:server:deliver', function(source, payload)
    local src = source
    local job = activeJobs[src]
    if not job then
        return { success = false, reason = 'No active job.' }
    end

    local trailerHealth = tonumber(payload and payload.trailerHealth) or 1000.0
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then
        return { success = false, reason = 'Player not found.' }
    end

    -- Validate distance to dropoff
    local pCoords = GetEntityCoords(GetPlayerPed(src))
    local d = job.dropoff.coords
    local dist = #(pCoords - vec3(d.x, d.y, d.z))
    if dist > 25.0 then
        return { success = false, reason = 'You\'re not at the drop-off.' }
    end

    -- Calculate pay (with damage penalty if trailer is below threshold)
    local cargo = job.cargo
    local payout = cargo.basePay
    local damaged = false
    if trailerHealth < Config.Job.trailerDamageThreshold then
        payout = math.floor(payout * (cargo.damagePenalty or 0.7))
        damaged = true
    end

    -- Deposit clean money
    Player.Functions.AddMoney('bank', payout, 'distortionz_trucking_delivery')

    -- Cleanup trailer if still around
    if payload and payload.trailerNetId then
        local trailer = NetworkGetEntityFromNetworkId(payload.trailerNetId)
        if trailer and trailer ~= 0 and DoesEntityExist(trailer) then
            DeleteEntity(trailer)
        end
    end

    -- Remove manifest item now that delivery is complete
    RemoveManifest(src)

    activeJobs[src] = nil
    cooldowns[src]  = os.time() + Config.Job.cooldownAfterDeliverySec

    Debug(('Delivered: src=%s cargo=%s pay=%s damaged=%s'):format(src, cargo.id, payout, tostring(damaged)))

    return {
        success = true,
        payout  = payout,
        damaged = damaged,
        cargo   = cargo.label,
    }
end)

-- ─── Cancel job ─────────────────────────────────────────────────────

RegisterNetEvent('distortionz_trucking:server:cancelJob', function(reason)
    local src = source
    if not activeJobs[src] then return end
    RemoveManifest(src)
    activeJobs[src] = nil
    Debug(('Cancelled: src=%s reason=%s'):format(src, reason or 'unknown'))
end)

-- ─── Cleanup on disconnect ──────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source
    if activeJobs[src] then RemoveManifest(src) end
    activeJobs[src] = nil
    cooldowns[src]  = nil
end)

CreateThread(function()
    Wait(1000)
    print(('^5[%s]^7 ^2v%s loaded — cargo=%d dropoffs=%d manifest=%s^7'):format(
        Config.Script.name,
        Config.CurrentVersion,
        #Config.Cargo,
        #Config.Dropoffs,
        tostring(Config.Manifest.enabled)
    ))
end)
