--!nonstrict

local Command = require("./lib/command.luau")
local Collection = require("./lib/collection.luau")
local Cleanup = require("./lib/cleanup.luau")
local Disk = require("./lib/disk.luau")
local Health = require("./lib/health.luau")
local Logs = require("./lib/logs.luau")
local Refresh = require("./lib/refresh.luau")
local Services = require("./lib/services.luau")
local Settings = require("./lib/settings.luau")
local Updates = require("./lib/updates.luau")

local CHECKUPDATES_TIMEOUT_MS = 30000
local LOCAL_COMMAND_TIMEOUT_MS = 5000
local COLLECTION_TIMEOUT_MS = 35000
local WATCHDOG_TICK_MS = 1000
local MODULE_NAMES = { "updates", "services", "disk", "cleanup", "logs" }

local gate = Refresh.new()
local started = false
local refreshIntervalMs = Settings.refreshIntervalMs("15")
local nextRefreshAtMs = nil
local run = nil
local runSequence = 0
local snapshot = {
  refreshing = false,
  collectedAtMs = nil,
  modules = {},
  health = Health.aggregate({}),
}

local refresh

local function publish()
  snapshot.health = Health.aggregate(snapshot.modules)
  noctalia.state.set("snapshot", snapshot)
end

local function finishRun()
  if run == nil then
    return
  end
  local completedAtMs = noctalia.nowMs()
  run = nil
  snapshot.refreshing = false
  snapshot.collectedAtMs = completedAtMs
  nextRefreshAtMs = Collection.nextRefreshAtMs(completedAtMs, refreshIntervalMs)
  local rerun = Refresh.complete(gate)
  publish()
  if rerun then
    refresh()
  end
end

local function finishModule(runId, name, moduleResult)
  local accepted, complete = Collection.complete(run, runId, name)
  if not accepted then
    return
  end
  snapshot.modules[name] = moduleResult
  if not complete then
    publish()
    return
  end
  finishRun()
end

local function collectUpdates(checkedAtMs, done)
  if not noctalia.commandExists("checkupdates") then
    done(Updates.unavailable(checkedAtMs))
    return
  end

  if not noctalia.commandExists("bash") or not noctalia.commandExists("awk") then
    done(Updates.error(checkedAtMs, "missing_bash_or_awk"))
    return
  end

  local accepted = noctalia.runAsync({
    "bash",
    "-o",
    "pipefail",
    "-c",
    "checkupdates --nocolor | awk 'BEGIN { count = 0 } { count += 1; if (count <= 8) printf \"package\\t%s\\t%s\\t%s\\n\", $1, $2, $4 } END { printf \"count\\t%d\\n\", count }'",
  }, function(checkResult)
    local failure = Command.failure(checkResult)
    if failure ~= nil then
      done(Updates.error(checkedAtMs, failure))
      return
    end

    local function finish(logLine)
      done(Updates.fromSummary(checkResult.exitCode, checkResult.stdout or "", logLine, checkedAtMs))
    end

    if not noctalia.commandExists("grep") or not noctalia.commandExists("tail") then
      finish(nil)
      return
    end

    local tailAccepted = noctalia.runAsync({ "bash", "-c", "grep -F 'starting full system upgrade' /var/log/pacman.log | tail -n 1" }, function(logResult)
      if Command.failure(logResult) ~= nil or logResult.exitCode ~= 0 then
        finish(nil)
      else
        finish(logResult.stdout or "")
      end
    end, LOCAL_COMMAND_TIMEOUT_MS)
    if not tailAccepted then
      finish(nil)
    end
  end, CHECKUPDATES_TIMEOUT_MS)
  if not accepted then
    done(Updates.error(checkedAtMs, "command_rejected"))
  end
end

local function failedUnitsCommand(userScope)
  local scope = userScope and "systemctl --user" or "systemctl"
  return scope
    .. " --failed --no-legend --plain --no-pager"
    .. " | awk 'BEGIN { count = 0 } { count += 1; if (count <= 20) print \"unit\\t\" substr($0, 1, 1024) } END { print \"count\\t\" count }'"
end

local function collectServices(checkedAtMs, done)
  if not noctalia.commandExists("systemctl") then
    done(Services.error(checkedAtMs, "missing_systemctl"))
    return
  end

  local systemResult = nil
  local userResult = nil
  local systemFinished = false
  local userFinished = false

  local function finishIfReady()
    if not systemFinished or not userFinished then
      return
    end
    local systemExit = Command.failure(systemResult) ~= nil and 1 or systemResult.exitCode
    local userExit = Command.failure(userResult) ~= nil and 1 or userResult.exitCode
    done(Services.fromScopes(
      systemExit,
      systemResult and systemResult.stdout or "",
      userExit,
      userResult and userResult.stdout or "",
      checkedAtMs
    ))
  end

  if not noctalia.commandExists("bash") or not noctalia.commandExists("awk") then
    done(Services.error(checkedAtMs, "missing_bash_or_awk"))
    return
  end

  local systemAccepted = noctalia.runAsync({ "bash", "-o", "pipefail", "-c", failedUnitsCommand(false) }, function(value)
    systemResult = value
    systemFinished = true
    finishIfReady()
  end, LOCAL_COMMAND_TIMEOUT_MS)
  if not systemAccepted then
    systemResult = { exitCode = 1 }
    systemFinished = true
  end

  local userAccepted = noctalia.runAsync({ "bash", "-o", "pipefail", "-c", failedUnitsCommand(true) }, function(value)
    userResult = value
    userFinished = true
    finishIfReady()
  end, LOCAL_COMMAND_TIMEOUT_MS)
  if not userAccepted then
    userResult = { exitCode = 1 }
    userFinished = true
  end
  finishIfReady()
end

local function collectCleanup(checkedAtMs, done)
  local cache = nil
  local orphans = nil
  local journal = nil

  local function finishIfReady()
    if cache ~= nil and orphans ~= nil and journal ~= nil then
      done(Cleanup.aggregate(cache, orphans, journal, checkedAtMs))
    end
  end

  if noctalia.commandExists("du") then
    local accepted = noctalia.runAsync(
      { "du", "--summarize", "--block-size=1", "--exclude=download-*", "/var/cache/pacman/pkg" },
      function(value)
        if Command.failure(value) ~= nil then
          cache = Cleanup.error(Command.failure(value))
        else
          cache = Cleanup.cacheFromDu(value.exitCode, value.stdout or "")
        end
        finishIfReady()
      end,
      LOCAL_COMMAND_TIMEOUT_MS
    )
    if not accepted then
      cache = Cleanup.error("command_rejected")
    end
  else
    cache = Cleanup.error("missing_du")
  end

  if noctalia.commandExists("pacman") and noctalia.commandExists("bash") and noctalia.commandExists("awk") then
    local accepted = noctalia.runAsync({
      "bash",
      "-o",
      "pipefail",
      "-c",
      "pacman -Qtdq | awk 'BEGIN { count = 0 } { count += 1; if (count <= 8) print \"package\\t\" $0 } END { print \"count\\t\" count }'",
    }, function(value)
      if Command.failure(value) ~= nil then
        orphans = Cleanup.error(Command.failure(value))
      else
        orphans = Cleanup.orphansFromSummary(value.exitCode, value.stdout or "")
      end
      finishIfReady()
    end, LOCAL_COMMAND_TIMEOUT_MS)
    if not accepted then
      orphans = Cleanup.error("command_rejected")
    end
  else
    orphans = Cleanup.error("missing_pacman_bash_or_awk")
  end

  if noctalia.commandExists("journalctl") and noctalia.commandExists("env") then
    local accepted = noctalia.runAsync({ "env", "LC_ALL=C", "journalctl", "--disk-usage" }, function(value)
      if Command.failure(value) ~= nil then
        journal = Cleanup.error(Command.failure(value))
      else
        journal = Cleanup.journalFromUsage(value.exitCode, value.stdout or "")
      end
      finishIfReady()
    end, LOCAL_COMMAND_TIMEOUT_MS)
    if not accepted then
      journal = Cleanup.error("command_rejected")
    end
  else
    journal = Cleanup.error("missing_journalctl_or_env")
  end

  finishIfReady()
end

local function decodeJson(value)
  local ok, decoded = pcall(function()
    return noctalia.json.decode(value)
  end)
  return ok and decoded or nil
end

local function collectLogs(checkedAtMs, done)
  if not noctalia.commandExists("journalctl") or not noctalia.commandExists("bash") or not noctalia.commandExists("jq") then
    done(Logs.error(checkedAtMs, "missing_journalctl_bash_or_jq"))
    return
  end

  local systemResult = nil
  local userResult = nil
  local systemFinished = false
  local userFinished = false
  local function parseScope(value, scope)
    local failure = Command.failure(value)
    if failure ~= nil then
      return { exitCode = 1, events = {}, detail = failure }
    elseif value.exitCode ~= 0 then
      return { exitCode = 1, events = {}, detail = "command_failed" }
    end
    local decoded = decodeJson(value.stdout or "")
    if decoded == nil then
      return { exitCode = 1, events = {}, detail = "invalid_json" }
    end
    local events, parseError = Logs.parsePrepared(decoded, scope)
    if events == nil then
      return { exitCode = 1, events = {}, detail = parseError }
    end
    return { exitCode = 0, events = events }
  end

  local function finishIfReady()
    if not systemFinished or not userFinished then
      return
    end
    done(Logs.fromScopes(
      systemResult.exitCode,
      systemResult.events,
      userResult.exitCode,
      userResult.events,
      checkedAtMs,
      systemResult.detail,
      userResult.detail
    ))
  end

  local systemAccepted = noctalia.runAsync({ "bash", "-o", "pipefail", "-c", Logs.collectionCommand(false) }, function(value)
    systemResult = parseScope(value, "system")
    systemFinished = true
    finishIfReady()
  end, LOCAL_COMMAND_TIMEOUT_MS)
  if not systemAccepted then
    systemResult = { exitCode = 1, events = {}, detail = "command_rejected" }
    systemFinished = true
  end

  local userAccepted = noctalia.runAsync({ "bash", "-o", "pipefail", "-c", Logs.collectionCommand(true) }, function(value)
    userResult = parseScope(value, "user")
    userFinished = true
    finishIfReady()
  end, LOCAL_COMMAND_TIMEOUT_MS)
  if not userAccepted then
    userResult = { exitCode = 1, events = {}, detail = "command_rejected" }
    userFinished = true
  end
  finishIfReady()
end

local function collectDisk(checkedAtMs, done)
  local nativeResult = Disk.fromStats(noctalia.diskStats("/"), checkedAtMs)
  if nativeResult ~= nil then
    done(nativeResult)
    return
  end

  if not noctalia.commandExists("df") then
    done(Disk.error(checkedAtMs, "missing_df"))
    return
  end

  local accepted = noctalia.runAsync({ "df", "--output=size,avail,pcent,target", "-B1", "/" }, function(dfResult)
    local failure = Command.failure(dfResult)
    if failure ~= nil then
      done(Disk.error(checkedAtMs, failure))
    else
      done(Disk.fromDf(dfResult.exitCode, dfResult.stdout or "", checkedAtMs))
    end
  end, LOCAL_COMMAND_TIMEOUT_MS)
  if not accepted then
    done(Disk.error(checkedAtMs, "command_rejected"))
  end
end

refresh = function()
  if not Refresh.request(gate) then
    snapshot.refreshing = true
    publish()
    return
  end

  local checkedAtMs = noctalia.nowMs()
  runSequence = runSequence + 1
  local runId = runSequence
  run = Collection.new(runId, checkedAtMs, checkedAtMs + COLLECTION_TIMEOUT_MS, MODULE_NAMES)
  snapshot.refreshing = true
  publish()

  collectUpdates(checkedAtMs, function(value) finishModule(runId, "updates", value) end)
  collectServices(checkedAtMs, function(value) finishModule(runId, "services", value) end)
  collectDisk(checkedAtMs, function(value) finishModule(runId, "disk", value) end)
  collectCleanup(checkedAtMs, function(value) finishModule(runId, "cleanup", value) end)
  collectLogs(checkedAtMs, function(value) finishModule(runId, "logs", value) end)
end

local function configureRefreshInterval()
  refreshIntervalMs = Settings.refreshIntervalMs(noctalia.getConfig("refresh_interval_minutes"))
  noctalia.setUpdateInterval(WATCHDOG_TICK_MS)
end

local function moduleDeadlineResult(name, checkedAtMs)
  if name == "updates" then
    return Updates.error(checkedAtMs, "collection_deadline")
  elseif name == "services" then
    return Services.error(checkedAtMs, "collection_deadline")
  elseif name == "cleanup" then
    return Cleanup.aggregate(
      Cleanup.error("collection_deadline"),
      Cleanup.error("collection_deadline"),
      Cleanup.error("collection_deadline"),
      checkedAtMs
    )
  elseif name == "logs" then
    return Logs.error(checkedAtMs, "collection_deadline")
  end
  return Disk.error(checkedAtMs, "collection_deadline")
end

local function expireRun(nowMs)
  if not Collection.expired(run, nowMs) then
    return
  end
  local expiredRun = run
  for _, name in ipairs(Collection.pendingNames(expiredRun)) do
    finishModule(expiredRun.id, name, moduleDeadlineResult(name, expiredRun.checkedAtMs))
  end
end

local function ensureStarted()
  if started then
    return
  end
  started = true
  refresh()
end

configureRefreshInterval()
noctalia.state.watch("refresh_request", function(_value)
  refresh()
end)
ensureStarted()

function update()
  local nowMs = noctalia.nowMs()
  expireRun(nowMs)
  if run == nil and Collection.isDue(nextRefreshAtMs, nowMs) then
    refresh()
  end
end

function onEnable()
  ensureStarted()
end

function onConfigChanged()
  configureRefreshInterval()
  refresh()
end

function onIpc(event, _payload)
  if event == "refresh" then
    refresh()
  end
end
