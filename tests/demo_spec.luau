local A = require("./assertions")
local Demo = require("../arch-maintenance-center/lib/demo")
local Fixtures = require("../arch-maintenance-center/lib/fixtures")

local fixture = Fixtures.build("critical", 1000)
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

route = Demo.routeRefresh("unknown", 1000, function() end, function() realCollections += 1 end)
A.equal(route, "real", "unknown route falls back to real")
A.equal(realCollections, 1, "real route collects once")

A.equal(Demo.requestedId({ id = "healthy", nonce = 1 }, true), "healthy", "enabled fixture request accepted")
A.equal(Demo.requestedId({ id = "real", nonce = 2 }, true), "real", "real request accepted")
A.equal(Demo.requestedId({ id = "healthy", nonce = 3 }, false), nil, "disabled developer request ignored")
A.equal(Demo.requestedId({ id = "unknown", nonce = 4 }, true), nil, "unknown request rejected")
A.equal(Demo.requestedId("critical", true), nil, "malformed request rejected")
A.equal(Demo.requestedId({ id = "critical" }, true), nil, "request without nonce rejected")
A.equal(Demo.requestedId({ id = "critical", nonce = math.huge }, true), nil, "infinite request nonce rejected")
A.equal(Demo.requestedId({ id = "critical", nonce = 100 }, true, 100), nil, "request from an earlier session rejected")
A.equal(Demo.requestedId({ id = "critical", nonce = 101 }, true, 100), "critical", "current session request accepted")

print("demo_spec passed")
