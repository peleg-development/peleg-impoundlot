local M = {}

---@param title string
---@param description string
---@param color number|nil
---@param fields table|nil
---@param footer string|nil
function M.SendLog(title, description, color, fields, footer)
    if not Config.Discord.enabled or Config.Discord.webhook == '' then
        return
    end

    local embed = {
        {
            title = title,
            description = description,
            color = color or Config.Discord.colors.info,
            fields = fields or {},
            footer = footer and { text = footer } or nil,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
    }

    local payload = {
        username = Config.Discord.botName,
        avatar_url = Config.Discord.botAvatar ~= '' and Config.Discord.botAvatar or nil,
        embeds = embed
    }

    PerformHttpRequest(Config.Discord.webhook, function(err, text, headers) end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json'
    })
end

---@param playerName string
---@param playerId number
---@param vehicleModel string
---@param plate string
---@param lotId string
---@param reason string|nil
function M.LogVehicleImpounded(playerName, playerId, vehicleModel, plate, lotId, reason)
    if not Config.Discord.logEvents.vehicleImpounded then return end

    local fields = {
        {
            name = 'Player',
            value = playerName .. ' (ID: ' .. playerId .. ')',
            inline = true
        },
        {
            name = 'Vehicle',
            value = vehicleModel or 'Unknown',
            inline = true
        },
        {
            name = 'Plate',
            value = plate,
            inline = true
        },
        {
            name = 'Impound Lot',
            value = lotId,
            inline = true
        }
    }

    if reason then
        table.insert(fields, {
            name = 'Reason',
            value = reason,
            inline = false
        })
    end

    M.SendLog(
        '🚗 Vehicle Impounded',
        'A vehicle has been impounded',
        Config.Discord.colors.impound,
        fields,
        'Impound System'
    )
end

---@param playerName string
---@param playerId number
---@param vehicleModel string
---@param plate string
---@param lotId string
---@param amount number|nil
function M.LogVehicleReleased(playerName, playerId, vehicleModel, plate, lotId, amount)
    if not Config.Discord.logEvents.vehicleReleased then return end

    local fields = {
        {
            name = 'Player',
            value = playerName .. ' (ID: ' .. playerId .. ')',
            inline = true
        },
        {
            name = 'Vehicle',
            value = vehicleModel or 'Unknown',
            inline = true
        },
        {
            name = 'Plate',
            value = plate,
            inline = true
        },
        {
            name = 'Impound Lot',
            value = lotId,
            inline = true
        }
    }

    if amount then
        table.insert(fields, {
            name = 'Amount Paid',
            value = '$' .. amount,
            inline = true
        })
    end

    M.SendLog(
        '🔓 Vehicle Released',
        'A vehicle has been released from impound',
        Config.Discord.colors.release,
        fields,
        'Impound System'
    )
end

---@param officerName string
---@param officerId number
---@param vehicleModel string
---@param plate string
---@param lotId string
---@param garageId string
function M.LogVehicleReleasedToGarage(officerName, officerId, vehicleModel, plate, lotId, garageId)
    if not Config.Discord.logEvents.vehicleReleasedToGarage then return end

    local fields = {
        {
            name = 'Officer',
            value = officerName .. ' (ID: ' .. officerId .. ')',
            inline = true
        },
        {
            name = 'Vehicle',
            value = vehicleModel or 'Unknown',
            inline = true
        },
        {
            name = 'Plate',
            value = plate,
            inline = true
        },
        {
            name = 'From Lot',
            value = lotId,
            inline = true
        },
        {
            name = 'To Garage',
            value = garageId,
            inline = true
        }
    }

    M.SendLog(
        '🏢 Vehicle Released to Garage',
        'An officer released a vehicle to a garage',
        Config.Discord.colors.release,
        fields,
        'Impound System'
    )
end

---@param playerName string
---@param playerId number
---@param amount number
---@param plate string
function M.LogPaymentReceived(playerName, playerId, amount, plate)
    if not Config.Discord.logEvents.paymentReceived then return end

    local fields = {
        {
            name = 'Player',
            value = playerName .. ' (ID: ' .. playerId .. ')',
            inline = true
        },
        {
            name = 'Amount',
            value = '$' .. amount,
            inline = true
        },
        {
            name = 'Vehicle Plate',
            value = plate,
            inline = true
        }
    }

    M.SendLog(
        '💰 Payment Received',
        'Payment received for vehicle release',
        Config.Discord.colors.payment,
        fields,
        'Impound System'
    )
end

---@param officerName string
---@param officerId number
---@param action string
---@param details string|nil
function M.LogOfficerAction(officerName, officerId, action, details)
    if not Config.Discord.logEvents.officerAction then return end

    local fields = {
        {
            name = 'Officer',
            value = officerName .. ' (ID: ' .. officerId .. ')',
            inline = true
        },
        {
            name = 'Action',
            value = action,
            inline = true
        }
    }

    if details then
        table.insert(fields, {
            name = 'Details',
            value = details,
            inline = false
        })
    end

    M.SendLog(
        '👮 Officer Action',
        'Police officer performed an action',
        Config.Discord.colors.info,
        fields,
        'Impound System'
    )
end

return M
