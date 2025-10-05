local m = require('src.shared.bridge')
local BRIDGE = m.BRIDGE
local isUIOpen = false

---@param vehicles table
---@param lots table
---@param garages table
---@param isPolice boolean
---@param baseFee number
local function openImpoundUI(vehicles, lots, garages, isPolice, baseFee)
    if isUIOpen then return end

    isUIOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        type = 'openImpoundUI',
        data = {
            vehicles = vehicles,
            lots = lots,
            garages = garages,
            isPolice = isPolice,
            baseFee = baseFee
        }
    })
end

---@param vehicles table
local function updateVehicles(vehicles)
    if not isUIOpen then return end

    SendNUIMessage({
        type = 'updateVehicles',
        data = {
            vehicles = vehicles
        }
    })
end

---@param notificationType string
---@param message string
---@param duration number|nil
local function showNotification(notificationType, message, duration)
    SendNUIMessage({
        type = 'showNotification',
        data = {
            notification = {
                type = notificationType,
                message = message,
                duration = duration or 5000
            }
        }
    })
end

---@return table
local function refreshVehicleList()
    return lib.callback.await('peleg_impound:get_all_player_vehicles', false) or {}
end

local function closeUI()
    if not isUIOpen then return end

    isUIOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        type = 'closeImpoundUI'
    })
end

RegisterNUICallback('closeUI', function(data, cb)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('releaseVehicle', function(data, cb)
    local plate = data.plate
    local lotId = data.lotId

    if not plate or not lotId then
        cb({ success = false, message = 'Invalid data' })
        return
    end

    local success, message = lib.callback.await('peleg_impound:pay_and_release', false, plate, lotId)

    if success then
        showNotification('success', 'Vehicle released successfully!')
        updateVehicles(refreshVehicleList())
    else
        showNotification('error', message or 'Failed to release vehicle')
    end

    cb({ success = success, message = message })
end)

RegisterNUICallback('releaseToGarage', function(data, cb)
    local plate = data.plate
    local lotId = data.lotId
    local garageId = data.garageId

    if not plate or not lotId or not garageId then
        cb({ success = false, message = 'Invalid data' })
        return
    end

    local success, message = lib.callback.await('peleg_impound:release_to_garage', false, plate, lotId, garageId)

    if success then
        showNotification('success', 'Vehicle released to garage successfully!')
        updateVehicles(refreshVehicleList())
    else
        showNotification('error', message or 'Failed to release vehicle')
    end

    cb({ success = success, message = message })
end)

RegisterNetEvent('peleg_impound:client:openUI', function()
    local isPolice = BRIDGE.IsPolice(cache.playerId)

    if not isPolice then
        lib.notify({ description = 'No permission to access impound system' })
        return
    end

    local vehicles = refreshVehicleList()
    openImpoundUI(vehicles, Config.Lots, Config.Garages, isPolice, Config.Fee)
end)

RegisterNetEvent('peleg_impound:client:refresh_markers', function()
    if isUIOpen then
        updateVehicles(refreshVehicleList())
    end
end)

RegisterNetEvent('peleg_impound:client:open_impound_setup', function()
    local playerCoords = GetEntityCoords(cache.ped)
    local veh = lib.getClosestVehicle(playerCoords, 5.0, true)
    
    -- Check if there's a vehicle nearby
    if not veh or not DoesEntityExist(veh) then
        lib.notify({ 
            description = 'No vehicle found within 5 meters',
            type = 'error'
        })
        return
    end
    
    local modelHash = GetEntityModel(veh)
    local modelName = GetDisplayNameFromVehicleModel(modelHash):lower()

    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'openImpoundSetup',
        data = {
            vehicleModel = modelName
        }
    })
end)

RegisterNUICallback('confirmImpound', function(data, cb)
    local fee = data.fee
    local releaseDate = data.releaseDate or ''
    
    if fee and fee > 0 then
        TriggerEvent('peleg_impound:client:start_flatbed_impound', fee, releaseDate)
    end
    
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('closeImpoundSetup', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)
