-- =====================================================================
--  Distortionz Trucking · client.lua
-- =====================================================================

local depotPed   = nil
local depotBlip  = nil

local activeJob  = nil
local pickupBlip = nil
local dropoffBlip = nil
local jobEndsAt  = 0

local truckEntity   = nil
local trailerEntity = nil

-- ─── Notify wrapper ─────────────────────────────────────────────────

local function Notify(message, notifyType, duration, title)
    if not message then return end
    notifyType = notifyType or 'primary'
    duration   = tonumber(duration) or Config.Notify.defaultLength
    title      = title or Config.Notify.title

    if notifyType == 'inform' then notifyType = 'info' end

    if GetResourceState(Config.Notify.resource) == 'started' then
        exports[Config.Notify.resource]:Notify(message, notifyType, duration, title)
        return
    end

    lib.notify({
        title       = title,
        description = message,
        type        = notifyType,
        duration    = duration,
    })
end

-- ─── NUI panel ──────────────────────────────────────────────────────

local function GetStageKey()
    if not activeJob then return 'pickup' end
    if activeJob.delivered then return 'delivered' end
    if activeJob.attached then return 'driving' end
    return 'pickup'
end

local function PanelShow()
    if not activeJob then return end
    SendNUIMessage({
        action      = 'show',
        stage       = GetStageKey(),
        cargo       = activeJob.cargo.label,
        cargoIcon   = activeJob.cargo.icon,
        dropoff     = activeJob.dropoff.label,
        secondsLeft = math.max(0, math.floor((jobEndsAt - GetGameTimer()) / 1000)),
        payout      = activeJob.cargo.basePay,
        manifestId  = activeJob.manifest and activeJob.manifest.id        or nil,
        container   = activeJob.manifest and activeJob.manifest.container or nil,
        weight      = activeJob.manifest and activeJob.manifest.weight    or nil,
        shipper     = activeJob.manifest and activeJob.manifest.shipper   or nil,
        consignee   = activeJob.manifest and activeJob.manifest.consignee or nil,
    })
end

local function PanelHide()
    SendNUIMessage({ action = 'hide' })
end

CreateThread(function()
    while true do
        if activeJob then
            local secondsLeft = math.max(0, math.floor((jobEndsAt - GetGameTimer()) / 1000))
            SendNUIMessage({
                action      = 'update',
                stage       = GetStageKey(),
                cargo       = activeJob.cargo.label,
                cargoIcon   = activeJob.cargo.icon,
                dropoff     = activeJob.dropoff.label,
                secondsLeft = secondsLeft,
                payout      = activeJob.cargo.basePay,
                manifestId  = activeJob.manifest and activeJob.manifest.id        or nil,
                container   = activeJob.manifest and activeJob.manifest.container or nil,
                weight      = activeJob.manifest and activeJob.manifest.weight    or nil,
                shipper     = activeJob.manifest and activeJob.manifest.shipper   or nil,
                consignee   = activeJob.manifest and activeJob.manifest.consignee or nil,
            })
            Wait(1000)
        else
            Wait(500)
        end
    end
end)

-- ─── Depot ped ──────────────────────────────────────────────────────

local function SpawnDepotPed()
    if depotPed and DoesEntityExist(depotPed) then return end

    local hash = joaat(Config.Depot.model)
    lib.requestModel(hash, 10000)

    depotPed = CreatePed(0, hash, Config.Depot.coords.x, Config.Depot.coords.y, Config.Depot.coords.z, Config.Depot.coords.w, false, true)
    SetEntityInvincible(depotPed, true)
    SetBlockingOfNonTemporaryEvents(depotPed, true)
    FreezeEntityPosition(depotPed, true)

    -- v1.1.0 — Distortionz convention: flag as protected so other scripts
    -- (distortionz_robped, etc.) skip this ped for player interactions.
    Entity(depotPed).state:set('distortionz_protected_ped', true, true)
    Entity(depotPed).state:set('distortionz_contact_ped',   true, true)
    Entity(depotPed).state:set('distortionz_depot_ped',     true, true)

    if Config.Depot.scenario then
        TaskStartScenarioInPlace(depotPed, Config.Depot.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(hash)

    exports.ox_target:addLocalEntity(depotPed, {
        {
            name     = 'distortionz_trucking_depot',
            label    = Config.Depot.targetLabel,
            icon     = Config.Depot.targetIcon,
            distance = 2.5,
            onSelect = function()
                TriggerEvent('distortionz_trucking:client:requestJob')
            end,
        }
    })
end

local function CreateDepotBlip()
    if not Config.Depot.blip or not Config.Depot.blip.enabled then return end
    if depotBlip then return end

    depotBlip = AddBlipForCoord(Config.Depot.coords.x, Config.Depot.coords.y, Config.Depot.coords.z)
    SetBlipSprite(depotBlip, Config.Depot.blip.sprite)
    SetBlipColour(depotBlip, Config.Depot.blip.color)
    SetBlipScale(depotBlip, Config.Depot.blip.scale)
    SetBlipAsShortRange(depotBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Depot.blip.label)
    EndTextCommandSetBlipName(depotBlip)
end

local function RemoveDepotPed()
    if depotPed and DoesEntityExist(depotPed) then
        exports.ox_target:removeLocalEntity(depotPed, 'distortionz_trucking_depot')
        DeletePed(depotPed)
    end
    depotPed = nil
    if depotBlip and DoesBlipExist(depotBlip) then RemoveBlip(depotBlip) end
    depotBlip = nil
end

-- ─── Job cleanup ────────────────────────────────────────────────────

local function ClearJobBlips()
    if pickupBlip and DoesBlipExist(pickupBlip) then RemoveBlip(pickupBlip) end
    if dropoffBlip and DoesBlipExist(dropoffBlip) then RemoveBlip(dropoffBlip) end
    pickupBlip, dropoffBlip = nil, nil
end

local function CleanupVehicles()
    -- If the player is in the truck or trailer, eject them first so the
    -- DeleteVehicle call doesn't get blocked.
    local ped = PlayerPedId()
    local currentVeh = GetVehiclePedIsIn(ped, false)

    if currentVeh ~= 0 and (currentVeh == truckEntity or currentVeh == trailerEntity) then
        TaskLeaveVehicle(ped, currentVeh, 0)
        -- Wait briefly for the leave-vehicle task to complete
        local exitStart = GetGameTimer()
        while GetVehiclePedIsIn(ped, false) ~= 0 and (GetGameTimer() - exitStart) < 1500 do
            Wait(50)
        end
    end

    if truckEntity and DoesEntityExist(truckEntity) then
        SetEntityAsMissionEntity(truckEntity, true, true)
        DeleteVehicle(truckEntity)
    end
    if trailerEntity and DoesEntityExist(trailerEntity) then
        SetEntityAsMissionEntity(trailerEntity, true, true)
        DeleteVehicle(trailerEntity)
    end
    truckEntity, trailerEntity = nil, nil
end

local function EndJob(reason, notifyType)
    if not activeJob then return end

    CleanupVehicles()
    ClearJobBlips()
    PanelHide()
    activeJob = nil
    jobEndsAt = 0

    if reason then
        Notify(reason, notifyType or 'error', 7000)
    end
end

-- ─── Vehicle spawn ──────────────────────────────────────────────────

local function SpawnTruckAndTrailer()
    -- Check the spawn area is clear
    local truckSpawnCoords = vec3(Config.Spawn.truck.x, Config.Spawn.truck.y, Config.Spawn.truck.z)
    local trailerSpawnCoords = vec3(Config.Spawn.trailer.x, Config.Spawn.trailer.y, Config.Spawn.trailer.z)

    -- Spawn truck
    local truckHash = joaat(Config.Spawn.truckModel)
    lib.requestModel(truckHash, 10000)
    truckEntity = CreateVehicle(truckHash, truckSpawnCoords.x, truckSpawnCoords.y, truckSpawnCoords.z, Config.Spawn.truck.w, true, false)
    SetVehicleOnGroundProperly(truckEntity)
    SetEntityAsMissionEntity(truckEntity, true, true)
    SetVehicleDoorsLocked(truckEntity, 0)
    SetVehicleDoorsLockedForAllPlayers(truckEntity, false)
    SetVehicleNeedsToBeHotwired(truckEntity, false)
    SetVehicleHasBeenOwnedByPlayer(truckEntity, true)
    SetModelAsNoLongerNeeded(truckHash)

    -- Spawn trailer
    local trailerHash = joaat(Config.Spawn.trailerModel)
    lib.requestModel(trailerHash, 10000)
    trailerEntity = CreateVehicle(trailerHash, trailerSpawnCoords.x, trailerSpawnCoords.y, trailerSpawnCoords.z, Config.Spawn.trailer.w, true, false)
    SetVehicleOnGroundProperly(trailerEntity)
    SetEntityAsMissionEntity(trailerEntity, true, true)
    SetVehicleDoorsLocked(trailerEntity, 0)
    SetVehicleDoorsLockedForAllPlayers(trailerEntity, false)
    SetVehicleNeedsToBeHotwired(trailerEntity, false)
    SetModelAsNoLongerNeeded(trailerHash)

    -- Defeat any auto-lock script (smallresources, vehiclekeys autolock, etc.)
    -- This runs for the entire job lifecycle since some scripts auto-lock
    -- after the driver exits the cab.
    CreateThread(function()
        while activeJob and truckEntity and DoesEntityExist(truckEntity) do
            SetVehicleDoorsLocked(truckEntity, 0)
            SetVehicleDoorsLockedForAllPlayers(truckEntity, false)
            Wait(2000)
        end
    end)

    -- Grant keys via qbx_vehiclekeys' QBCore-compat event (no dependency required)
    -- This bypasses the "search for keys" prompt from qbx_smallresources / qbx_vehiclekeys
    Wait(300)
    if DoesEntityExist(truckEntity) then
        local truckPlate = GetVehicleNumberPlateText(truckEntity)
        TriggerEvent('vehiclekeys:client:SetOwner', truckPlate)
    end

    -- Pickup blip on the trailer
    pickupBlip = AddBlipForEntity(trailerEntity)
    SetBlipSprite(pickupBlip, 479)
    SetBlipColour(pickupBlip, 5)
    SetBlipScale(pickupBlip, 0.9)
    SetBlipAsShortRange(pickupBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Trailer Pickup')
    EndTextCommandSetBlipName(pickupBlip)
end

local function ShowDropoffBlip()
    if dropoffBlip and DoesBlipExist(dropoffBlip) then return end
    if not activeJob or not activeJob.dropoff then return end

    local d = activeJob.dropoff.coords
    dropoffBlip = AddBlipForCoord(d.x, d.y, d.z)
    SetBlipSprite(dropoffBlip, 477)
    SetBlipColour(dropoffBlip, 2)
    SetBlipScale(dropoffBlip, 0.9)
    SetBlipRoute(dropoffBlip, true)
    SetBlipRouteColour(dropoffBlip, 2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Drop-off · ' .. activeJob.dropoff.label)
    EndTextCommandSetBlipName(dropoffBlip)
end

-- ─── Job request ────────────────────────────────────────────────────

RegisterNetEvent('distortionz_trucking:client:requestJob', function()
    if activeJob then
        Notify('You already have an active run. Finish it first.', 'warning', 5000)
        return
    end

    local result = lib.callback.await('distortionz_trucking:server:requestJob', false)
    if not result or not result.success then
        Notify(result and result.reason or 'Could not start job.', 'error', 5000)
        return
    end

    activeJob = {
        cargo     = result.job.cargo,
        dropoff   = result.job.dropoff,
        manifest  = result.job.manifest,
        attached  = false,
        delivered = false,
        spawnedAt = GetGameTimer(),
    }
    jobEndsAt = GetGameTimer() + (Config.Job.timeLimitSeconds * 1000)

    SpawnTruckAndTrailer()
    PanelShow()

    Notify(('Cargo: %s — drive to the trailer and back the truck into it.'):format(activeJob.cargo.label),
        activeJob.cargo.color, 8000)
end)

-- ─── Trailer attachment loop ────────────────────────────────────────

CreateThread(function()
    while true do
        local sleep = 1000

        if activeJob and not activeJob.attached and activeJob.spawnedAt
            and truckEntity and trailerEntity
            and DoesEntityExist(truckEntity) and DoesEntityExist(trailerEntity)
            -- 3-second grace period after spawn to let physics settle and avoid
            -- false-positive attachment from spawn collision.
            and (GetGameTimer() - activeJob.spawnedAt) > 3000
        then
            sleep = 500

            -- Single deterministic check: is the trailer entity literally
            -- attached to the truck entity? Only fires after the 5th wheel
            -- physically snaps from a real backup hookup.
            local attachedTo = GetEntityAttachedTo(trailerEntity)

            if attachedTo == truckEntity then
                activeJob.attached = true

                if pickupBlip and DoesBlipExist(pickupBlip) then
                    RemoveBlip(pickupBlip); pickupBlip = nil
                end

                ShowDropoffBlip()
                Notify(('Trailer hooked. Deliver to %s.'):format(activeJob.dropoff.label), 'success', 6000)
            end
        end

        Wait(sleep)
    end
end)

-- ─── Drop-off + abandonment loop ────────────────────────────────────

CreateThread(function()
    while true do
        local sleep = 1000

        if activeJob and activeJob.attached and not activeJob.delivered then
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            local d = activeJob.dropoff.coords
            local dDist = #(pCoords - vec3(d.x, d.y, d.z))

            -- Abandonment check
            if trailerEntity and DoesEntityExist(trailerEntity) then
                local tCoords = GetEntityCoords(trailerEntity)
                local pToTrailer = #(pCoords - tCoords)
                if pToTrailer > Config.Job.abandonDistance and not IsPedInAnyVehicle(ped, false) then
                    TriggerServerEvent('distortionz_trucking:server:cancelJob', 'You abandoned the trailer.')
                    EndJob('You abandoned the trailer. Run cancelled.', 'error')
                end
            end

            if activeJob and dDist <= 30.0 then
                sleep = 0
                DrawMarker(1, d.x, d.y, d.z - 0.9, 0, 0, 0, 0, 0, 0,
                    8.0, 8.0, 1.5, 200, 200, 40, 120, false, false, 2, false, nil, nil, false)

                if dDist <= 15.0 and activeJob.attached and truckEntity and DoesEntityExist(truckEntity) then
                    local truckSpeed = GetEntitySpeed(truckEntity) * 2.236936 -- m/s -> mph
                    if truckSpeed <= Config.Job.minDropoffSpeed then
                        lib.showTextUI('[E] Drop off cargo', { position = 'right-center' })

                        if IsControlJustPressed(0, 38) then
                            lib.hideTextUI()

                            local trailerHealth = GetVehicleEngineHealth(trailerEntity)
                            local trailerNetId = NetworkGetNetworkIdFromEntity(trailerEntity)

                            local result = lib.callback.await('distortionz_trucking:server:deliver', false, {
                                trailerHealth = trailerHealth,
                                trailerNetId  = trailerNetId,
                            })

                            if result and result.success then
                                activeJob.delivered = true
                                Notify(('Delivered: %s · $%s'):format(activeJob.cargo.label, result.payout),
                                    activeJob.cargo.color, 7000)

                                if result.damaged then
                                    Wait(700)
                                    Notify('Trailer was damaged — pay reduced.', 'warning', 5000)
                                end

                                EndJob(nil, nil)
                            elseif result and result.reason then
                                Notify(result.reason, 'error', 5000)
                            end
                        end
                    else
                        lib.hideTextUI()
                    end
                else
                    lib.hideTextUI()
                end
            else
                lib.hideTextUI()
            end

            -- Time limit check
            if jobEndsAt > 0 and GetGameTimer() > jobEndsAt then
                TriggerServerEvent('distortionz_trucking:server:cancelJob', 'Time ran out.')
                EndJob('Time ran out. Run failed.', 'error')
            end
        end

        Wait(sleep)
    end
end)

-- ─── Police alert handler ───────────────────────────────────────────

RegisterNetEvent('distortionz_trucking:client:policeAlert', function(payload)
    if not payload or not payload.coords then return end

    local PlayerData = exports.qbx_core:GetPlayerData()
    if not PlayerData or not PlayerData.job then return end

    local isCop = false
    for _, j in ipairs(Config.Police.jobNames) do
        if PlayerData.job.name == j and PlayerData.job.onduty then
            isCop = true; break
        end
    end
    if not isCop then return end

    local c = payload.coords
    if type(c) == 'table' then c = vec3(c.x or 0, c.y or 0, c.z or 0) end

    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 477)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 1.0)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Routine Inspection: ' .. (payload.label or 'Trucking'))
    EndTextCommandSetBlipName(blip)

    Notify(payload.label or 'Trucking inspection', 'police', 8000, 'Dispatch')

    SetTimeout(90 * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

-- ─── Lifecycle ──────────────────────────────────────────────────────

CreateThread(function()
    Wait(1500)

    -- Register custom metadata fields with ox_inventory so they appear
    -- as proper rows in the manifest tooltip.
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:displayMetadata({
            manifest     = 'Manifest',
            container    = 'Container',
            cargo        = 'Cargo',
            gross_weight = 'Gross Weight',
            shipper      = 'Shipper',
            consignee    = 'Consignee',
            destination  = 'Destination',
            issued       = 'Issued',
            carrier      = 'Carrier',
        })
    end

    SpawnDepotPed()
    CreateDepotBlip()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RemoveDepotPed()
    ClearJobBlips()
    CleanupVehicles()
    PanelHide()
    if lib and lib.hideTextUI then lib.hideTextUI() end
end)
