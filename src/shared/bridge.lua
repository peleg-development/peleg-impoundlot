---@class BRIDGE
local BRIDGE = {}

---@return 'qb'|'esx'|'none'
---@nodiscard
local function detect()
    local qb = GetResourceState('qb-core') == 'started'
    local esx = GetResourceState('es_extended') == 'started'
    if qb and not esx then return 'qb' end
    if esx and not qb then return 'esx' end
    return 'none'
end

BRIDGE.framework = detect()
BRIDGE.qb = nil
BRIDGE.esx = nil

if BRIDGE.framework == 'qb' then
    BRIDGE.qb = exports['qb-core']:GetCoreObject()
    Config.Framework = 'qb'
elseif BRIDGE.framework == 'esx' then
    if exports['es_extended'] and exports['es_extended'].getSharedObject then
        BRIDGE.esx = exports['es_extended']:getSharedObject()
        Config.Framework = 'esx'
    else
        Config.Framework = 'esx'
        TriggerEvent('esx:getSharedObject', function(obj) BRIDGE.esx = obj end)
    end
end

---@param src number
---@return table|nil
function BRIDGE.GetPlayer(src)
    if BRIDGE.framework == 'qb' then return BRIDGE.qb.Functions.GetPlayer(src) end
    if BRIDGE.framework == 'esx' then return BRIDGE.esx.GetPlayerFromId(src) end
    return nil
end

function BRIDGE.PlayerName(src)   
    if BRIDGE.framework == 'qb' then return BRIDGE.qb.Functions.GetPlayer(src).PlayerData.charinfo.firstname .. ' ' .. BRIDGE.qb.Functions.GetPlayer(src).PlayerData.charinfo.lastname end
    if BRIDGE.framework == 'esx' then return BRIDGE.esx.GetPlayerFromId(src).name end
    return ''
end

---@param player any
---@return string
function BRIDGE.GetIdentifier(player)
    if BRIDGE.framework == 'qb' then return player.PlayerData.citizenid end
    if BRIDGE.framework == 'esx' then return player.identifier end
    return tostring(GetPlayerIdentifierByType((player and player.source) or 0, 'license') or '')
end

---@param src number
---@return boolean
function BRIDGE.IsPolice(src)
    if IsDuplicityVersion() then 
        if BRIDGE.framework == 'qb' then
            local p = BRIDGE.GetPlayer(src)
            return p and p.PlayerData.job and (p.PlayerData.job.type == 'leo' or p.PlayerData.job.name == 'police') or false
        elseif BRIDGE.framework == 'esx' then
            local p = BRIDGE.GetPlayer(src)
            return p and p.job and (p.job.name == 'police' or p.job.type == 'leo') or false
        end
    else
        if BRIDGE.framework == 'qb' then
            local p = BRIDGE.qb.Functions.GetPlayerData()
            return p and p.job and (p.job.type == 'leo' or p.job.name == 'police') or false
        elseif BRIDGE.framework == 'esx' then
            local p = BRIDGE.esx.GetPlayerData()
            return p and p.job and (p.job.name == 'police' or p.job.type == 'leo') or false
        end 
    end
    return false
end

---@param src number
---@param amount number
---@return boolean
function BRIDGE.RemoveMoney(src, amount)
    if amount <= 0 then return true end
    if BRIDGE.framework == 'qb' then
        local p = BRIDGE.GetPlayer(src)
        if not p then return false end
        if p.Functions.RemoveMoney('cash', amount) then return true end
        return p.Functions.RemoveMoney('bank', amount)
    elseif BRIDGE.framework == 'esx' then
        local p = BRIDGE.GetPlayer(src)
        if not p then return false end
        if p.removeAccountMoney then
            if p.getAccount('money') and p.getAccount('money').money >= amount then p.removeAccountMoney('money', amount) return true end
            if p.getAccount('bank') and p.getAccount('bank').money >= amount then p.removeAccountMoney('bank', amount) return true end
        end
    end
    return false
end

---@param src number
---@param msg string
function BRIDGE.Notify(src, msg)
    TriggerClientEvent('ox_lib:notify', src, { description = msg })
end

---@param veh number
---@return string|nil
function BRIDGE.GetVehicleProps(veh)
    if IsDuplicityVersion() then return nil end
    if not veh or veh == 0 then return nil end
    if BRIDGE.framework == 'qb' and BRIDGE.qb and BRIDGE.qb.Functions and BRIDGE.qb.Functions.GetVehicleProperties then
        local props = BRIDGE.qb.Functions.GetVehicleProperties(veh)
        return props and json.encode(props) or nil
    end
    if BRIDGE.framework == 'esx' and ESX and ESX.Game and ESX.Game.GetVehicleProperties then
        local props = ESX.Game.GetVehicleProperties(veh)
        return props and json.encode(props) or nil
    end
    return nil
end

---@param src number
---@param plate string
---@param veh number|nil
function BRIDGE.GiveKeys(src, plate, veh)
    if Config.KeysIntegration == 'qb-vehiclekeys' and GetResourceState('qb-vehiclekeys') == 'started' then
        local netId = veh and NetworkGetNetworkIdFromEntity(veh) or nil
        if IsDuplicityVersion() then
            TriggerClientEvent('qb-vehiclekeys:client:AddKeys', src, plate, netId)
        else
            TriggerEvent('qb-vehiclekeys:client:AddKeys', plate, netId)
        end
    elseif Config.KeysIntegration == 'mk_vehkeys' and GetResourceState('mk_vehkeys') == 'started' then
        if IsDuplicityVersion() then
            TriggerClientEvent('mk_vehkeys:client:AddKeys', src, plate)
        else
            TriggerEvent('mk_vehkeys:client:AddKeys', plate)
        end
    end
end

---@param src number
---@return string
function BRIDGE.PlayerIdentifier(src)
    local p = BRIDGE.GetPlayer(src)
    if not p then return '' end
    return BRIDGE.GetIdentifier(p)
end

---@param identifier string
---@return number|nil
function BRIDGE.GetPlayerSourceByIdentifier(identifier)
    if BRIDGE.framework == 'qb' then
        for _, playerId in ipairs(GetPlayers()) do
            local player = BRIDGE.GetPlayer(tonumber(playerId))
            if player and BRIDGE.GetIdentifier(player) == identifier then
                return tonumber(playerId)
            end
        end
    elseif BRIDGE.framework == 'esx' then
        local player = BRIDGE.esx.GetPlayerFromIdentifier(identifier)
        if player then return player.source end
    end
    return nil
end

---@param identifier string
---@return string|nil
function BRIDGE.GetPlayerNameByIdentifier(identifier)
    local src = BRIDGE.GetPlayerSourceByIdentifier(identifier)
    if not src then return nil end
    return BRIDGE.PlayerName(src)
end

---@return 'qb'|'esx'|'none'
function BRIDGE.Framework()
    return BRIDGE.framework
end


---@class TargetBridge
local TargetBridge = {}

---@param coords vector3
---@param radius number
---@param options table
function TargetBridge.addSphereZone(coords, radius, options)
    if GetResourceState('ox_target') == 'started' then
        local oxOptions = {}
        for i = 1, #options do
            local opt = options[i]
            local eventName = opt.event
            local onSelect = opt.onSelect or opt.action
            if not onSelect and eventName then
                onSelect = function(data)
                    TriggerEvent(eventName, data)
                end
            end
            oxOptions[i] = {
                name = opt.name,
                icon = opt.icon,
                label = opt.label,
                onSelect = onSelect,
                canInteract = opt.canInteract,
            }
        end
        exports.ox_target:addSphereZone({
            coords = coords,
            radius = radius,
            options = oxOptions
        })
    elseif GetResourceState('qb-target') == 'started' then
        local zoneName = 'peleg_impound_' .. coords.x .. '_' .. coords.y
        local qbOptions = {}
        for i = 1, #options do
            local opt = options[i]
            qbOptions[i] = {
                name = opt.name,
                icon = opt.icon,
                label = opt.label,
                type = opt.type,
                event = opt.event,
                action = opt.action or opt.onSelect,
                canInteract = opt.canInteract,
            }
        end
        exports['qb-target']:AddCircleZone(zoneName, coords, radius, {
            name = zoneName,
            debugPoly = false,
            useZ = true,
        }, {
            options = qbOptions,
            distance = radius
        })
    end
end

---@param entity number
---@param options table
function TargetBridge.addLocalEntity(entity, options)
    if GetResourceState('ox_target') == 'started' then
        local oxOptions = {}
        for i = 1, #options do
            local opt = options[i]
            local eventName = opt.event
            local onSelect = opt.onSelect or opt.action
            if not onSelect and eventName then
                onSelect = function(data)
                    TriggerEvent(eventName, data)
                end
            end
            oxOptions[i] = {
                name = opt.name,
                icon = opt.icon,
                label = opt.label,
                onSelect = onSelect,
                canInteract = opt.canInteract,
            }
        end
        exports.ox_target:addLocalEntity(entity, oxOptions)
    elseif GetResourceState('qb-target') == 'started' then
        local qbOptions = {}
        for i = 1, #options do
            local opt = options[i]
            qbOptions[i] = {
                name = opt.name,
                icon = opt.icon,
                label = opt.label,
                type = opt.type,
                event = opt.event,
                action = opt.action or opt.onSelect,
                canInteract = opt.canInteract,
            }
        end
        exports['qb-target']:AddTargetEntity(entity, {
            options = qbOptions,
            distance = 2.0
        })
    end
end

return { BRIDGE = BRIDGE, TargetBridge = TargetBridge }