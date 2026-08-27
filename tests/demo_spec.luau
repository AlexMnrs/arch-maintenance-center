local A = require("./assertions")
local Cleanup = require("../arch-maintenance-center/lib/cleanup")
local Demo = require("../arch-maintenance-center/lib/demo")
local Disk = require("../arch-maintenance-center/lib/disk")
local Fixtures = require("../arch-maintenance-center/lib/fixtures")
local Health = require("../arch-maintenance-center/lib/health")
local Logs = require("../arch-maintenance-center/lib/logs")
local Recommendations = require("../arch-maintenance-center/lib/recommendations")
local Services = require("../arch-maintenance-center/lib/services")
local Updates = require("../arch-maintenance-center/lib/updates")

local models = {
  Cleanup = Cleanup,
  Disk = Disk,
  Health = Health,
  Logs = Logs,
  Recommendations = Recommendations,
  Services = Services,
  Updates = Updates,
}

local function buildFixture(id, nowMs)
  return Fixtures.build(id, nowMs, models)
end

local fixture = buildFixture("critical", 1000)
A.equal(Demo.isFixture(fixture), true, "known fixture detected")
A.equal(Demo.fixtureId(fixture), "critical", "fixture id exposed")
A.equal(Demo.isFixture({ source = { kind = "real" } }), false, "real source is not fixture")
A.equal(Demo.isFixture({ source = { kind = "fixture", fixtureId = "unknown" } }), true, "fixture marker is recognized for safety")
A.equal(Demo.isFixture({}), false, "legacy snapshot is real")
A.equal(Demo.shouldCollect(nil), true, "real source collects")
A.equal(Demo.shouldCollect("critical"), false, "fixture source does not collect")
A.equal(Demo.acceptRealCallback(4, 4, nil), true, "current real callback accepted")
A.equal(Demo.acceptRealCallback(4, 5, nil), false, "stale callback rejected")
A.equal(Demo.acceptRealCallback(4, 4, "critical"), false, "callback rejected after fixture selection")

local fixturePublishes = 0
local realCollections = 0
local route = Demo.routeRefresh(
  "critical",
  1000,
  buildFixture,
  function(snapshot)
    fixturePublishes += 1
    A.equal(snapshot.source.fixtureId, "critical", "fixture route publishes selected data")
  end,
  function()
    realCollections += 1
  end
)
A.equal(route, "fixture", "fixture refresh route selected")
A.equal(fixturePublishes, 1, "fixture refresh publishes once")
A.equal(realCollections, 0, "fixture refresh does not collect real data")

route = Demo.routeRefresh("unknown", 1000, buildFixture, function() end, function() realCollections += 1 end)
A.equal(route, "real", "unknown route falls back to real")
A.equal(realCollections, 1, "real route collects once")

A.equal(Demo.requestedId({ id = "healthy", nonce = 1 }, true, nil, Fixtures.contains), "healthy", "enabled fixture request accepted")
A.equal(Demo.requestedId({ id = "real", nonce = 2 }, true, nil, Fixtures.contains), "real", "real request accepted")
A.equal(Demo.requestedId({ id = "healthy", nonce = 3 }, false, nil, Fixtures.contains), nil, "disabled developer request ignored")
A.equal(Demo.requestedId({ id = "unknown", nonce = 4 }, true, nil, Fixtures.contains), nil, "unknown request rejected")
A.equal(Demo.requestedId({ id = "healthy", nonce = 4 }, true), nil, "missing catalog validator rejected")
A.equal(Demo.requestedId("critical", true, nil, Fixtures.contains), nil, "malformed request rejected")
A.equal(Demo.requestedId({ id = "critical" }, true, nil, Fixtures.contains), nil, "request without nonce rejected")
A.equal(Demo.requestedId({ id = "critical", nonce = math.huge }, true, nil, Fixtures.contains), nil, "infinite request nonce rejected")
A.equal(Demo.requestedId({ id = "critical", nonce = 100 }, true, 100, Fixtures.contains), nil, "request from an earlier session rejected")
A.equal(Demo.requestedId({ id = "critical", nonce = 101 }, true, 100, Fixtures.contains), "critical", "current session request accepted")

print("demo_spec passed")
