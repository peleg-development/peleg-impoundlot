---@class VehicleUtils
local VehicleUtils = {}
local m = require('src.shared.bridge')
local TargetBridge = m.TargetBridge

---@param veh number
---@param frozen boolean
function VehicleUtils.lock_and_freeze(veh, frozen)
    SetVehicleDoorsLocked(veh, 2)
    SetEntityInvincible(veh, true)
    FreezeEntityPosition(veh, frozen)
end

---@param coords vector3
---@param occupiedSpots table
---@param radius number
---@return boolean
function VehicleUtils.isSpotOccupied(coords, occupiedSpots, radius)
    for _, spot in ipairs(occupiedSpots) do
        if #(coords - spot) < radius then
            return true
        end
    end
    return false
end

---@param lot table
---@param occupiedSpots table
---@param radius number
---@return vector4|nil
function VehicleUtils.findAvailableSpot(lot, occupiedSpots, radius)
    for _, spawn in ipairs(lot.spawn) do
        if not VehicleUtils.isSpotOccupied(vector3(spawn.x, spawn.y, spawn.z), occupiedSpots, radius) then
            occupiedSpots[#occupiedSpots + 1] = vector3(spawn.x, spawn.y, spawn.z)
            return spawn
        end
    end
    return nil
end

---@param vehicleData table
---@param lot table
---@param occupiedSpots table
---@return number|nil
function VehicleUtils.spawnVehicleInLot(vehicleData, lot, occupiedSpots)
    local availableSpot = VehicleUtils.findAvailableSpot(lot, occupiedSpots, 3.0)
    if not availableSpot then return nil end

    local vehicleModel = vehicleData.model and GetHashKey(vehicleData.model)
    if not vehicleModel then return nil end

    lib.requestModel(vehicleModel, 5000)
    local veh = CreateVehicle(vehicleModel, availableSpot.x, availableSpot.y, availableSpot.z, availableSpot.w, false,
        false)
    SetVehicleNumberPlateText(veh, vehicleData.plate)
    VehicleUtils.lock_and_freeze(veh, true)

    return veh
end


-- OLD REMOVED
-- ---@param veh number
-- ---@param vehicleData table
-- ---@param lot string
-- function VehicleUtils.addVehicleTarget(veh, vehicleData, lot)
--     TargetBridge.addLocalEntity(veh, {
--         {
--             name = 'peleg_impound_release_' .. vehicleData.plate,
--             icon = 'fa-solid fa-key',
--             label = 'Release Vehicle',
--             type = 'client',
--             event = 'peleg_impound:client:release_from_target',
--             action = function()
--                 local ok, msg = lib.callback.await('peleg_impound:pay_and_release', false, vehicleData.plate, lot)
--                 if not ok then lib.notify({ description = msg or 'Failed' }) end
--             end
--         }
--     })
-- end

-- RegisterNetEvent('peleg_impound:client:release_from_target', function(data)
--     local entity = data and data.entity or data
--     if not entity or not DoesEntityExist(entity) then return end
--     local plate = GetVehicleNumberPlateText(entity)
--     plate = normalize_plate(plate)

--     local pos = GetEntityCoords(entity)
--     local closestLot, bestDist = nil, math.huge
--     for _, lot in ipairs(Config.Lots) do
--         local dist = #(pos - lot.center)
--         if dist < bestDist then
--             bestDist = dist
--             closestLot = lot
--         end
--     end
--     if not closestLot then return end

--     local ok, msg = lib.callback.await('peleg_impound:pay_and_release', false, plate, closestLot.id)
--     if not ok then lib.notify({ description = msg or 'Failed' }) end
-- end)

return VehicleUtils
