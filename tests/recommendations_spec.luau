local A = require("./assertions")
local Recommendations = require("../arch-maintenance-center/lib/recommendations")

local function modules(values)
  return values or {}
end

local none = Recommendations.fromModules(modules({
  updates = { state = "ready", data = { count = 0 } },
  services = { state = "ready", data = { count = 0 } },
  disk = { state = "ready", data = { usagePercent = 79.9 } },
  cleanup = {
    state = "ready",
    data = {
      cache = { state = "ready", data = { bytes = 1024 * 1024 * 1024 } },
      orphans = { state = "ready", data = { count = 0 } },
      journal = { state = "ready", data = { bytes = 1024 * 1024 * 1024 } },
    },
  },
  logs = { state = "ready", data = { count = 10 } },
}))
A.equal(#none, 0, "logs and storage context do not create recommendations")

local updates = Recommendations.fromModules({
  updates = { state = "ready", data = { count = 2, daysSinceLastUpgrade = 1 } },
})
A.equal(updates[1].id, "updates_available", "pending updates create an action")
A.equal(updates[1].severity, "info", "recent updates remain informational")

local stale = Recommendations.fromModules({
  updates = { state = "ready", data = { count = 2, daysSinceLastUpgrade = Recommendations.staleDays() } },
})
A.equal(stale[1].severity, "warning", "stale updates need attention")

local unknownAge = Recommendations.fromModules({
  updates = { state = "ready", data = { count = 2 } },
})
A.equal(unknownAge[1].severity, "info", "unknown upgrade age does not warn")

local partialCleanup = Recommendations.fromModules({
  cleanup = {
    state = "ready",
    complete = false,
    data = { orphans = { state = "ready", data = { count = 4 } } },
  },
})
A.equal(partialCleanup[1].id, "orphan_packages", "known orphans survive partial cleanup")

local ordered = Recommendations.fromModules({
  updates = { state = "ready", data = { count = 4, daysSinceLastUpgrade = 20 } },
  services = { state = "ready", data = { count = 2 } },
  disk = { state = "ready", data = { usagePercent = 95, availableBytes = 1024 } },
  cleanup = { state = "ready", data = { orphans = { state = "ready", data = { count = 1 } } } },
})
A.equal(ordered[1].id, "low_disk_space", "critical disk action comes first")
A.equal(ordered[2].id, "failed_units", "services win warning ties")
A.equal(ordered[3].id, "updates_available", "updates follow services")
A.equal(ordered[4].id, "orphan_packages", "cleanup information is last")

local invalid = Recommendations.fromModules({
  updates = { state = "ready", data = { count = -1 } },
  services = { state = "error", data = { count = 4 } },
  disk = { state = "ready", data = { usagePercent = math.huge } },
  cleanup = { state = "ready", data = { orphans = { state = "ready", data = { count = 1.5 } } } },
})
A.equal(#invalid, 0, "invalid and unavailable data stays out of actions")

print("recommendations_spec passed")
