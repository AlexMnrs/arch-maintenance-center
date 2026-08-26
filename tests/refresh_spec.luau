local A = require("./assertions")
local Refresh = require("../arch-maintenance-center/lib/refresh")

local gate = Refresh.new()
A.equal(Refresh.request(gate), true, "first refresh starts")
A.equal(Refresh.request(gate), false, "overlap is queued")
A.equal(Refresh.request(gate), false, "multiple overlaps coalesce")
A.equal(Refresh.complete(gate), true, "one rerun requested")
A.equal(Refresh.request(gate), true, "rerun can start")
A.equal(Refresh.complete(gate), false, "no third run")

print("refresh_spec passed")
