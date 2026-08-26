local Updates = {}

local DAY_MS = 24 * 60 * 60 * 1000
local STALE_DAYS = 14

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

function Updates.unavailable(checkedAtMs)
  return result("unavailable", "unknown", checkedAtMs, "updates_unavailable", "missing_checkupdates")
end

function Updates.error(checkedAtMs, detail)
  return result("error", "unknown", checkedAtMs, "updates_error", detail or "command_failed")
end

function Updates.parseCheckupdates(output)
  if type(output) ~= "string" then
    return nil, "invalid_output"
  end

  local packages = {}
  for rawLine in string.gmatch(output .. "\n", "(.-)\r?\n") do
    local line = trim(rawLine)
    if line ~= "" then
      local name, currentVersion, newVersion = string.match(line, "^(%S+)%s+(%S+)%s+%-%>%s+(%S+)$")
      if name == nil then
        return nil, "malformed_line"
      end
      table.insert(packages, {
        name = name,
        currentVersion = currentVersion,
        newVersion = newVersion,
      })
    end
  end
  return packages
end

function Updates.parseLastFullUpgrade(logText)
  if type(logText) ~= "string" then
    return nil
  end

  local latest = nil
  for line in string.gmatch(logText .. "\n", "(.-)\r?\n") do
    if string.find(line, "starting full system upgrade", 1, true) ~= nil then
      local year, month, day, hour, minute, second = string.match(
        line,
        "^%[(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)"
      )
      if year ~= nil then
        local timestamp = os.time({
          year = tonumber(year),
          month = tonumber(month),
          day = tonumber(day),
          hour = tonumber(hour),
          min = tonumber(minute),
          sec = tonumber(second),
        })
        if timestamp ~= nil and (latest == nil or timestamp > latest) then
          latest = timestamp
        end
      end
    end
  end
  return latest ~= nil and latest * 1000 or nil
end

function Updates.fromCommand(exitCode, output, logText, checkedAtMs)
  if exitCode ~= 0 and exitCode ~= 2 then
    return Updates.error(checkedAtMs, "command_failed")
  end

  local packages, parseError
  if exitCode == 2 then
    packages = {}
  else
    packages, parseError = Updates.parseCheckupdates(output or "")
    if packages == nil then
      return Updates.error(checkedAtMs, parseError)
    end
  end

  local lastUpgradeMs = Updates.parseLastFullUpgrade(logText)
  local daysSinceLastUpgrade = nil
  if lastUpgradeMs ~= nil and type(checkedAtMs) == "number" and checkedAtMs >= lastUpgradeMs then
    daysSinceLastUpgrade = math.floor((checkedAtMs - lastUpgradeMs) / DAY_MS)
  end

  local count = #packages
  local severity = "ok"
  local summary = "updates_current"
  if count > 0 then
    summary = "updates_pending"
    severity = daysSinceLastUpgrade ~= nil and daysSinceLastUpgrade >= STALE_DAYS and "warning" or "info"
  end

  return result("ready", severity, checkedAtMs, summary, nil, {
    count = count,
    packages = packages,
    lastUpgradeMs = lastUpgradeMs,
    daysSinceLastUpgrade = daysSinceLastUpgrade,
  })
end

return Updates
