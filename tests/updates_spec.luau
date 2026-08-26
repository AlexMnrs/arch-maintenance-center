local A = require("./assertions")
local Updates = require("../arch-maintenance-center/lib/updates")

local now = os.time({ year = 2026, month = 8, day = 26, hour = 12, min = 0, sec = 0 }) * 1000
local recentLog = "[2026-08-25T22:15:20+0200] [PACMAN] starting full system upgrade\n"
local oldLog = "[2026-08-01T08:00:00+0200] [PACMAN] starting full system upgrade\n"

local packages = Updates.parseCheckupdates("linux 6.1-1 -> 6.2-1\npacman 7.0-1 -> 7.0-2\n")
A.equal(#packages, 2, "two updates parsed")
A.equal(packages[1].name, "linux", "package name")

local malformed, malformedError = Updates.parseCheckupdates("not a valid update line")
A.equal(malformed, nil, "malformed output rejected")
A.equal(malformedError, "malformed_line", "malformed error")

local none = Updates.fromCommand(2, "", recentLog, now)
A.equal(none.state, "ready", "exit two is ready")
A.equal(none.data.count, 0, "exit two means no updates")
A.equal(none.severity, "ok", "no updates healthy")

local current = Updates.fromCommand(0, "linux 6.1-1 -> 6.2-1", recentLog, now)
A.equal(current.severity, "info", "recent pending updates informational")
A.equal(current.data.daysSinceLastUpgrade, 0, "recent full upgrade age")

local stale = Updates.fromCommand(0, "linux 6.1-1 -> 6.2-1", oldLog, now)
A.equal(stale.severity, "warning", "stale pending updates warn")
A.truthy(stale.data.daysSinceLastUpgrade >= 14, "stale age is at least threshold")

local failed = Updates.fromCommand(1, "", recentLog, now)
A.equal(failed.state, "error", "exit one is error")

print("updates_spec passed")
