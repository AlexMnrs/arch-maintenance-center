local A = require("./assertions")
local Diagnosis = require("../arch-maintenance-center/lib/diagnosis")

local snapshot = {
  collectedAtMs = 1787745600000,
  platform = { state = "supported", id = "arch" },
  health = { severity = "warning", complete = false, issueCount = 1, recommendationCount = 2, unavailableCount = 1 },
  recommendations = {
    { id = "updates_available", data = { count = 1, daysSinceLastUpgrade = 20 } },
    { id = "orphan_packages", data = { count = 1 } },
  },
  modules = {
    updates = { state = "ready", data = { count = 1, lastUpgradeMs = 1787742000000 } },
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
    cleanup = {
      state = "ready",
      data = {
        cache = { state = "ready", data = { bytes = 1024 } },
        orphans = { state = "ready", data = { count = 1, packages = { "never-copy-this" } } },
        journal = { state = "ready", data = { bytes = 2048 } },
      },
    },
    logs = {
      state = "ready",
      data = {
        count = 1,
        events = {
          { source = "kernel", message = "token=super-secret user=alice path=/home/alice ip=203.0.113.8" },
        },
        systemAvailable = true,
        userAvailable = false,
      },
    },
  },
}

local diagnosis = Diagnosis.format(snapshot)
A.truthy(string.find(diagnosis, "Complete: no", 1, true), "incomplete diagnosis is explicit")
A.truthy(string.find(diagnosis, "Source: real", 1, true), "legacy snapshot source is real")
A.truthy(string.find(diagnosis, "Platform: supported (arch)", 1, true), "supported platform is recorded")
A.truthy(string.find(diagnosis, "Recommended actions: 2", 1, true), "action count is recorded")
A.truthy(string.find(diagnosis, "updates_available: 1 pending", 1, true), "safe update action included")
A.truthy(string.find(diagnosis, "Last full upgrade: 2026-08-26T", 1, true), "upgrade timestamp is absolute")
A.truthy(string.find(diagnosis, "docker.service", 1, true), "safe service included")
A.equal(string.find(diagnosis, "rm.service", 1, true), nil, "malicious service excluded")
A.truthy(string.find(diagnosis, "Root disk used: 90%", 1, true), "disk rounded")
A.truthy(string.find(diagnosis, "Orphan packages: 1", 1, true), "cleanup count included")
A.truthy(string.find(diagnosis, "Journal errors shown: 1", 1, true), "logs count included")
A.equal(string.find(diagnosis, "super-secret", 1, true), nil, "free-form log message excluded")
A.equal(string.find(diagnosis, "never-copy-this", 1, true), nil, "orphan sample excluded")

local commands = Diagnosis.commands(snapshot)
A.truthy(string.find(commands, "systemctl status", 1, true), "inspection command included")
A.truthy(string.find(commands, "'docker.service'", 1, true), "unit quoted")
A.equal(string.find(commands, "sudo", 1, true), nil, "no privileged commands")
A.equal(string.find(commands, "rm.service", 1, true), nil, "malicious command excluded")
A.truthy(string.find(commands, "journalctl --disk-usage", 1, true), "cleanup inspection included")
A.equal(Diagnosis.shellQuote("it's"), "'it'\"'\"'s'", "single quote escaped")

local unsupported = {
  collectedAtMs = 1,
  platform = { state = "unsupported", id = "fedora" },
  health = { severity = "ok", complete = true },
  modules = snapshot.modules,
}
local unsupportedDiagnosis = Diagnosis.format(unsupported)
A.truthy(string.find(unsupportedDiagnosis, "Platform: unsupported (fedora)", 1, true), "unsupported platform is explicit")
A.truthy(string.find(unsupportedDiagnosis, "Recommended actions: 0", 1, true), "unsupported diagnosis keeps action count")
A.truthy(string.find(unsupportedDiagnosis, "Status: unavailable", 1, true), "unsupported diagnosis is unavailable")
A.equal(Diagnosis.commands(unsupported), "", "unsupported platforms receive no Arch commands")

local fixture = {
  source = { kind = "fixture", fixtureId = "critical" },
  collectedAtMs = snapshot.collectedAtMs,
  platform = snapshot.platform,
  health = snapshot.health,
  recommendations = snapshot.recommendations,
  modules = snapshot.modules,
}
local fixtureDiagnosis = Diagnosis.format(fixture)
A.truthy(string.find(fixtureDiagnosis, "Source: fixture (critical)", 1, true), "fixture source is explicit")
A.equal(Diagnosis.commands(fixture), "", "fixtures receive no commands")

print("diagnosis_spec passed")
