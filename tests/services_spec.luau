local A = require("./assertions")
local Services = require("../arch-maintenance-center/lib/services")

local output = table.concat({
  "docker.service loaded failed failed Docker Application Container Engine",
  "backup@daily.service loaded failed failed Daily backup job",
}, "\n")

local units = Services.parseFailed(output, "system")
A.equal(#units, 2, "failed units parsed")
A.equal(units[1].description, "Docker Application Container Engine", "description keeps spaces")
A.equal(units[2].commandSafe, true, "instance unit is safe")

local empty = Services.fromScopes(0, "", 1, "no user bus", 123)
A.equal(empty.state, "ready", "missing user bus does not fail system scope")
A.equal(empty.data.count, 0, "empty failed set")
A.equal(empty.data.userScopeAvailable, false, "user scope marked unavailable")
A.equal(empty.complete, false, "missing user scope makes the result partial")
A.equal(empty.data.systemCount, 0, "system scope count retained")

local combined = Services.fromScopes(0, output, 0, "pipewire.service loaded failed failed PipeWire", 123)
A.equal(combined.data.count, 3, "system and user units combined")
A.equal(combined.severity, "warning", "failed units warn")
A.equal(combined.complete, true, "both scopes make the result complete")
A.equal(combined.data.systemCount, 2, "system failures counted separately")
A.equal(combined.data.userCount, 1, "user failures counted separately")

local broken = Services.fromScopes(1, "", 0, "", 123)
A.equal(broken.state, "error", "system scope failure errors")

A.equal(Services.isSafeUnitName("normal.service"), true, "normal unit accepted")
A.equal(Services.isSafeUnitName("dev-disk-by\\x2duuid.mount"), true, "escaped unit accepted")
A.equal(Services.isSafeUnitName("bad\ncommand.service"), false, "newline rejected")
A.equal(Services.isSafeUnitName("-option.service"), false, "option-like unit rejected")
A.equal(Services.isSafeUnitName("bad'unit.service"), false, "quote rejected")

print("services_spec passed")
