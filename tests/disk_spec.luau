local A = require("./assertions")
local Disk = require("../arch-maintenance-center/lib/disk")

local function stats(percent)
  return { usagePercent = percent, totalBytes = 1000, availableBytes = 100 }
end

A.equal(Disk.fromStats(stats(79.9), 1).severity, "ok", "below warning")
A.equal(Disk.fromStats(stats(80), 1).severity, "warning", "warning boundary")
A.equal(Disk.fromStats(stats(89.9), 1).severity, "warning", "below critical")
A.equal(Disk.fromStats(stats(90), 1).severity, "critical", "critical boundary")

local parsed = Disk.parseDf("1B-blocks Avail Use% Mounted on\n1000 75 93% /\n")
A.equal(parsed.usagePercent, 93, "df percent parsed")
A.equal(parsed.availableBytes, 75, "df available parsed")

local malformed, parseError = Disk.parseDf("unexpected")
A.equal(malformed, nil, "malformed df rejected")
A.equal(parseError, "malformed_output", "malformed df error")

print("disk_spec passed")
