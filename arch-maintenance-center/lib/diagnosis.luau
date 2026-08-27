local Diagnosis = {}

local function isFixture(snapshot)
  return type(snapshot) == "table"
    and type(snapshot.source) == "table"
    and snapshot.source.kind == "fixture"
end

local function fixtureId(snapshot)
  return isFixture(snapshot) and type(snapshot.source.fixtureId) == "string" and snapshot.source.fixtureId or nil
end

local function safeNumber(value, fallback)
  return type(value) == "number" and value == value and value ~= math.huge and value >= 0 and value or fallback
end

local function formatUtc(value)
  if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 then
    return "unknown"
  end
  return os.date("!%Y-%m-%dT%H:%M:%SZ", math.floor(value / 1000))
end

function Diagnosis.shellQuote(value)
  value = tostring(value or "")
  return "'" .. string.gsub(value, "'", "'\"'\"'") .. "'"
end

local function isSafeUnitName(value)
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

local function isSupportedPlatform(snapshot)
  return type(snapshot) == "table"
    and type(snapshot.platform) == "table"
    and snapshot.platform.state == "supported"
    and snapshot.platform.id == "arch"
end

local function safePlatformId(value)
  if type(value) == "string" and #value <= 128 and string.match(value, "^[a-z0-9][a-z0-9._-]*$") ~= nil then
    return value
  end
  return "unknown"
end

local function recommendationLine(value)
  if type(value) ~= "table" or type(value.data) ~= "table" then
    return nil
  end
  local data = value.data
  if value.id == "updates_available" then
    local line = "- updates_available: " .. tostring(safeNumber(data.count, 0)) .. " pending"
    if type(data.daysSinceLastUpgrade) == "number"
      and data.daysSinceLastUpgrade == data.daysSinceLastUpgrade
      and data.daysSinceLastUpgrade ~= math.huge
      and data.daysSinceLastUpgrade ~= -math.huge
      and data.daysSinceLastUpgrade >= 0
    then
      line = line .. ", " .. tostring(math.floor(data.daysSinceLastUpgrade)) .. " days since full upgrade"
    end
    return line
  elseif value.id == "failed_units" then
    return "- failed_units: " .. tostring(safeNumber(data.count, 0))
  elseif value.id == "low_disk_space" then
    return "- low_disk_space: " .. tostring(math.floor(safeNumber(data.usagePercent, 0) + 0.5)) .. "% used"
  elseif value.id == "orphan_packages" then
    return "- orphan_packages: " .. tostring(safeNumber(data.count, 0))
  end
  return nil
end

function Diagnosis.format(snapshot)
  if type(snapshot) ~= "table" or type(snapshot.health) ~= "table" then
    return "Arch Maintenance Center diagnosis\nStatus: unavailable"
  end

  local platform = type(snapshot.platform) == "table" and snapshot.platform or { state = "error", detail = "missing_platform" }
  local lines = {
    "Arch Maintenance Center diagnosis",
    "Generated: " .. formatUtc(snapshot.collectedAtMs),
    isFixture(snapshot)
      and "Source: fixture (" .. tostring(fixtureId(snapshot)) .. ")"
      or "Source: real",
    "Platform: " .. tostring(platform.state or "unknown") .. (platform.id and " (" .. safePlatformId(platform.id) .. ")" or ""),
  }
  local health = snapshot.health
  local recommendations = type(snapshot.recommendations) == "table" and snapshot.recommendations or {}
  table.insert(lines, "Recommended actions: " .. tostring(safeNumber(health.recommendationCount, 0)))
  for _, recommendation in ipairs(recommendations) do
    local line = recommendationLine(recommendation)
    if line ~= nil then
      table.insert(lines, line)
    end
  end
  if not isSupportedPlatform(snapshot) then
    table.insert(lines, "Status: unavailable")
    return table.concat(lines, "\n")
  end

  table.insert(lines, "Status: " .. tostring(health.severity or "unknown"))
  table.insert(lines, "Complete: " .. (health.complete == true and "yes" or "no"))
  table.insert(lines, "Issues: " .. tostring(safeNumber(health.issueCount, 0)))
  table.insert(lines, "Unavailable modules: " .. tostring(safeNumber(health.unavailableCount, 0)))

  local modules = type(snapshot.modules) == "table" and snapshot.modules or {}
  local updates = modules.updates
  if type(updates) == "table" and updates.state == "ready" then
    local data = updates.data or {}
    table.insert(lines, "Updates: " .. tostring(safeNumber(data.count, 0)) .. " pending")
    if type(data.lastUpgradeMs) == "number" then
      table.insert(lines, "Last full upgrade: " .. formatUtc(data.lastUpgradeMs))
    else
      table.insert(lines, "Last full upgrade: unknown")
    end
  else
    table.insert(lines, "Updates: unavailable")
  end

  local services = modules.services
  if type(services) == "table" and services.state == "ready" then
    local data = services.data or {}
    table.insert(lines, "Failed services: " .. tostring(safeNumber(data.count, 0)))
    for _, unit in ipairs(type(data.units) == "table" and data.units or {}) do
      if isSafeUnitName(unit.name) then
        table.insert(lines, "- " .. tostring(unit.scope == "user" and "user" or "system") .. ":" .. unit.name)
      end
    end
  else
    table.insert(lines, "Services: unavailable")
  end

  local disk = modules.disk
  if type(disk) == "table" and disk.state == "ready" then
    table.insert(lines, "Root disk used: " .. tostring(math.floor(safeNumber(disk.data and disk.data.usagePercent, 0) + 0.5)) .. "%")
  else
    table.insert(lines, "Root disk: unavailable")
  end

  local cleanup = modules.cleanup
  if type(cleanup) == "table" and cleanup.state == "ready" then
    local data = cleanup.data or {}
    local cache = data.cache
    local orphans = data.orphans
    local journal = data.journal
    if type(cache) == "table" and cache.state == "ready" then
      table.insert(lines, "Pacman cache: " .. tostring(safeNumber(cache.data and cache.data.bytes, 0)) .. " bytes")
    else
      table.insert(lines, "Pacman cache: unavailable")
    end
    if type(orphans) == "table" and orphans.state == "ready" then
      table.insert(lines, "Orphan packages: " .. tostring(safeNumber(orphans.data and orphans.data.count, 0)))
    else
      table.insert(lines, "Orphan packages: unavailable")
    end
    if type(journal) == "table" and journal.state == "ready" then
      table.insert(lines, "Journal usage: " .. tostring(safeNumber(journal.data and journal.data.bytes, 0)) .. " bytes")
    else
      table.insert(lines, "Journal usage: unavailable")
    end
  else
    table.insert(lines, "Cleanup: unavailable")
  end

  local logs = modules.logs
  if type(logs) == "table" and logs.state == "ready" then
    local data = logs.data or {}
    table.insert(lines, "Journal errors shown: " .. tostring(safeNumber(data.count, 0)) .. (data.truncated == true and "+" or ""))
    table.insert(lines, "System journal available: " .. (data.systemAvailable == true and "yes" or "no"))
    table.insert(lines, "User journal available: " .. (data.userAvailable == true and "yes" or "no"))
  else
    table.insert(lines, "System logs: unavailable")
  end

  return table.concat(lines, "\n")
end

function Diagnosis.commands(snapshot)
  if isFixture(snapshot) or not isSupportedPlatform(snapshot) then
    return ""
  end
  local commands = {
    "checkupdates --nocolor",
    "df -h /",
    "du -sh /var/cache/pacman/pkg",
    "pacman -Qtdq",
    "journalctl --disk-usage",
    "journalctl -b -p err --no-pager -n 50",
    "journalctl --user -b -p err --no-pager -n 50",
  }
  local services = type(snapshot) == "table"
    and type(snapshot.modules) == "table"
    and snapshot.modules.services
    or nil
  local units = services ~= nil and services.state == "ready" and services.data and services.data.units or {}

  for _, unit in ipairs(type(units) == "table" and units or {}) do
    if isSafeUnitName(unit.name) then
      local quoted = Diagnosis.shellQuote(unit.name)
      if unit.scope == "user" then
        table.insert(commands, "systemctl --user status --no-pager " .. quoted)
        table.insert(commands, "journalctl --user -u " .. quoted .. " -b --no-pager -n 50")
      else
        table.insert(commands, "systemctl status --no-pager " .. quoted)
        table.insert(commands, "journalctl -u " .. quoted .. " -b --no-pager -n 50")
      end
    end
  end
  return table.concat(commands, "\n")
end

return Diagnosis
