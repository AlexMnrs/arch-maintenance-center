local A = require("./assertions")
local Logs = require("../arch-maintenance-center/lib/logs")

local kernel, kernelError = Logs.normalizePreparedEvent({
  t = 1787745600123456,
  p = 3,
  s = "kernel",
  m = "line one\nline two",
}, "system")
A.equal(kernelError, nil, "kernel event normalized")
A.equal(kernel.source, "kernel", "kernel source is explicit")
A.equal(kernel.message, "line one line two", "control characters are neutralized")
A.equal(kernel.timestampMs, 1787745600123, "microseconds become milliseconds")

local longMessage = string.rep("x", 300)
local capped = Logs.normalizePreparedEvent({
  t = 1000,
  p = 2,
  s = "example",
  m = longMessage,
}, "user")
A.equal(#capped.message, 240, "messages are capped")

local parsed = Logs.parsePrepared({
  {
    t = 1000,
    p = 3,
    s = "alpha",
    m = "first",
  },
  {
    t = 2000,
    p = 2,
    s = "beta",
    m = "second",
  },
}, "system")
A.equal(#parsed, 2, "json line sample parsed")
A.equal(parsed[2].source, "beta", "identifier becomes source")

local malformed, parseError = Logs.parsePrepared({ { t = "bad", p = 3, s = "source", m = "message" } }, "system")
A.equal(malformed, nil, "invalid json event rejected")
A.equal(parseError, "invalid_event", "invalid event is traced")

local hostile = Logs.normalizePreparedEvent({ t = 1000, p = 3, s = "bad\tunit", m = "bad\0message" }, "system")
A.equal(hostile.source, "bad unit", "source control characters are neutralized")
A.equal(hostile.message, "bad message", "message controls are neutralized")

local systemCommand = Logs.collectionCommand(false)
local userCommand = Logs.collectionCommand(true)
A.truthy(string.find(systemCommand, "journalctl --boot", 1, true), "system command is scoped")
A.truthy(string.find(userCommand, "journalctl --user --boot", 1, true), "user command is scoped")
A.truthy(string.find(systemCommand, "jq -cs", 1, true), "journal output is bounded before Luau")
A.equal(string.find(systemCommand, "sudo", 1, true), nil, "log collection is unprivileged")

local systemEvents = {}
for index = 1, 11 do
  table.insert(systemEvents, {
    scope = "system",
    timestampMs = index,
    priority = 3,
    source = "system",
    message = tostring(index),
  })
end
local userEvents = {
  {
    scope = "user",
    timestampMs = 50,
    priority = 3,
    source = "user",
    message = "latest",
  },
}
local combined = Logs.fromScopes(0, systemEvents, 0, userEvents, 100)
A.equal(combined.state, "ready", "logs aggregate ready")
A.equal(combined.severity, "info", "journal errors are informational")
A.equal(combined.data.truncated, true, "over-limit events marked truncated")
A.equal(#combined.data.events, 10, "events capped")
A.equal(combined.data.events[1].source, "user", "events sorted newest first")
A.equal(combined.data.systemDetail, nil, "available system scope has no failure detail")
A.equal(combined.data.userDetail, nil, "available user scope has no failure detail")

local partial = Logs.fromScopes(0, {}, 1, {}, 100, nil, "command_timed_out")
A.equal(partial.state, "ready", "single available journal scope retained")
A.equal(partial.complete, false, "missing journal scope is partial")
A.equal(partial.data.userDetail, "command_timed_out", "scope failure stays traceable")

local unavailable = Logs.fromScopes(1, {}, 1, {}, 100)
A.equal(unavailable.state, "error", "both missing scopes fail logs")

print("logs_spec passed")
