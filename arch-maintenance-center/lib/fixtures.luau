local function import(name)
  local ok, value = pcall(require, "./" .. name .. ".luau")
  if ok then
    return value
  end
  return require("./" .. name)
end

local Cleanup = import("cleanup")
local Disk = import("disk")
local Health = import("health")
local Logs = import("logs")
local Recommendations = import("recommendations")
local Services = import("services")
local Updates = import("updates")

local Fixtures = {}

local DAY_MS = 24 * 60 * 60 * 1000
local TOTAL_BYTES = 100 * 1024 * 1024 * 1024
local IDS = {
  "healthy",
  "recommendations",
  "attention",
  "critical",
  "incomplete",
  "all_checks_failed",
  "collecting",
  "platform_checking",
  "platform_unsupported",
  "platform_error",
}

local KNOWN = {}
for _, id in ipairs(IDS) do
  KNOWN[id] = true
end

local function packageSummary(count, packages)
  local lines = {}
  for _, package in ipairs(packages or {}) do
    table.insert(lines, table.concat({
      "package",
      package.name,
      package.installedVersion,
      package.availableVersion,
    }, "\t"))
  end
  table.insert(lines, "count\t" .. tostring(count))
  return table.concat(lines, "\n")
end

local function updates(nowMs, count, days)
  local packages = count > 0 and {
    { name = "demo-kernel", installedVersion = "1.0.0", availableVersion = "1.1.0" },
    { name = "demo-browser", installedVersion = "2.4.0", availableVersion = "2.5.0" },
  } or {}
  local value = Updates.fromSummary(
    count == 0 and 2 or 0,
    packageSummary(count, packages),
    "",
    nowMs
  )
  if days ~= nil then
    value.data.lastUpgradeMs = math.max(0, nowMs - days * DAY_MS)
    value.data.daysSinceLastUpgrade = days
    if count > 0 then
      value.severity = days >= Recommendations.staleDays() and "warning" or "info"
    end
  end
  return value
end

local function services(nowMs, systemCount, userCount, userAvailable)
  local systemLines = {}
  if systemCount > 0 then
    table.insert(systemLines, "unit\tdemo-network.service loaded failed failed Synthetic network service")
  end
  if systemCount > 1 then
    table.insert(systemLines, "unit\tdemo-backup.service loaded failed failed Synthetic backup service")
  end
  table.insert(systemLines, "count\t" .. tostring(systemCount))

  local userLines = {}
  if userCount > 0 then
    table.insert(userLines, "unit\tdemo-session.service loaded failed failed Synthetic user service")
  end
  table.insert(userLines, "count\t" .. tostring(userCount))
  return Services.fromScopes(
    0,
    table.concat(systemLines, "\n"),
    userAvailable == false and 1 or 0,
    table.concat(userLines, "\n"),
    nowMs
  )
end

local function disk(nowMs, usagePercent)
  return Disk.fromStats({
    usagePercent = usagePercent,
    totalBytes = TOTAL_BYTES,
    availableBytes = math.floor(TOTAL_BYTES * (100 - usagePercent) / 100),
  }, nowMs)
end

local function cleanup(nowMs, orphanCount, journalAvailable)
  local packageLines = {}
  if orphanCount > 0 then
    table.insert(packageLines, "package\tdemo-orphan-tool")
  end
  if orphanCount > 1 then
    table.insert(packageLines, "package\tdemo-orphan-library")
  end
  table.insert(packageLines, "count\t" .. tostring(orphanCount))
  return Cleanup.aggregate(
    Cleanup.cacheFromDu(0, "536870912\t/var/cache/pacman/pkg\n"),
    Cleanup.orphansFromSummary(orphanCount == 0 and 1 or 0, table.concat(packageLines, "\n")),
    journalAvailable == false
      and Cleanup.error("demo_journal_unavailable")
      or Cleanup.journalFromUsage(0, "Archived and active journals take up 256.0M in the file system."),
    nowMs
  )
end

local function event(nowMs, index, scope)
  return {
    scope = scope,
    timestampMs = nowMs - index * 60000,
    priority = 3,
    source = "demo-journal",
    message = "Synthetic demo journal event " .. tostring(index),
  }
end

local function logs(nowMs, count, userAvailable)
  local systemEvents = {}
  for index = 1, count do
    table.insert(systemEvents, event(nowMs, index, "system"))
  end
  return Logs.fromScopes(
    0,
    systemEvents,
    userAvailable == false and 1 or 0,
    {},
    nowMs,
    nil,
    userAvailable == false and "demo_user_journal_unavailable" or nil
  )
end

local function readySnapshot(id, nowMs, modules)
  local recommendations = Recommendations.fromModules(modules)
  return {
    source = { kind = "fixture", fixtureId = id },
    platform = { state = "supported", id = "arch" },
    refreshing = false,
    collectedAtMs = nowMs,
    modules = modules,
    recommendations = recommendations,
    health = Health.aggregate(modules, recommendations),
  }
end

local function emptySnapshot(id, platform, refreshing, nowMs)
  local modules = {}
  return {
    source = { kind = "fixture", fixtureId = id },
    platform = platform,
    refreshing = refreshing,
    collectedAtMs = nil,
    modules = modules,
    recommendations = {},
    health = Health.aggregate(modules, {}),
    generatedAtMs = nowMs,
  }
end

local function buildReady(id, nowMs)
  if id == "healthy" then
    return readySnapshot(id, nowMs, {
      updates = updates(nowMs, 0, 1),
      services = services(nowMs, 0, 0, true),
      disk = disk(nowMs, 42),
      cleanup = cleanup(nowMs, 0, true),
      logs = logs(nowMs, 0, true),
    })
  elseif id == "recommendations" then
    return readySnapshot(id, nowMs, {
      updates = updates(nowMs, 5, 1),
      services = services(nowMs, 0, 0, true),
      disk = disk(nowMs, 52),
      cleanup = cleanup(nowMs, 2, true),
      logs = logs(nowMs, 3, true),
    })
  elseif id == "attention" then
    return readySnapshot(id, nowMs, {
      updates = updates(nowMs, 12, 21),
      services = services(nowMs, 2, 0, true),
      disk = disk(nowMs, 85),
      cleanup = cleanup(nowMs, 0, true),
      logs = logs(nowMs, 4, true),
    })
  elseif id == "critical" then
    return readySnapshot(id, nowMs, {
      updates = updates(nowMs, 24, 30),
      services = services(nowMs, 1, 0, true),
      disk = disk(nowMs, 92),
      cleanup = cleanup(nowMs, 3, true),
      logs = logs(nowMs, Logs.eventLimit() + 1, true),
    })
  elseif id == "incomplete" then
    return readySnapshot(id, nowMs, {
      updates = Updates.error(nowMs, "demo_updates_unavailable"),
      services = services(nowMs, 0, 0, false),
      disk = disk(nowMs, 60),
      cleanup = cleanup(nowMs, 4, false),
      logs = logs(nowMs, 1, false),
    })
  elseif id == "all_checks_failed" then
    return readySnapshot(id, nowMs, {
      updates = Updates.error(nowMs, "demo_updates_failed"),
      services = Services.error(nowMs, "demo_services_failed"),
      disk = Disk.error(nowMs, "demo_disk_failed"),
      cleanup = Cleanup.aggregate(
        Cleanup.error("demo_cache_failed"),
        Cleanup.error("demo_orphans_failed"),
        Cleanup.error("demo_journal_failed"),
        nowMs
      ),
      logs = Logs.error(nowMs, "demo_logs_failed"),
    })
  end
  return nil
end

function Fixtures.ids()
  local values = {}
  for index, id in ipairs(IDS) do
    values[index] = id
  end
  return values
end

function Fixtures.contains(id)
  return type(id) == "string" and KNOWN[id] == true
end

function Fixtures.build(id, nowMs)
  if not Fixtures.contains(id)
    or type(nowMs) ~= "number"
    or nowMs ~= nowMs
    or nowMs == math.huge
    or nowMs < 0
  then
    return nil
  end
  local ready = buildReady(id, nowMs)
  if ready ~= nil then
    return ready
  elseif id == "collecting" then
    return emptySnapshot(id, { state = "supported", id = "arch" }, true, nowMs)
  elseif id == "platform_checking" then
    return emptySnapshot(id, { state = "checking" }, false, nowMs)
  elseif id == "platform_unsupported" then
    return emptySnapshot(id, { state = "unsupported", id = "fedora", detail = "unsupported_id" }, false, nowMs)
  end
  return emptySnapshot(id, { state = "error", detail = "read_failed" }, false, nowMs)
end

return Fixtures
