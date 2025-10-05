local VehicleUtils = require('src.client.vehicle_utils')

local spawned = {}
local occupiedSpots = {}
local vehicleMap = {} 

RegisterNetEvent('peleg_impound:client:refresh_markers', function()
    for _, v in ipairs(spawned) do if DoesEntityExist(v) then DeleteEntity(v) end end
    spawned = {}
    occupiedSpots = {}
    vehicleMap = {}

    if not Config.ShowVehiclePreview then return end

    for _, lot in ipairs(Config.Lots) do
        local playerVehicles = lib.callback.await('peleg_impound:get_player_vehicles_in_lot', false, lot.id) or {}

        for _, vehicleData in ipairs(playerVehicles) do
            local veh = VehicleUtils.spawnVehicleInLot(vehicleData, lot, occupiedSpots)
            if veh then
                spawned[#spawned + 1] = veh
                vehicleMap[vehicleData.plate] = veh
                -- VehicleUtils.addVehicleTarget(veh, vehicleData, lot.id)
            end
        end
    end
end)

RegisterNetEvent('peleg_impound:client:remove_vehicle_from_lot', function(plate, lotId)
    if not Config.ShowVehiclePreview then return end
    
    local vehicle = vehicleMap[plate]
    if vehicle and DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
        vehicleMap[plate] = nil
        
        for i = #spawned, 1, -1 do
            if spawned[i] == vehicle then
                table.remove(spawned, i)
                break
            end
        end
    end
end)

CreateThread(function()
    Wait(1500)
    TriggerEvent('peleg_impound:client:refresh_markers')
    
    while true do
        Wait(300000) -- 5 minutes
        if Config.ShowVehiclePreview then
            TriggerEvent('peleg_impound:client:refresh_markers')
        end
    end
end)
