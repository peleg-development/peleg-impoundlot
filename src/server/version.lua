local RESOURCE_NAME <const> = GetCurrentResourceName()
local CHECK_URL <const> =
"https://gist.githubusercontent.com/peleg-development/9cb25936b605d6a1e78c005b5001000d/raw/9e885cafc86c4ece1a9142b27e3c8dc8308b5b51/version.json"

---@param v string|nil
---@return integer, integer, integer
local function parseSemVer(v)
  if type(v) ~= 'string' then return 0, 0, 0 end
  local a, b, c = 0, 0, 0
  local i = 1
  for num in v:gmatch('%d+') do
    local n = tonumber(num) or 0
    if i == 1 then a = n elseif i == 2 then b = n else c = n end
    i = i + 1
    if i > 3 then break end
  end
  return a, b, c
end

---@param lv string|nil
---@param rv string|nil
---@return integer
local function compareSemVer(lv, rv)
  local la, lb, lc = parseSemVer(lv)
  local ra, rb, rc = parseSemVer(rv)
  if la ~= ra then return la < ra and -1 or 1 end
  if lb ~= rb then return lb < rb and -1 or 1 end
  if lc ~= rc then return lc < rc and -1 or 1 end
  return 0
end

---@param s any
---@return string
local function strip_colors(s)
  return tostring(s or ''):gsub('%^%d', '')
end

---@param s string
---@return integer
local function utf8_len(s)
  local n = 0
  for _ in s:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
    n = n + 1
  end
  return n
end

---@param s any
---@return integer
local function vlen(s)
  return utf8_len(strip_colors(tostring(s or '')))
end

---@param s string
---@param width integer
---@return string[]
local function wrap(s, width)
  s = tostring(s or '')
  if width <= 0 then return { s } end
  local out, line, col = {}, '', 0

  local function hardbreak_long_word(word)
    local acc, acc_len = '', 0
    for ch in word:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
      local clen = 1
      if acc_len + clen > width then
        table.insert(out, acc)
        acc, acc_len = ch, 1
      else
        acc = acc .. ch
        acc_len = acc_len + 1
      end
    end
    return acc, acc_len
  end

  for word, space in s:gmatch('(%S+)(%s*)') do
    local wlen = vlen(word)
    if col > 0 then
      if col + 1 + wlen > width then
        table.insert(out, line)
        line, col = word, wlen
      else
        line = line .. ' ' .. word
        col = col + 1 + wlen
      end
    else
      if wlen > width then
        line, col = hardbreak_long_word(word)
      else
        line, col = word, wlen
      end
    end

    if space:find('\n', 1, true) then
      table.insert(out, line)
      line, col = '', 0
    end
  end

  if #line > 0 then table.insert(out, line) end
  if #out == 0 then out[1] = '' end
  return out
end

---@param title string
---@param kv table<string, any>
---@param kind 'ok'|'update'|'warn'|'error'
local function printBanner(title, kv, kind)
  local color = '^2' -- ok / success
  if kind == 'update' or kind == 'warn' then color = '^3' elseif kind == 'error' then color = '^1' end
  local reset = '^0'

  local W = 66
  local function hr(ch) return string.rep(ch, W) end
  local function emit(line) print(color .. line .. reset) end

  emit('┌' .. hr('─') .. '┐')
  local head = ' ' .. tostring(title or '') .. ' '
  local pad = math.max(0, W - vlen(head))
  emit('│' .. head .. string.rep(' ', pad) .. '│')
  emit('├' .. hr('─') .. '┤')

  local keys, n = {}, 0
  for k in pairs(kv or {}) do
    n = n + 1; keys[n] = k
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

  for _, k in ipairs(keys) do
    local key = tostring(k)
    local val = kv[k]
    if val == nil then val = '' end
    val              = tostring(val)

    local key_len    = vlen(key)
    local left_first = ' ' .. key .. ': '
    local left_next  = ' ' .. string.rep(' ', key_len + 2)
    local avail      = W - vlen(left_first)

    local lines      = wrap(val, avail)
    for i, ln in ipairs(lines) do
      local left = (i == 1) and left_first or left_next
      local full = left .. ln
      local fill = math.max(0, W - vlen(full))
      emit('│' .. full .. string.rep(' ', fill) .. '│')
    end
  end

  emit('└' .. hr('─') .. '┘')
end

local function getLocalVersion()
  local v = GetResourceMetadata(RESOURCE_NAME, 'version', 0)
  if v == nil or v == '' then return nil end
  return v
end

local function extractRemoteInfo(tbl)
  if type(tbl) ~= 'table' then return nil end
  local v = tbl.version or tbl.latest or tbl.tag_name or tbl.versionNumber or tbl.current
  local msg = tbl.message or tbl.note or tbl.name or tbl.title or tbl.description or ''
  local url = tbl.download or tbl.url or tbl.html_url or tbl.homepage or '—'
  return { version = tostring(v or ''), message = tostring(msg or ''), url = tostring(url or '—') }
end

local function doCheck()
  local localVersion = getLocalVersion()
  if not localVersion then
    printBanner('peleg-impoundlot — Version Check', {
      Status = 'No version found in fxmanifest. Add: version "x.y.z"',
      Resource = RESOURCE_NAME,
    }, 'warn')
    return
  end

  PerformHttpRequest(CHECK_URL, function(code, body, _headers)
    if type(code) ~= 'number' or code < 200 or code >= 300 or type(body) ~= 'string' or body == '' then
      printBanner('peleg-impoundlot — Version Check', {
        Status = ('HTTP error while checking updates (code %s)'):format(tostring(code)),
        Resource = RESOURCE_NAME,
        Local = 'v' .. localVersion,
        Remote = 'unavailable',
      }, 'warn')
      return
    end

    local ok, decoded = pcall(function() return json.decode(body) end)
    if not ok then
      printBanner('peleg-impoundlot — Version Check', {
        Status = 'Failed to parse update JSON.',
        Resource = RESOURCE_NAME,
        Local = 'v' .. localVersion,
      }, 'error')
      return
    end

    local info = extractRemoteInfo(decoded)
    if not info or info.version == '' then
      printBanner('peleg-impoundlot — Version Check', {
        Status = 'Remote JSON missing version field.',
        Resource = RESOURCE_NAME,
        Local = 'v' .. localVersion,
      }, 'error')
      return
    end

    local cmp = compareSemVer(localVersion, info.version)
    if cmp < 0 then
      printBanner('peleg-impoundlot — UPDATE AVAILABLE     ', {
        Current = 'v' .. localVersion .. " ",
        Latest  = 'v' .. info.version .. " ",
        Note    = info.message ~= '' and ('"' .. info.message .. '"') or '—',
        URL     = info.url,
      }, 'update')
    elseif cmp == 0 then
      print(('^2[peleg-impoundlot]^0 Up to date (v%s).'):format(localVersion))
    else
      print(('^3[peleg-impoundlot]^0 Local version (v%s) is newer than remote (v%s).'):format(localVersion, info.version))
    end
  end, 'GET')
end

CreateThread(function()
  Wait(2000)
  doCheck()
end)
