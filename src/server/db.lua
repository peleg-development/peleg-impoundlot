---@class ImpoundRow
---@field id integer
---@field owner_identifier string
---@field plate string
---@field props string
---@field model string
---@field lot_id string
---@field in_lot integer
---@field fee integer
---@field framework string
---@field inserted_at string
---@field release_at string|nil
---@field release_unix integer|nil

local M = {}

---@return boolean
function M.Init()
    local success, result = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS peleg_impound (
        id INT AUTO_INCREMENT PRIMARY KEY,
        owner_identifier VARCHAR(64) NOT NULL,
        plate VARCHAR(16) NOT NULL,
        props LONGTEXT NULL,
        model VARCHAR(64) NULL,
        lot_id VARCHAR(32) NOT NULL,
        in_lot TINYINT(1) NOT NULL DEFAULT 0,
        fee INT NOT NULL DEFAULT 0,
        inserted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_plate (plate)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

        MySQL.query.await([[ALTER TABLE peleg_impound ADD COLUMN IF NOT EXISTS release_at TIMESTAMP NULL DEFAULT NULL;]])
        MySQL.query.await([[ALTER TABLE peleg_impound ADD COLUMN IF NOT EXISTS release_unix BIGINT NULL DEFAULT NULL;]])
    end)
    if not success then
        print('^1[peleg-impound] Database initialization failed: ' .. tostring(result) .. '^0')
        return false
    end
    return true
end

---@param plate string
---@return table|nil
function M.FetchVehicle(plate)
    local framework = Config.Framework
    local lookupPlate = normalize_plate(plate)
    
    ---@param t table Framework table configuration
    ---@return table|nil
    local function fetchFromFramework(t)
        local query = ('SELECT * FROM %s WHERE REPLACE(UPPER(%s), " ", "") = ? LIMIT 1'):format(t.table, t.plate)
        local row = MySQL.single.await(query, { lookupPlate })
        
        if Config.Debug then
            print(('^3[peleg-impound] DEBUG - Query: %s | Plate: %s | Result: %s^0'):format(
                query, plate, row and 'found' or 'not found'))
            if row then
                print(('^3[peleg-impound] DEBUG - Row data: %s^0'):format(json.encode(row, { indent = true })))
            end
        end
        
        if not row then return nil end
        
        local props = row[t.vehicleJsonAlt] or row[t.vehicleJsonFallback]
        return { 
            owner = row[t.owner], 
            plate = row[t.plate], 
            props = props, 
            garage = row[t.garage], 
            state = row[t.state] 
        }
    end
    
    local success, result = pcall(function()
        if framework == 'qb' or framework == 'qb-core' then
            return fetchFromFramework(Config.FrameworkTables.qb)
        elseif framework == 'esx' or framework == 'es_extended' then
            return fetchFromFramework(Config.FrameworkTables.esx)
        elseif framework == 'auto' then
            ---@diagnostic disable-next-line: need-check-nil
            local qbResult = fetchFromFramework(Config.FrameworkTables.qb)
            if qbResult then return qbResult end
            
            ---@diagnostic disable-next-line: need-check-nil
            local esxResult = fetchFromFramework(Config.FrameworkTables.esx)
            return esxResult
        else
            error(('Unknown framework: %s'):format(framework))
        end
    end)
    
    if not success then
        print(('^1[peleg-impound] FetchVehicle failed for plate "%s": %s^0'):format(plate, tostring(result)))
        return nil
    end
    
    return result
end

---@param plate string
---@return boolean
function M.RemoveVehicleFromGarage(plate)
    local framework = Config.Framework
    local lookupPlate = normalize_plate(plate)
    local success, result = pcall(function()
        if framework == 'qb' then
            local t = Config.FrameworkTables.qb
            local _ = MySQL.update.await(('DELETE FROM %s WHERE REPLACE(UPPER(%s), " ", "") = ?'):format(t.table, t.plate), { lookupPlate })
            return true
        else
            local t = Config.FrameworkTables.esx
            local _ = MySQL.update.await(('DELETE FROM %s WHERE REPLACE(UPPER(%s), " ", "") = ?'):format(t.table, t.plate), { lookupPlate })
            return true
        end
    end)
    if not success then
        print('^1[peleg-impound] RemoveVehicleFromGarage failed: ' .. tostring(result) .. '^0')
        return false
    end
    return result
end

---@param owner string
---@param plate string
---@param props string|nil
---@param model string|nil
---@param lot_id string
---@param fee integer
---@param release_at string|nil
---@param release_unix integer|nil
---@return integer|nil
function M.AddToImpound(owner, plate, props, model, lot_id, fee, release_at, release_unix)
    plate = normalize_plate(plate)
    local success, result = pcall(function()
        if release_unix and release_unix > 0 then
            return MySQL.insert.await(
                'INSERT INTO peleg_impound (owner_identifier, plate, props, model, lot_id, in_lot, fee, release_at, release_unix) VALUES (?,?,?,?,?,?,?,?,?)',
                { owner, plate, props, model, lot_id, 0, fee, release_at, release_unix })
        else
            return MySQL.insert.await(
                'INSERT INTO peleg_impound (owner_identifier, plate, props, model, lot_id, in_lot, fee) VALUES (?,?,?,?,?,?,?)',
                { owner, plate, props, model, lot_id, 0, fee })
        end
    end)
    if not success then
        print('^1[peleg-impound] AddToImpound failed: ' .. tostring(result) .. '^0')
        return nil
    end
    return result
end

---@param plate string
---@return boolean
function M.RemoveFromImpound(plate)
    local lookupPlate = normalize_plate(plate)
    local success, result = pcall(function()
        return MySQL.update.await("DELETE FROM peleg_impound WHERE REPLACE(UPPER(plate), ' ', '') = ?", { lookupPlate })
    end)
    if not success then
        print('^1[peleg-impound] RemoveFromImpound failed: ' .. tostring(result) .. '^0')
        return false
    end
    return result and result > 0
end

---@param owner string
---@return ImpoundRow[]
function M.GetImpoundedByOwner(owner)
    local success, result = pcall(function()
        return MySQL.query.await('SELECT *, COALESCE(release_unix, UNIX_TIMESTAMP(release_at)) AS release_unix FROM peleg_impound WHERE owner_identifier = ?', { owner })
    end)
    if not success then
        print('^1[peleg-impound] GetImpoundedByOwner failed: ' .. tostring(result) .. '^0')
        return {}
    end
    return result or {}
end

---@return ImpoundRow[]
function M.GetAll()
    local success, result = pcall(function()
        return MySQL.query.await('SELECT *, COALESCE(release_unix, UNIX_TIMESTAMP(release_at)) AS release_unix FROM peleg_impound', {})
    end)
    if not success then
        print('^1[peleg-impound] GetAll failed: ' .. tostring(result) .. '^0')
        return {}
    end
    return result or {}
end

---@param lotId string
---@return ImpoundRow[]
function M.GetPlayerVehiclesInLot(lotId)
    local success, result = pcall(function()
        return MySQL.query.await('SELECT *, COALESCE(release_unix, UNIX_TIMESTAMP(release_at)) AS release_unix FROM peleg_impound WHERE lot_id = ? AND owner_identifier != ?',
            { lotId, 'npc' })
    end)
    if not success then
        print('^1[peleg-impound] GetPlayerVehiclesInLot failed: ' .. tostring(result) .. '^0')
        return {}
    end
    return result or {}
end

---@return ImpoundRow[]
function M.GetAllPlayerVehicles()
    local success, result = pcall(function()
        return MySQL.query.await('SELECT *, COALESCE(release_unix, UNIX_TIMESTAMP(release_at)) AS release_unix FROM peleg_impound WHERE owner_identifier != ?', { 'npc' })
    end)
    if not success then
        print('^1[peleg-impound] GetAllPlayerVehicles failed: ' .. tostring(result) .. '^0')
        return {}
    end
    return result or {}
end

---@param plate string
---@param inLot boolean
function M.SetInLot(plate, inLot)
    local lookupPlate = normalize_plate(plate)
    local success, result = pcall(function()
        return MySQL.update.await("UPDATE peleg_impound SET in_lot = ? WHERE REPLACE(UPPER(plate), ' ', '') = ?", { inLot and 1 or 0, lookupPlate })
    end)
    if not success then
        print('^1[peleg-impound] SetInLot failed: ' .. tostring(result) .. '^0')
    end
end

---@param plate string
---@param newLot string
function M.MoveLot(plate, newLot)
    local lookupPlate = normalize_plate(plate)
    local success, result = pcall(function()
        return MySQL.update.await("UPDATE peleg_impound SET lot_id = ? WHERE REPLACE(UPPER(plate), ' ', '') = ?", { newLot, lookupPlate })
    end)
    if not success then
        print('^1[peleg-impound] MoveLot failed: ' .. tostring(result) .. '^0')
    end
end

---@param evt string
---@param data table|string|number|boolean|nil
local function emitDebug(evt, data)
    if not Config.Debug then return end
    local payload = data
    if type(payload) == 'table' and json and json.encode then
        payload = json.encode(data)
    else
        payload = tostring(payload)
    end
    print(('[peleg-impound][%s] %s'):format(evt, payload))
end

---@param owner string
---@param plate string
---@param props string|nil
---@param garage string
---@param model string|nil
---@param storedState integer|nil
---@return boolean
function M.AddVehicleToGarage(owner, plate, props, garage, model, storedState)
    local framework = Config.Framework
    local vehicleHash = model and GetHashKey(model) or 0
    
    local license = owner
    if type(owner) == 'string' and owner:find('^license:') then
        license = owner
    else
        if framework == 'qb' or framework == 'qb-core' then
            local row = MySQL.single.await('SELECT license FROM players WHERE citizenid = ? LIMIT 1', { owner })
            if row and row.license and row.license ~= '' then license = row.license end
        elseif framework == 'esx' or framework == 'es_extended' then
            license = owner
        elseif framework == 'auto' then
            if type(owner) == 'string' and owner:find('^license:') then
                license = owner
            else
                local row = MySQL.single.await('SELECT license FROM players WHERE citizenid = ? LIMIT 1', { owner })
                if row and row.license and row.license ~= '' then license = row.license else license = owner end
            end
        end
    end
    
    emitDebug('AddVehicleToGarage:begin', {
        owner = owner, plate = plate, garage = garage, model = model,
        storedState = storedState or 1, framework = framework
    })

    local success, result = pcall(function()
        local t
        if framework == 'qb' or framework == 'qb-core' then
            t = Config.FrameworkTables.qb
        else
            t = Config.FrameworkTables.esx
        end

        local columns = { t.owner, t.plate, t.vehicleJsonFallback }
        local values  = { owner, plate, props or '{}' }

        if t.garage then
            columns[#columns+1] = t.garage
            values[#values+1] = garage
        end

        if t.state then
            columns[#columns+1] = t.state
            values[#values+1] = storedState or 1
        end

        if t.model then
            columns[#columns+1] = t.model
            values[#values+1] = model or 'adder'
        end
        if t.hash then
            columns[#columns+1] = t.hash
            values[#values+1] = vehicleHash
        end

        if (framework == 'esx' or framework == 'es_extended' or (framework == 'auto' and t == Config.FrameworkTables.esx)) and t.name then
            columns[#columns+1] = t.name
            values[#values+1] = model or 'adder'
        end
        
        if t.license then
            columns[#columns+1] = t.license
            values[#values+1] = license
        end

        local placeholders = {}
        for i = 1, #columns do placeholders[i] = '?' end
        local sql = ('INSERT INTO %s (%s) VALUES (%s)')
            :format(t.table, table.concat(columns, ', '), table.concat(placeholders, ', '))

        emitDebug('AddVehicleToGarage:prepared', {
            table = t.table, columns = columns, values = values
        })

        local insertId = MySQL.insert.await(sql, values)

        emitDebug('AddVehicleToGarage:db_result', { insertId = insertId })
        return insertId
    end)

    if not success then
        emitDebug('AddVehicleToGarage:error', { error = tostring(result), plate = plate, owner = owner })
        print('^1[peleg-impound] AddVehicleToGarage failed: ' .. tostring(result) .. '^0')
        return false
    end

    local ok = (result and result > 0) or false
    emitDebug('AddVehicleToGarage:done', { ok = ok, insertId = result, plate = plate })
    return ok
end


return M
