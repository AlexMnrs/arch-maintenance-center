local Cleanup = {}

local PACKAGE_SAMPLE_LIMIT = 8
local SIZE_MULTIPLIERS = {
  B = 1,
  K = 1024,
  M = 1024 * 1024,
  G = 1024 * 1024 * 1024,
  T = 1024 * 1024 * 1024 * 1024,
  P = 1024 * 1024 * 1024 * 1024 * 1024,
}

local function trim(value)
  return (string.gsub(value or "", "^%s*(.-)%s*$", "%1"))
end

local function signal(state, detail, data)
  return {
    state = state,
    detail = detail,
    data = data or {},
  }
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

local function parseInteger(value)
  local digits = string.match(value or "", "^%s*(%d+)%s*$")
  if digits == nil or #digits > 18 then
    return nil
  end
  return tonumber(digits)
end

function Cleanup.error(detail)
  return signal("error", detail or "command_failed")
end

function Cleanup.cacheFromDu(exitCode, output)
  if exitCode ~= 0 then
    return Cleanup.error("command_failed")
  end
  if type(output) ~= "string" then
    return Cleanup.error("invalid_output")
  end

  local bytes = parseInteger(string.match(output, "^%s*(%d+)%s+%S+%s*$"))
  if bytes == nil then
    return Cleanup.error("malformed_output")
  end
  return signal("ready", nil, { bytes = bytes })
end

function Cleanup.parseOrphanSummary(output)
  if type(output) ~= "string" then
    return nil, "invalid_output"
  end

  local count = nil
  local packages = {}
  for rawLine in string.gmatch(output .. "\n", "(.-)\r?\n") do
    if rawLine ~= "" then
      local label, value = string.match(rawLine, "^(%a+)\t(.*)$")
      if label == "package" then
        local name = trim(value)
        if name == "" or #name > 256 or string.match(name, "^[%w@_.+%-]+$") == nil then
          return nil, "malformed_package"
        end
        table.insert(packages, name)
      elseif label == "count" then
        if count ~= nil then
          return nil, "duplicate_count"
        end
        count = parseInteger(value)
        if count == nil then
          return nil, "invalid_count"
        end
      else
        return nil, "malformed_line"
      end
    end
  end

  if count == nil or count < #packages then
    return nil, "invalid_count"
  end
  return {
    count = count,
    packages = packages,
    truncated = count > #packages,
  }
end

function Cleanup.orphansFromSummary(exitCode, output)
  if exitCode ~= 0 and exitCode ~= 1 then
    return Cleanup.error("command_failed")
  end
  local parsed, parseError = Cleanup.parseOrphanSummary(output)
  if parsed == nil then
    return Cleanup.error(parseError)
  end
  return signal("ready", nil, parsed)
end

function Cleanup.parseJournalUsage(output)
  if type(output) ~= "string" then
    return nil, "invalid_output"
  end

  local amount, unit = string.match(output, "take up%s+([%d%.]+)([BKMGTPE])%s+in the file system")
  amount = tonumber(amount)
  local multiplier = unit ~= nil and SIZE_MULTIPLIERS[unit] or nil
  if amount == nil or multiplier == nil or amount < 0 then
    return nil, "malformed_output"
  end
  return math.floor(amount * multiplier + 0.5)
end

function Cleanup.journalFromUsage(exitCode, output)
  if exitCode ~= 0 then
    return Cleanup.error("command_failed")
  end
  local bytes, parseError = Cleanup.parseJournalUsage(output)
  if bytes == nil then
    return Cleanup.error(parseError)
  end
  return signal("ready", nil, { bytes = bytes })
end

function Cleanup.aggregate(cache, orphans, journal, checkedAtMs)
  cache = cache or Cleanup.error("missing_result")
  orphans = orphans or Cleanup.error("missing_result")
  journal = journal or Cleanup.error("missing_result")

  local readyCount = 0
  for _, item in ipairs({ cache, orphans, journal }) do
    if item.state == "ready" then
      readyCount = readyCount + 1
    end
  end

  if readyCount == 0 then
    return result("error", "unknown", checkedAtMs, "cleanup_error", "all_sources_failed", {
      cache = cache,
      orphans = orphans,
      journal = journal,
    })
  end

  local orphanCount = type(orphans.data) == "table" and tonumber(orphans.data.count) or 0
  local value = result("ready", orphanCount > 0 and "info" or "ok", checkedAtMs, "cleanup_ready", nil, {
    cache = cache,
    orphans = orphans,
    journal = journal,
  })
  value.complete = readyCount == 3
  return value
end

function Cleanup.packageSampleLimit()
  return PACKAGE_SAMPLE_LIMIT
end

return Cleanup
