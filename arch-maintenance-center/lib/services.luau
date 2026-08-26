local Services = {}

local UNIT_SAMPLE_LIMIT = 20

local function trim(value)
  return (string.gsub(value or "", "^%s*(.-)%s*$", "%1"))
end

local function result(state, severity, checkedAtMs, summary, detail, data)
  return {
    state = state,
    severity = severity,
    checkedAtMs = checkedAtMs,
    summary = summary,
    detail = detail,
    data = data or {},
  }
end

local function cleanDescription(value)
  local characters = {}
  for index = 1, #(value or "") do
    local byte = string.byte(value, index)
    if byte ~= nil then
      table.insert(characters, (byte < 32 or byte == 127) and " " or string.char(byte))
    end
  end
  local cleaned = trim(table.concat(characters))
  if #cleaned > 240 then
    cleaned = string.sub(cleaned, 1, 237) .. "..."
  end
  return cleaned
end

function Services.isSafeUnitName(value)
  if type(value) ~= "string" or value == "" or #value > 256 or string.sub(value, 1, 1) == "-" then
    return false
  end
  for index = 1, #value do
    local character = string.sub(value, index, index)
    if string.match(character, "[%w@_.:%-]") == nil and character ~= "\\" then
      return false
    end
  end
  return true
end

function Services.parseFailed(output, scope)
  if type(output) ~= "string" then
    return nil, "invalid_output"
  end

  local units = {}
  for rawLine in string.gmatch(output .. "\n", "(.-)\r?\n") do
    local line = trim(rawLine)
    if line ~= "" then
      local name, loadState, activeState, subState, description = string.match(
        line,
        "^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.+)$"
      )
      if name == nil then
        return nil, "malformed_line"
      end
      table.insert(units, {
        name = name,
        scope = scope,
        loadState = loadState,
        activeState = activeState,
        subState = subState,
        description = cleanDescription(description),
        commandSafe = Services.isSafeUnitName(name),
      })
    end
  end
  return units
end

function Services.parseScope(output, scope)
  if type(output) ~= "string" then
    return nil, "invalid_output"
  end

  local count = nil
  local units = {}
  for rawLine in string.gmatch(output .. "\n", "(.-)\r?\n") do
    if rawLine ~= "" then
      local label, value = string.match(rawLine, "^(%a+)\t(.*)$")
      if label == "unit" then
        local parsed, parseError = Services.parseFailed(value, scope)
        if parsed == nil or #parsed ~= 1 then
          return nil, parseError or "malformed_line"
        end
        table.insert(units, parsed[1])
      elseif label == "count" then
        if count ~= nil then
          return nil, "duplicate_count"
        end
        count = tonumber(value)
        if count == nil or count < 0 or math.floor(count) ~= count then
          return nil, "invalid_count"
        end
      else
        return nil, "malformed_line"
      end
    end
  end
  if count == nil or count < #units then
    return nil, "invalid_count"
  end
  return {
    count = count,
    units = units,
    truncated = count > #units,
  }
end

function Services.error(checkedAtMs, detail)
  return result("error", "unknown", checkedAtMs, "services_error", detail or "command_failed")
end

function Services.fromScopes(systemExitCode, systemOutput, userExitCode, userOutput, checkedAtMs)
  if systemExitCode ~= 0 then
    return Services.error(checkedAtMs, "system_scope_failed")
  end

  local system, parseError = Services.parseScope(systemOutput or "", "system")
  if system == nil then
    return Services.error(checkedAtMs, parseError)
  end

  local units = system.units
  local systemCount = system.count
  local userScopeAvailable = userExitCode == 0
  local userCount = 0
  local userTruncated = false
  if userScopeAvailable then
    local user, userParseError = Services.parseScope(userOutput or "", "user")
    if user == nil then
      return Services.error(checkedAtMs, userParseError)
    end
    for _, unit in ipairs(user.units) do
      table.insert(units, unit)
    end
    userCount = user.count
    userTruncated = user.truncated
  end

  table.sort(units, function(left, right)
    if left.scope == right.scope then
      return left.name < right.name
    end
    return left.scope < right.scope
  end)

  local totalCount = systemCount + userCount
  local value = result("ready", totalCount > 0 and "warning" or "ok", checkedAtMs, totalCount > 0 and "services_failed" or "services_healthy", nil, {
    count = totalCount,
    systemCount = systemCount,
    userCount = userCount,
    units = units,
    unitsTruncated = system.truncated or userTruncated,
    systemUnitsTruncated = system.truncated,
    userUnitsTruncated = userTruncated,
    userScopeAvailable = userScopeAvailable,
  })
  value.complete = userScopeAvailable
  return value
end

function Services.unitSampleLimit()
  return UNIT_SAMPLE_LIMIT
end

return Services
