local Services = {}

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
        description = trim(description),
        commandSafe = Services.isSafeUnitName(name),
      })
    end
  end
  return units
end

function Services.error(checkedAtMs, detail)
  return result("error", "unknown", checkedAtMs, "services_error", detail or "command_failed")
end

function Services.fromScopes(systemExitCode, systemOutput, userExitCode, userOutput, checkedAtMs)
  if systemExitCode ~= 0 then
    return Services.error(checkedAtMs, "system_scope_failed")
  end

  local units, parseError = Services.parseFailed(systemOutput or "", "system")
  if units == nil then
    return Services.error(checkedAtMs, parseError)
  end

  local userScopeAvailable = userExitCode == 0
  if userScopeAvailable then
    local userUnits, userParseError = Services.parseFailed(userOutput or "", "user")
    if userUnits == nil then
      return Services.error(checkedAtMs, userParseError)
    end
    for _, unit in ipairs(userUnits) do
      table.insert(units, unit)
    end
  end

  table.sort(units, function(left, right)
    if left.scope == right.scope then
      return left.name < right.name
    end
    return left.scope < right.scope
  end)

  return result("ready", #units > 0 and "warning" or "ok", checkedAtMs, #units > 0 and "services_failed" or "services_healthy", nil, {
    count = #units,
    units = units,
    userScopeAvailable = userScopeAvailable,
  })
end

return Services
