local Recommendations = {}

local STALE_DAYS = 14
local PRIORITY = {
  critical = 3,
  warning = 2,
  info = 1,
}
local MODULE_ORDER = {
  services = 1,
  disk = 2,
  updates = 3,
  cleanup = 4,
}

local function wholeNumber(value)
  if type(value) ~= "number" then
    return nil
  end
  local numeric = value :: number
  if numeric ~= numeric or numeric == math.huge or numeric < 0 or math.floor(numeric) ~= numeric then
    return nil
  end
  return numeric
end

local function insert(actions, id, module, severity, data)
  table.insert(actions, {
    id = id,
    module = module,
    severity = severity,
    data = data,
  })
end

local function collectUpdates(actions, module)
  if type(module) ~= "table" or module.state ~= "ready" then
    return
  end
  local count = wholeNumber(module.data and module.data.count)
  if count == nil or count == 0 then
    return
  end
  local days = wholeNumber(module.data and module.data.daysSinceLastUpgrade)
  insert(actions, "updates_available", "updates", days ~= nil and days >= STALE_DAYS and "warning" or "info", {
    count = count,
    daysSinceLastUpgrade = days,
  })
end

local function collectServices(actions, module)
  if type(module) ~= "table" or module.state ~= "ready" then
    return
  end
  local count = wholeNumber(module.data and module.data.count)
  if count ~= nil and count > 0 then
    insert(actions, "failed_units", "services", "warning", { count = count })
  end
end

local function collectDisk(actions, module)
  if type(module) ~= "table" or module.state ~= "ready" then
    return
  end
  local usage = module.data and module.data.usagePercent
  if type(usage) ~= "number" or usage ~= usage or usage == math.huge or usage < 80 or usage > 100 then
    return
  end
  local available = module.data and module.data.availableBytes
  insert(actions, "low_disk_space", "disk", usage >= 90 and "critical" or "warning", {
    usagePercent = usage,
    availableBytes = type(available) == "number" and available == available and available ~= math.huge and available >= 0 and available or nil,
  })
end

local function collectCleanup(actions, module)
  if type(module) ~= "table" or module.state ~= "ready" then
    return
  end
  local orphans = module.data and module.data.orphans
  local count = type(orphans) == "table" and orphans.state == "ready"
    and wholeNumber(orphans.data and orphans.data.count) or nil
  if count ~= nil and count > 0 then
    insert(actions, "orphan_packages", "cleanup", "info", { count = count })
  end
end

function Recommendations.fromModules(modules)
  modules = type(modules) == "table" and modules or {}
  local actions = {}
  collectUpdates(actions, modules.updates)
  collectServices(actions, modules.services)
  collectDisk(actions, modules.disk)
  collectCleanup(actions, modules.cleanup)
  table.sort(actions, function(left, right)
    local leftPriority = PRIORITY[left.severity] or 0
    local rightPriority = PRIORITY[right.severity] or 0
    if leftPriority ~= rightPriority then
      return leftPriority > rightPriority
    end
    local leftModule = MODULE_ORDER[left.module] or math.huge
    local rightModule = MODULE_ORDER[right.module] or math.huge
    if leftModule ~= rightModule then
      return leftModule < rightModule
    end
    return left.id < right.id
  end)
  return actions
end

function Recommendations.staleDays()
  return STALE_DAYS
end

return Recommendations
