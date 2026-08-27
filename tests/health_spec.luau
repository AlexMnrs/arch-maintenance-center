local A = require("./assertions")
local Health = require("../arch-maintenance-center/lib/health")

local function module(state, severity)
  return { state = state, severity = severity }
end

local function full(updates, services, disk, cleanup, logs)
  return {
    updates = updates or module("ready", "ok"),
    services = services or module("ready", "ok"),
    disk = disk or module("ready", "ok"),
    cleanup = cleanup or module("ready", "ok"),
    logs = logs or module("ready", "ok"),
  }
end

local healthy = Health.aggregate(full(), {})
A.equal(healthy.severity, "ok", "informational module does not warn globally")
A.equal(healthy.complete, true, "all modules complete")
A.equal(healthy.recommendationCount, 0, "clean modules need no recommendations")

local informational = Health.aggregate(full(module("ready", "info")), {})
A.equal(informational.severity, "ok", "information stays distinct from warning")
A.equal(informational.recommendationCount, 0, "informational modules do not create recommendations")

local recommended = Health.aggregate(full(module("ready", "info")), { { id = "updates_available" } })
A.equal(recommended.recommendationCount, 1, "recommendations are counted separately")

local warning = Health.aggregate(full(module("ready", "warning")))
A.equal(warning.severity, "warning", "warning propagated")
A.equal(warning.issueCount, 1, "warning counted")

local critical = Health.aggregate(full(module("ready", "warning"), module("ready", "warning"), module("ready", "critical")))
A.equal(critical.severity, "critical", "critical wins")
A.equal(critical.issueCount, 3, "issues counted by module")

local incomplete = Health.aggregate(full(module("unavailable", "unknown")))
A.equal(incomplete.complete, false, "unavailable module incomplete")
A.equal(incomplete.unavailableCount, 1, "unavailable counted")
A.equal(incomplete.unavailableModules[1], "updates", "unavailable module named")
A.equal(incomplete.severity, "ok", "known health remains separate from completeness")

local partial = Health.aggregate(full(nil, { state = "ready", severity = "ok", complete = false }))
A.equal(partial.complete, false, "partial ready module keeps diagnosis incomplete")
A.equal(partial.unavailableModules[1], "services", "partial module is traceable")

print("health_spec passed")
