local Disk = {}

local WARNING_PERCENT = 80
local CRITICAL_PERCENT = 90

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

local function ready(usagePercent, totalBytes, availableBytes, checkedAtMs, source)
  local severity = "ok"
  if usagePercent >= CRITICAL_PERCENT then
    severity = "critical"
  elseif usagePercent >= WARNING_PERCENT then
    severity = "warning"
  end
  return result("ready", severity, checkedAtMs, "disk_usage", nil, {
    path = "/",
    usagePercent = usagePercent,
    totalBytes = totalBytes,
    availableBytes = availableBytes,
    source = source,
  })
end

function Disk.error(checkedAtMs, detail)
  return result("error", "unknown", checkedAtMs, "disk_error", detail or "command_failed")
end

function Disk.fromStats(stats, checkedAtMs)
  if type(stats) ~= "table"
    or type(stats.usagePercent) ~= "number"
    or type(stats.totalBytes) ~= "number"
    or type(stats.availableBytes) ~= "number"
  then
    return nil
  end
  return ready(stats.usagePercent, stats.totalBytes, stats.availableBytes, checkedAtMs, "noctalia")
end

function Disk.parseDf(output)
  if type(output) ~= "string" then
    return nil, "invalid_output"
  end

  local rows = {}
  for line in string.gmatch(output .. "\n", "(.-)\r?\n") do
    if string.match(line, "%S") ~= nil then
      table.insert(rows, line)
    end
  end
  if #rows < 2 then
    return nil, "malformed_output"
  end

  local total, available, percent, path = string.match(rows[#rows], "^%s*(%d+)%s+(%d+)%s+(%d+)%%%s+(.+)%s*$")
  total = tonumber(total)
  available = tonumber(available)
  percent = tonumber(percent)
  if total == nil or available == nil or percent == nil or path ~= "/" or percent < 0 or percent > 100 then
    return nil, "malformed_output"
  end
  return {
    usagePercent = percent,
    totalBytes = total,
    availableBytes = available,
  }
end

function Disk.fromDf(exitCode, output, checkedAtMs)
  if exitCode ~= 0 then
    return Disk.error(checkedAtMs, "command_failed")
  end
  local stats, parseError = Disk.parseDf(output or "")
  if stats == nil then
    return Disk.error(checkedAtMs, parseError)
  end
  return ready(stats.usagePercent, stats.totalBytes, stats.availableBytes, checkedAtMs, "df")
end

return Disk
