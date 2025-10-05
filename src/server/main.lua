local DB = require('src.server.db')
local Discord = require('src.server.discord')
local m = require('src.shared.bridge')
local BRIDGE = m.BRIDGE
DB.Init()

lib.callback.register('peleg_impound:get_player_impounded', function(src)
    local id = BRIDGE.PlayerIdentifier(src)
    return DB.GetImpoundedByOwner(id)
end)

lib.callback.register('peleg_impound:get_all_impounded', function(src)
    if not BRIDGE.IsPolice(src) then return {} end
    return DB.GetAll()
end)

lib.callback.register('peleg_impound:get_player_vehicles_in_lot', function(src, lotId)
    return DB.GetPlayerVehiclesInLot(lotId)
end)

lib.callback.register('peleg_impound:get_all_player_vehicles', function(src)
    return DB.GetAllPlayerVehicles()
end)

lib.callback.register('peleg_impound:pay_and_release', function(src, plate, lotId)
    local rows = DB.GetImpoundedByOwner(BRIDGE.PlayerIdentifier(src))
    local row = table_find(rows, function(r) return r.plate == plate end)
    if not row then return false, 'Not yours' end
    if not BRIDGE.IsPolice(src) then return false, 'Requires officer' end

    local lot = table_find(Config.Lots, function(l) return l.id == lotId end)
    if not lot then
        return false, 'Lot not configured'
    end

    local spawnLoc = lot.release_spawn or (lot.spawn and lot.spawn[math.random(1, #lot.spawn)])
    if not spawnLoc then
        return false, 'No spawn location configured for this lot'
    end

    if not DB.RemoveFromImpound(plate) then return false, 'Internal error' end
    local playerName = BRIDGE.PlayerName(src)
    Discord.LogVehicleReleased(playerName, src, row.model, plate, lotId, 0)

    DB.AddVehicleToGarage(BRIDGE.PlayerIdentifier(src), plate, row.props, Config.DefaultGarage, row.model, 1)

    local ownerSource = BRIDGE.GetPlayerSourceByIdentifier(row.owner)
    if ownerSource then
        BRIDGE.GiveKeys(ownerSource, plate)
    end

    TriggerClientEvent('peleg_impound:client:spawn_vehicle', ownerSource or src, plate, lotId, row.model, spawnLoc)
    TriggerClientEvent('peleg_impound:client:remove_vehicle_from_lot', -1, plate, lotId)
    return true, 'Released'
end)

lib.callback.register('peleg_impound:release_to_garage', function(src, plate, lotId, garageId)
    if not BRIDGE.IsPolice(src) then return false, 'No permission' end

    local allVehicles = DB.GetAll()
    local vehicleData = table_find(allVehicles, function(v) return v.plate == plate end)

    if not vehicleData then return false, 'Vehicle not found' end

    local ok = DB.RemoveFromImpound(plate)
    if not ok then return false, 'Failed to remove from impound' end

    local success = DB.AddVehicleToGarage(vehicleData.owner_identifier, plate, vehicleData.props, garageId,
        vehicleData.model, 1)

    if success then
        local officerName = BRIDGE.PlayerName(src)
        Discord.LogVehicleReleasedToGarage(officerName, src, vehicleData.model, plate, lotId, garageId)

        TriggerClientEvent('peleg_impound:client:refresh_markers', -1)
        return true, 'Vehicle released to garage'
    else
        return false, 'Failed to add vehicle to garage'
    end
end)

lib.addCommand('impound', {
    help = 'Impound closest vehicle with flatbed',
}, function(src, args)
    if not BRIDGE.IsPolice(src) then
        BRIDGE.Notify(src, 'No permission')
        return
    end
    TriggerClientEvent('peleg_impound:client:open_impound_setup', src)
end)

RegisterNetEvent('peleg_impound:server:finalize_impound', function(payload)
    local src = source
    if not BRIDGE.IsPolice(src) then return end
    local plate = normalize_plate(payload.plate)
    local owner = payload.owner
    local lotId = payload.lotId
    local fee = tonumber(Config.Fee or 0) + (tonumber(payload.fee) or 0)
    local releaseDate = payload.release_date
    local releaseAt, releaseUnix = nil, nil
    if releaseDate and releaseDate ~= '' then
        local year, month, day = releaseDate:match('(%d+)-(%d+)-(%d+)')
        if year and month and day then
            local releaseTime = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = 0,
                min = 0,
                sec = 0
            })
            if releaseTime > os.time() then
                releaseUnix = releaseTime
                releaseAt = os.date('!%Y-%m-%d %H:%M:%S', releaseUnix)
            end
        end
    end


    local row = DB.FetchVehicle(plate)
    if not row then
        return
    end
    DB.RemoveVehicleFromGarage(plate)
    DB.AddToImpound(row.owner, plate, row.props, payload.model, lotId, fee, releaseAt, releaseUnix)

    local officerName = BRIDGE.PlayerName(src)
    local ownerName = BRIDGE.GetPlayerNameByIdentifier(row.owner)
    Discord.LogVehicleImpounded(ownerName or 'Unknown', 0, payload.model, plate, lotId, 'Player Vehicle')
    Discord.LogOfficerAction(officerName, src, 'Impounded Player Vehicle',
        'Owner: ' .. (ownerName or 'Unknown') .. ', Plate: ' .. plate)

    TriggerClientEvent('peleg_impound:client:refresh_markers', -1)
end)
