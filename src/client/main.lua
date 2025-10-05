local m = require('src.shared.bridge')
local BRIDGE, TargetBridge = m.BRIDGE, m.TargetBridge

RegisterNetEvent('peleg_impound:client:spawn_vehicle', function(plate, lotId, model, spawnLoc)
    local vehicleModel = model and GetHashKey(model)
    if not vehicleModel then return end
    
    lib.requestModel(vehicleModel, 5000)
    local veh = CreateVehicle(vehicleModel, spawnLoc.x, spawnLoc.y, spawnLoc.z, spawnLoc.w, true, false)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, plate)
    BRIDGE.GiveKeys(cache.playerId or PlayerId(), plate, veh)
end)

---@param releaseDate string
RegisterNetEvent('peleg_impound:client:start_flatbed_impound', function(fee, releaseDate)
    local playerCoords = GetEntityCoords(cache.ped)
    local veh = lib.getClosestVehicle(playerCoords, 5.0, true)

    if not veh or veh == 0 then
        lib.notify({ description = 'No vehicle found within 100 meters' })
        return
    end

    local plate = GetVehicleNumberPlateText(veh)
    plate = normalize_plate(plate)
    local model = string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
    local vehicleCoords = GetEntityCoords(veh)

    lib.notify({ description = 'Impounding vehicle' })

    local closestLot = nil
    local closestDistance = math.huge
    for _, lot in ipairs(Config.Lots) do
        local distance = #(playerCoords - lot.center)
        if distance < closestDistance then
            closestDistance = distance
            closestLot = lot
        end
    end

    if not closestLot then
        lib.notify({ description = 'No impound lot found' })
        return
    end

    TriggerEvent('peleg_impound:client:flatbed_pickup', veh, closestLot.id, fee, plate, model, releaseDate)
end)

---@param lot table
---@return number|nil
local function spawnPed(lot)
    if not lot.ped or not lot.ped.enabled then return nil end

    local pedModel = GetHashKey(lot.ped.model)
    lib.requestModel(pedModel, 5000)

    local ped = CreatePed(4, pedModel, lot.ped.coords.x, lot.ped.coords.y, lot.ped.coords.z, lot.ped.coords.w, false,
        true)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if lot.ped.scenario then
        TaskStartScenarioInPlace(ped, lot.ped.scenario, 0, true)
    end

    return ped
end

CreateThread(function()
    for _, lot in ipairs(Config.Lots) do
        local ped = spawnPed(lot)

        local targetOptions = {
            {
                name = 'peleg_impound_open_ui_' .. lot.id,
                label = 'Impound Lot',
                icon = 'fa-solid fa-warehouse',
                canInteract = function()
                    return BRIDGE.IsPolice(cache.playerId)
                end,
                action = function()
                    TriggerEvent('peleg_impound:client:openUI')
                end
            }
        }

        if ped then
            TargetBridge.addLocalEntity(ped, targetOptions)
        else
            TargetBridge.addSphereZone(lot.center, 2.5, targetOptions)
        end
    end
end)

---@return number|nil
function GetClosestPlayer()
    local players = GetActivePlayers()
    local myCoords = GetEntityCoords(cache.ped)
    local best, bestDist = nil, 3.0
    for _, pid in ipairs(players) do
        if pid ~= cache.playerId then
            local ped = GetPlayerPed(pid)
            local dist = #(GetEntityCoords(ped) - myCoords)
            if dist < bestDist then best, bestDist = pid, dist end
        end
    end
    if not best then return nil end
    return best
end
