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

local function updates(models, nowMs, count, days)
  local Updates = models.Updates
  local Recommendations = models.Recommendations
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

local function services(models, nowMs, systemCount, userCount, userAvailable)
  local Services = models.Services
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

local function disk(models, nowMs, usagePercent)
  local Disk = models.Disk
  return Disk.fromStats({
    usagePercent = usagePercent,
    totalBytes = TOTAL_BYTES,
    availableBytes = math.floor(TOTAL_BYTES * (100 - usagePercent) / 100),
  }, nowMs)
end

local function cleanup(models, nowMs, orphanCount, journalAvailable)
  local Cleanup = models.Cleanup
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

local function logs(models, nowMs, count, userAvailable)
  local Logs = models.Logs
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

local function readySnapshot(models, id, nowMs, modules)
  local Health = models.Health
  local Recommendations = models.Recommendations
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

local function emptySnapshot(models, id, platform, refreshing, nowMs)
  local Health = models.Health
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

local function buildReady(models, id, nowMs)
  local Cleanup = models.Cleanup
  local Disk = models.Disk
  local Logs = models.Logs
  local Services = models.Services
  local Updates = models.Updates
  if id == "healthy" then
    return readySnapshot(models, id, nowMs, {
      updates = updates(models, nowMs, 0, 1),
      services = services(models, nowMs, 0, 0, true),
      disk = disk(models, nowMs, 42),
      cleanup = cleanup(models, nowMs, 0, true),
      logs = logs(models, nowMs, 0, true),
    })
  elseif id == "recommendations" then
    return readySnapshot(models, id, nowMs, {
      updates = updates(models, nowMs, 5, 1),
      services = services(models, nowMs, 0, 0, true),
      disk = disk(models, nowMs, 52),
      cleanup = cleanup(models, nowMs, 2, true),
      logs = logs(models, nowMs, 3, true),
    })
  elseif id == "attention" then
    return readySnapshot(models, id, nowMs, {
      updates = updates(models, nowMs, 12, 21),
      services = services(models, nowMs, 2, 0, true),
      disk = disk(models, nowMs, 85),
      cleanup = cleanup(models, nowMs, 0, true),
      logs = logs(models, nowMs, 4, true),
    })
  elseif id == "critical" then
    return readySnapshot(models, id, nowMs, {
      updates = updates(models, nowMs, 24, 30),
      services = services(models, nowMs, 1, 0, true),
      disk = disk(models, nowMs, 92),
      cleanup = cleanup(models, nowMs, 3, true),
      logs = logs(models, nowMs, Logs.eventLimit() + 1, true),
    })
  elseif id == "incomplete" then
    return readySnapshot(models, id, nowMs, {
      updates = Updates.error(nowMs, "demo_updates_unavailable"),
      services = services(models, nowMs, 0, 0, false),
      disk = disk(models, nowMs, 60),
      cleanup = cleanup(models, nowMs, 4, false),
      logs = logs(models, nowMs, 1, false),
    })
  elseif id == "all_checks_failed" then
    return readySnapshot(models, id, nowMs, {
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

local REQUIRED_MODELS = {
  Cleanup = { "aggregate", "cacheFromDu", "orphansFromSummary", "error", "journalFromUsage" },
  Disk = { "fromStats", "error" },
  Health = { "aggregate" },
  Logs = { "fromScopes", "eventLimit", "error" },
  Recommendations = { "fromModules", "staleDays" },
  Services = { "fromScopes", "error" },
  Updates = { "fromSummary", "error" },
}

local function validModels(models)
  if type(models) ~= "table" then
    return false
  end
  for name, functions in pairs(REQUIRED_MODELS) do
    local model = models[name]
    if type(model) ~= "table" then
      return false
    end
    for _, functionName in ipairs(functions) do
      if type(model[functionName]) ~= "function" then
        return false
      end
    end
  end
  return true
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

function Fixtures.build(id, nowMs, models)
  if not Fixtures.contains(id)
    or type(nowMs) ~= "number"
    or nowMs ~= nowMs
    or nowMs == math.huge
    or nowMs < 0
    or not validModels(models)
  then
    return nil
  end
  local ready = buildReady(models, id, nowMs)
  if ready ~= nil then
    return ready
  elseif id == "collecting" then
    return emptySnapshot(models, id, { state = "supported", id = "arch" }, true, nowMs)
  elseif id == "platform_checking" then
    return emptySnapshot(models, id, { state = "checking" }, false, nowMs)
  elseif id == "platform_unsupported" then
    return emptySnapshot(models, id, { state = "unsupported", id = "fedora", detail = "unsupported_id" }, false, nowMs)
  end
  return emptySnapshot(models, id, { state = "error", detail = "read_failed" }, false, nowMs)
end

return Fixtures
