local A = require("./assertions")
local Fixtures = require("../arch-maintenance-center/lib/fixtures")

local now = 1787824800000
local expectedIds = {
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

local ids = Fixtures.ids()
A.equal(#ids, #expectedIds, "fixture catalog size")
for index, id in ipairs(expectedIds) do
  A.equal(ids[index], id, "fixture catalog order " .. tostring(index))
  A.equal(Fixtures.contains(id), true, "fixture is recognized: " .. id)
  local snapshot = Fixtures.build(id, now)
  A.truthy(snapshot ~= nil, "fixture builds: " .. id)
  A.equal(snapshot.source.kind, "fixture", "fixture source kind: " .. id)
  A.equal(snapshot.source.fixtureId, id, "fixture source id: " .. id)
  A.truthy(type(snapshot.health) == "table", "fixture health exists: " .. id)
  A.truthy(type(snapshot.recommendations) == "table", "fixture recommendations exist: " .. id)
end

A.equal(Fixtures.contains("unknown"), false, "unknown fixture rejected")
A.equal(Fixtures.build("unknown", now), nil, "unknown fixture does not build")
A.equal(Fixtures.build("healthy", -1), nil, "invalid timestamp rejected")

local healthy = Fixtures.build("healthy", now)
A.equal(healthy.health.severity, "ok", "healthy fixture severity")
A.equal(healthy.health.complete, true, "healthy fixture complete")
A.equal(#healthy.recommendations, 0, "healthy fixture has no recommendations")
A.equal(healthy.modules.disk.data.usagePercent, 42, "healthy disk usage")

local recommendations = Fixtures.build("recommendations", now)
A.equal(recommendations.health.severity, "ok", "informational fixture remains healthy")
A.equal(recommendations.health.complete, true, "recommendations fixture complete")
A.equal(#recommendations.recommendations, 2, "informational recommendations count")
A.equal(recommendations.recommendations[1].id, "updates_available", "updates ordered before cleanup information")
A.equal(recommendations.recommendations[2].id, "orphan_packages", "orphans are second")

local attention = Fixtures.build("attention", now)
A.equal(attention.health.severity, "warning", "attention fixture severity")
A.equal(attention.health.issueCount, 3, "attention issue count")
A.equal(#attention.recommendations, 3, "attention recommendation count")

local critical = Fixtures.build("critical", now)
A.equal(critical.health.severity, "critical", "critical fixture severity")
A.equal(critical.health.issueCount, 3, "critical issue count")
A.equal(#critical.recommendations, 4, "critical fixture has expansion scenario")
A.equal(critical.recommendations[1].id, "low_disk_space", "critical disk recommendation first")
A.equal(critical.modules.logs.data.truncated, true, "critical logs are truncated")

local incomplete = Fixtures.build("incomplete", now)
A.equal(incomplete.health.complete, false, "incomplete fixture is partial")
A.equal(incomplete.health.severity, "ok", "incomplete fixture has no warning")
A.equal(#incomplete.recommendations, 1, "partial fixture retains known action")
A.equal(incomplete.recommendations[1].id, "orphan_packages", "partial cleanup action retained")

local failed = Fixtures.build("all_checks_failed", now)
A.equal(failed.health.complete, false, "failed checks are incomplete")
A.equal(failed.health.unavailableCount, 5, "all modules unavailable")
A.equal(#failed.recommendations, 0, "failed checks do not create actions")

local collecting = Fixtures.build("collecting", now)
A.equal(collecting.platform.state, "supported", "collecting platform supported")
A.equal(collecting.refreshing, true, "collecting fixture refreshes")
A.equal(collecting.collectedAtMs, nil, "collecting fixture has no completed time")

A.equal(Fixtures.build("platform_checking", now).platform.state, "checking", "platform checking fixture")
A.equal(Fixtures.build("platform_unsupported", now).platform.id, "fedora", "unsupported fixture id")
A.equal(Fixtures.build("platform_error", now).platform.state, "error", "platform error fixture")

local rebuilt = Fixtures.build("healthy", now + 1000)
A.equal(rebuilt.collectedAtMs, now + 1000, "fixture refresh updates timestamp")
A.equal(rebuilt.modules.disk.data.usagePercent, healthy.modules.disk.data.usagePercent, "fixture values are deterministic")

print("fixtures_spec passed")
