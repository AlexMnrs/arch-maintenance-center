--!nonstrict

local Disk = require("./lib/disk.luau")
local Health = require("./lib/health.luau")
local Refresh = require("./lib/refresh.luau")
local Services = require("./lib/services.luau")
local Settings = require("./lib/settings.luau")
local Updates = require("./lib/updates.luau")

local gate = Refresh.new()
local pending = 0
local started = false
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

local function finishModule(name, moduleResult)
  snapshot.modules[name] = moduleResult
  pending = pending - 1
  if pending > 0 then
    publish()
    return
  end

  snapshot.refreshing = false
  snapshot.collectedAtMs = noctalia.nowMs()
  local rerun = Refresh.complete(gate)
  publish()
  if rerun then
    refresh()
  end
end

local function commandFailed(result)
  return result == nil
    or result.timedOut == true
    or result.stdoutTruncated == true
    or result.stderrTruncated == true
end

local function collectUpdates(checkedAtMs, done)
  if not noctalia.commandExists("checkupdates") then
    done(Updates.unavailable(checkedAtMs))
    return
  end

  local accepted = noctalia.runAsync({ "checkupdates", "--nocolor" }, function(checkResult)
    if commandFailed(checkResult) then
      done(Updates.error(checkedAtMs, "command_failed"))
      return
    end

    local function finish(logText)
      done(Updates.fromCommand(checkResult.exitCode, checkResult.stdout or "", logText, checkedAtMs))
    end

    if not noctalia.commandExists("tail") then
      finish(nil)
      return
    end

    local tailAccepted = noctalia.runAsync({ "tail", "-n", "5000", "/var/log/pacman.log" }, function(logResult)
      if commandFailed(logResult) or logResult.exitCode ~= 0 then
        finish(nil)
      else
        finish(logResult.stdout or "")
      end
    end)
    if not tailAccepted then
      finish(nil)
    end
  end)
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
    local systemExit = commandFailed(systemResult) and 1 or systemResult.exitCode
    local userExit = commandFailed(userResult) and 1 or userResult.exitCode
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
  end)
  if not systemAccepted then
    systemResult = { exitCode = 1 }
    systemFinished = true
  end

  local userAccepted = noctalia.runAsync({ "systemctl", "--user", "--failed", "--no-legend", "--plain", "--no-pager" }, function(value)
    userResult = value
    userFinished = true
    finishIfReady()
  end)
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
    if commandFailed(dfResult) then
      done(Disk.error(checkedAtMs, "command_failed"))
    else
      done(Disk.fromDf(dfResult.exitCode, dfResult.stdout or "", checkedAtMs))
    end
  end)
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
  pending = 3
  snapshot.refreshing = true
  publish()

  collectUpdates(checkedAtMs, function(value) finishModule("updates", value) end)
  collectServices(checkedAtMs, function(value) finishModule("services", value) end)
  collectDisk(checkedAtMs, function(value) finishModule("disk", value) end)
end

local function configureRefreshInterval()
  noctalia.setUpdateInterval(Settings.refreshIntervalMs(noctalia.getConfig("refresh_interval_minutes")))
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
  refresh()
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
