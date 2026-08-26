local Logs = {}

local EVENT_LIMIT = 10
local COMMAND_EVENT_LIMIT = EVENT_LIMIT + 1
local SOURCE_LIMIT = 128
local MESSAGE_LIMIT = 240

local JQ_FILTER = [[def clean($limit): tostring | gsub("[\u0000-\u001f\u007f]"; " ") | if length > $limit then .[0:($limit - 3)] + "..." else . end; map({t: ((.__REALTIME_TIMESTAMP // "") | try tonumber catch null), p: ((.PRIORITY // "") | try tonumber catch null), s: ((if ._TRANSPORT == "kernel" then "kernel" else (._SYSTEMD_UNIT // ._SYSTEMD_USER_UNIT // .SYSLOG_IDENTIFIER // ._TRANSPORT // "journal") end) | clean(128)), m: ((.MESSAGE // "(no message)") | clean(240))})]]

local function trim(value)
  return (string.gsub(value or "", "^%s*(.-)%s*$", "%1"))
end

local function result(state, severity, checkedAtMs, summary, detail, data)
  return {
    state = state,
    severity = severity,
    checkedAtMs = checkedAtMs,
    summary = summary,
    detail = detail,
    data = data or {},
  }
end

local function sanitize(value, limit)
  if type(value) ~= "string" then
    return nil
  end
  local cleaned = trim(string.gsub(value, "[%c]", " "))
  if #cleaned > limit then
    cleaned = string.sub(cleaned, 1, limit - 3) .. "..."
  end
  return cleaned
end

function Logs.collectionCommand(userScope)
  local scope = userScope == true and " --user" or ""
  return "journalctl"
    .. scope
    .. " --boot --priority=err --no-pager --quiet --output=json"
    .. " --output-fields=__REALTIME_TIMESTAMP,PRIORITY,SYSLOG_IDENTIFIER,_SYSTEMD_UNIT,_SYSTEMD_USER_UNIT,_TRANSPORT,MESSAGE"
    .. " --lines=" .. tostring(COMMAND_EVENT_LIMIT)
    .. " | jq -cs '" .. JQ_FILTER .. "'"
end

function Logs.normalizePreparedEvent(value, scope)
  if type(value) ~= "table" or (scope ~= "system" and scope ~= "user") then
    return nil, "invalid_event"
  end

  local timestamp = tonumber(value.t)
  local priority = tonumber(value.p)
  if timestamp == nil or timestamp < 0 or priority == nil or priority < 0 or priority > 3 then
    return nil, "invalid_event"
  end

  local source = sanitize(value.s, SOURCE_LIMIT)
  local message = sanitize(value.m, MESSAGE_LIMIT)
  if source == nil or source == "" then
    source = "journal"
  end
  if message == nil or message == "" then
    message = "(no message)"
  end
  return {
    scope = scope,
    timestampMs = math.floor(timestamp / 1000),
    priority = math.floor(priority),
    source = source,
    message = message,
  }
end

function Logs.parsePrepared(value, scope)
  if type(value) ~= "table" then
    return nil, "invalid_output"
  elseif #value > COMMAND_EVENT_LIMIT then
    return nil, "too_many_events"
  end

  local events = {}
  for _, item in ipairs(value) do
    local event, eventError = Logs.normalizePreparedEvent(item, scope)
    if event == nil then
      return nil, eventError
    end
    table.insert(events, event)
  end
  return events
end

function Logs.error(checkedAtMs, detail)
  return result("error", "unknown", checkedAtMs, "logs_error", detail or "command_failed")
end

function Logs.fromScopes(systemExitCode, systemEvents, userExitCode, userEvents, checkedAtMs, systemDetail, userDetail)
  local systemAvailable = systemExitCode == 0
  local userAvailable = userExitCode == 0
  if not systemAvailable and not userAvailable then
    return Logs.error(checkedAtMs, systemDetail or userDetail or "all_scopes_failed")
  end

  local events = {}
  local truncated = false
  local function append(scopeEvents)
    if type(scopeEvents) ~= "table" then
      return
    end
    if #scopeEvents > EVENT_LIMIT then
      truncated = true
    end
    for _, event in ipairs(scopeEvents) do
      table.insert(events, event)
    end
  end
  if systemAvailable then
    append(systemEvents)
  end
  if userAvailable then
    append(userEvents)
  end

  table.sort(events, function(left, right)
    if left.timestampMs == right.timestampMs then
      return left.scope < right.scope
    end
    return left.timestampMs > right.timestampMs
  end)
  while #events > EVENT_LIMIT do
    table.remove(events)
    truncated = true
  end

  local unavailableSystemDetail = nil
  local unavailableUserDetail = nil
  if not systemAvailable then
    unavailableSystemDetail = systemDetail
  end
  if not userAvailable then
    unavailableUserDetail = userDetail
  end

  local value = result(
    "ready",
    #events > 0 and "info" or "ok",
    checkedAtMs,
    #events > 0 and "logs_events" or "logs_clear",
    not (systemAvailable and userAvailable) and (systemDetail or userDetail or "scope_failed") or nil,
    {
      events = events,
      count = #events,
      truncated = truncated,
      systemAvailable = systemAvailable,
      userAvailable = userAvailable,
      systemDetail = unavailableSystemDetail,
      userDetail = unavailableUserDetail,
    }
  )
  value.complete = systemAvailable and userAvailable
  return value
end

function Logs.eventLimit()
  return EVENT_LIMIT
end

return Logs
