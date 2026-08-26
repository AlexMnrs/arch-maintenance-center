--!nonstrict

local Command = require("./lib/command.luau")
local Collection = require("./lib/collection.luau")
local Disk = require("./lib/disk.luau")
local Health = require("./lib/health.luau")
local Refresh = require("./lib/refresh.luau")
local Services = require("./lib/services.luau")
local Settings = require("./lib/settings.luau")
local Updates = require("./lib/updates.luau")

local CHECKUPDATES_TIMEOUT_MS = 30000
local LOCAL_COMMAND_TIMEOUT_MS = 5000
local COLLECTION_TIMEOUT_MS = 35000
local WATCHDOG_TICK_MS = 1000
local MODULE_NAMES = { "updates", "services", "disk" }

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

  if not noctalia.commandExists("bash") then
    done(Updates.error(checkedAtMs, "missing_bash"))
    return
  end

  local accepted = noctalia.runAsync({ "bash", "-o", "pipefail", "-c", "checkupdates --nocolor | wc -l" }, function(checkResult)
    local failure = Command.failure(checkResult)
    if failure ~= nil then
      done(Updates.error(checkedAtMs, failure))
      return
    end

    local function finish(logLine)
      done(Updates.fromCount(checkResult.exitCode, checkResult.stdout or "", logLine, checkedAtMs))
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

  local args = { "systemctl", "--failed", "--no-legend", "--plain", "--no-pager" }
  local systemAccepted = noctalia.runAsync(args, function(value)
    systemResult = value
    systemFinished = true
    finishIfReady()
  end, LOCAL_COMMAND_TIMEOUT_MS)
  if not systemAccepted then
    systemResult = { exitCode = 1 }
    systemFinished = true
  end

  local userAccepted = noctalia.runAsync({ "systemctl", "--user", "--failed", "--no-legend", "--plain", "--no-pager" }, function(value)
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
