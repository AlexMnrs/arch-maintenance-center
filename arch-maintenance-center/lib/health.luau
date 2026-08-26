local Health = {}

local RANK = {
  unknown = 0,
  ok = 0,
  info = 0,
  warning = 1,
  critical = 2,
}

local ORDER = { "updates", "services", "disk" }

function Health.aggregate(modules)
  modules = type(modules) == "table" and modules or {}
  local severity = "ok"
  local rank = 0
  local complete = true
  local issueCount = 0
  local unavailableCount = 0

  for _, name in ipairs(ORDER) do
    local module = modules[name]
    if type(module) ~= "table" or module.state ~= "ready" then
      complete = false
      unavailableCount = unavailableCount + 1
    else
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
  }
end

return Health
