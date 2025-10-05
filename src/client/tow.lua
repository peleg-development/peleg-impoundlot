---@param veh number
---@param lotId string
---@param fee number
---@param plate string
---@param model string
---@param releaseDate string
RegisterNetEvent('peleg_impound:client:flatbed_pickup', function(veh, lotId, fee, plate, model, releaseDate)
    if not DoesEntityExist(veh) then return end

    local success = lib.progressBar({
        duration = 15000,
        label = 'Impounding vehicle...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
        anim = { scenario = 'WORLD_HUMAN_CLIPBOARD' }
    })

    if success then
        DeleteEntity(veh)

        lib.notify({
            description = 'Vehicle impounded successfully',
            type = 'success'
        })

        TriggerServerEvent('peleg_impound:server:finalize_impound', {
            type = 'player',
            lotId = lotId,
            plate = normalize_plate(plate),
            model = model,
            owner = 'unknown',
            fee = fee,
            release_date = releaseDate or ''
        })
    else
        lib.notify({
            description = 'Impound cancelled',
            type = 'error'
        })
    end
end)
