local Updates = {}

local DAY_MS = 24 * 60 * 60 * 1000
local STALE_DAYS = 14

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

function Updates.parseCount(output)
  if type(output) ~= "string" then
    return nil, "invalid_count"
  end
  local digits = string.match(output, "^%s*(%d+)%s*$")
  if digits == nil or #digits > 9 then
    return nil, "invalid_count"
  end
  local count = tonumber(digits)
  if count == nil then
    return nil, "invalid_count"
  end
  return count
end

function Updates.parseLastFullUpgrade(logLine)
  if type(logLine) ~= "string" or string.find(logLine, "starting full system upgrade", 1, true) == nil then
    return nil
  end
  local year, month, day, hour, minute, second = string.match(
    logLine,
    "^%[(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)"
  )
  if year == nil then
    return nil
  end
  local timestamp = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(minute),
    sec = tonumber(second),
  })
  return timestamp ~= nil and timestamp * 1000 or nil
end

function Updates.fromCount(exitCode, output, logLine, checkedAtMs)
  if exitCode ~= 0 and exitCode ~= 2 then
    return Updates.error(checkedAtMs, "command_failed")
  end

  local count, parseError = Updates.parseCount(output)
  if count == nil or (exitCode == 2 and count ~= 0) then
    return Updates.error(checkedAtMs, parseError or "invalid_count")
  end

  local lastUpgradeMs = Updates.parseLastFullUpgrade(logLine)
  local daysSinceLastUpgrade = nil
  if lastUpgradeMs ~= nil and type(checkedAtMs) == "number" and checkedAtMs >= lastUpgradeMs then
    daysSinceLastUpgrade = math.floor((checkedAtMs - lastUpgradeMs) / DAY_MS)
  end

  local severity = "ok"
  local summary = "updates_current"
  if count > 0 then
    summary = "updates_pending"
    severity = daysSinceLastUpgrade ~= nil and daysSinceLastUpgrade >= STALE_DAYS and "warning" or "info"
  end

  return result("ready", severity, checkedAtMs, summary, nil, {
    count = count,
    lastUpgradeMs = lastUpgradeMs,
    daysSinceLastUpgrade = daysSinceLastUpgrade,
  })
end

return Updates
