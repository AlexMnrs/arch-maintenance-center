local A = require("./assertions")
local Health = require("../arch-maintenance-center/lib/health")

local function module(state, severity)
  return { state = state, severity = severity }
end

local healthy = Health.aggregate({
  updates = module("ready", "info"),
  services = module("ready", "ok"),
  disk = module("ready", "ok"),
})
A.equal(healthy.severity, "ok", "informational module does not warn globally")
A.equal(healthy.complete, true, "all modules complete")

local warning = Health.aggregate({
  updates = module("ready", "warning"),
  services = module("ready", "ok"),
  disk = module("ready", "ok"),
})
A.equal(warning.severity, "warning", "warning propagated")
A.equal(warning.issueCount, 1, "warning counted")

local critical = Health.aggregate({
  updates = module("ready", "warning"),
  services = module("ready", "warning"),
  disk = module("ready", "critical"),
})
A.equal(critical.severity, "critical", "critical wins")
A.equal(critical.issueCount, 3, "issues counted by module")

local incomplete = Health.aggregate({
  updates = module("unavailable", "unknown"),
  services = module("ready", "ok"),
  disk = module("ready", "ok"),
})
A.equal(incomplete.complete, false, "unavailable module incomplete")
A.equal(incomplete.unavailableCount, 1, "unavailable counted")
A.equal(incomplete.unavailableModules[1], "updates", "unavailable module named")
A.equal(incomplete.severity, "ok", "known health remains separate from completeness")

local partial = Health.aggregate({
  updates = module("ready", "ok"),
  services = { state = "ready", severity = "ok", complete = false },
  disk = module("ready", "ok"),
})
A.equal(partial.complete, false, "partial ready module keeps diagnosis incomplete")
A.equal(partial.unavailableModules[1], "services", "partial module is traceable")

print("health_spec passed")
