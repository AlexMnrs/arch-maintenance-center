local Health = {}

local RANK = {
  unknown = 0,
  ok = 0,
  info = 0,
  warning = 1,
  critical = 2,
}

local ORDER = { "updates", "services", "disk", "cleanup", "logs" }

function Health.aggregate(modules, recommendations)
  modules = type(modules) == "table" and modules or {}
  recommendations = type(recommendations) == "table" and recommendations or {}
  local severity = "ok"
  local rank = 0
  local complete = true
  local issueCount = 0
  local unavailableCount = 0
  local unavailableModules = {}

  for _, name in ipairs(ORDER) do
    local module = modules[name]
    if type(module) ~= "table" or module.state ~= "ready" or module.complete == false then
      complete = false
      unavailableCount = unavailableCount + 1
      table.insert(unavailableModules, name)
    end
    if type(module) == "table" and module.state == "ready" then
      local moduleRank = RANK[module.severity] or 0
      if moduleRank > rank then
        rank = moduleRank
        severity = module.severity
      end
      if module.severity == "warning" or module.severity == "critical" then
        issueCount = issueCount + 1
      end
    end
  end

  return {
    severity = severity,
    complete = complete,
    issueCount = issueCount,
    unavailableCount = unavailableCount,
    unavailableModules = unavailableModules,
    recommendationCount = #recommendations,
  }
end

return Health
