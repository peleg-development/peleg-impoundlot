---@param tbl table
---@param pred fun(v:any):boolean
---@return any|nil
function table_find(tbl, pred)
    for _, v in ipairs(tbl) do
        if pred(v) then return v end
    end
    return nil
end

---@param plate string
---@return string
function normalize_plate(plate)
    if not plate then return '' end
    plate = tostring(plate)
    plate = plate:gsub('%s+', '')
    plate = plate:upper()
    return plate
end

---@param src number
---@return number, number, number
function get_coords_of_player(src)
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    return coords.x, coords.y, coords.z
end

---@param a vector3
---@param b vector3
---@return number
function v3distance(a, b)
    return #(a - b)
end
