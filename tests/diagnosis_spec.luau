local A = require("./assertions")
local Diagnosis = require("../arch-maintenance-center/lib/diagnosis")

local snapshot = {
  collectedAtMs = 1787745600000,
  health = { severity = "warning", complete = false, issueCount = 1, unavailableCount = 1 },
  modules = {
    updates = { state = "unavailable", data = {} },
    services = {
      state = "ready",
      data = {
        count = 2,
        units = {
          { scope = "system", name = "docker.service" },
          { scope = "system", name = "bad\nrm.service" },
        },
      },
    },
    disk = { state = "ready", data = { usagePercent = 89.6 } },
  },
}

local diagnosis = Diagnosis.format(snapshot)
A.truthy(string.find(diagnosis, "Complete: no", 1, true), "incomplete diagnosis is explicit")
A.truthy(string.find(diagnosis, "docker.service", 1, true), "safe service included")
A.equal(string.find(diagnosis, "rm.service", 1, true), nil, "malicious service excluded")
A.truthy(string.find(diagnosis, "Root disk used: 90%", 1, true), "disk rounded")

local commands = Diagnosis.commands(snapshot)
A.truthy(string.find(commands, "systemctl status", 1, true), "inspection command included")
A.truthy(string.find(commands, "'docker.service'", 1, true), "unit quoted")
A.equal(string.find(commands, "sudo", 1, true), nil, "no privileged commands")
A.equal(string.find(commands, "rm.service", 1, true), nil, "malicious command excluded")
A.equal(Diagnosis.shellQuote("it's"), "'it'\"'\"'s'", "single quote escaped")

print("diagnosis_spec passed")
