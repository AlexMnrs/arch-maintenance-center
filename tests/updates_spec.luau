local A = require("./assertions")
local Updates = require("../arch-maintenance-center/lib/updates")

local now = os.time({ year = 2026, month = 8, day = 26, hour = 12, min = 0, sec = 0 }) * 1000
local recentLog = "[2026-08-25T22:15:20+0200] [PACMAN] starting full system upgrade\n"
local oldLog = "[2026-08-01T08:00:00+0200] [PACMAN] starting full system upgrade\n"

A.equal(Updates.parseCount("0\n"), 0, "zero updates parsed")
A.equal(Updates.parseCount("1\n"), 1, "one update parsed")
A.equal(Updates.parseCount("97\n"), 97, "multiple updates parsed")

local summary = Updates.parseSummary(table.concat({
  "package\tlinux\t6.17.2\t6.17.3",
  "package\tfirefox\t142.0\t142.0.1",
  "count\t10",
}, "\n"))
A.equal(summary.count, 10, "summary count parsed")
A.equal(#summary.packages, 2, "package sample parsed")
A.equal(summary.packages[1].availableVersion, "6.17.3", "available version retained")
A.equal(summary.packagesTruncated, true, "sample truncation retained")

local malformedSummary, summaryError = Updates.parseSummary("package\tlinux\t6.17.2\ncount\t1\n")
A.equal(malformedSummary, nil, "malformed package rejected")
A.equal(summaryError, "malformed_package", "malformed package traced")

local malformed, malformedError = Updates.parseCount("1\n2\n")
A.equal(malformed, nil, "multiple lines rejected")
A.equal(malformedError, "invalid_count", "malformed count error")

local malformedText = Updates.parseCount("linux 6.1-1 -> 6.2-1\n")
A.equal(malformedText, nil, "package output rejected")

A.truthy(Updates.parseLastFullUpgrade(recentLog) ~= nil, "single upgrade line parsed")
A.equal(Updates.parseLastFullUpgrade("[2026-08-25] [PACMAN] installed pacman"), nil, "unrelated log line ignored")

local none = Updates.fromCount(2, "0\n", recentLog, now)
A.equal(none.state, "ready", "exit two is ready")
A.equal(none.data.count, 0, "exit two means no updates")
A.equal(none.severity, "ok", "no updates healthy")

local current = Updates.fromCount(0, "1\n", recentLog, now)
A.equal(current.state, "ready", "one update result is ready")
A.equal(current.severity, "info", "recent pending updates informational")
A.equal(current.data.daysSinceLastUpgrade, 0, "recent full upgrade age")

local stale = Updates.fromCount(0, "97\n", oldLog, now)
A.equal(stale.severity, "warning", "stale pending updates warn")
A.truthy(stale.data.daysSinceLastUpgrade >= 14, "stale age is at least threshold")
A.equal(stale.data.packages, nil, "package list is not retained")

local unknownDate = Updates.fromCount(0, "1\n", "", now)
A.equal(unknownDate.state, "ready", "missing upgrade date does not fail updates")
A.equal(unknownDate.data.lastUpgradeMs, nil, "missing date remains unknown")
A.equal(unknownDate.data.daysSinceLastUpgrade, nil, "missing date has no age")

local failed = Updates.fromCount(1, "0\n", recentLog, now)
A.equal(failed.state, "error", "exit one is error")

local inconsistent = Updates.fromCount(2, "1\n", recentLog, now)
A.equal(inconsistent.state, "error", "exit two with a nonzero count is error")

local detailed = Updates.fromSummary(0, "package\tlinux\t6.17.2\t6.17.3\ncount\t1\n", recentLog, now)
A.equal(detailed.state, "ready", "detailed update result ready")
A.equal(detailed.data.packages[1].name, "linux", "detailed package retained")
A.equal(Updates.upgradeCommand(), "sudo pacman -Syu", "upgrade command is explicit")

print("updates_spec passed")
