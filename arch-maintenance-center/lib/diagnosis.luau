local Diagnosis = {}

local function safeNumber(value, fallback)
  return type(value) == "number" and value or fallback
end

function Diagnosis.shellQuote(value)
  value = tostring(value or "")
  return "'" .. string.gsub(value, "'", "'\"'\"'") .. "'"
end

local function isSafeUnitName(value)
  if type(value) ~= "string" or value == "" or #value > 256 or string.sub(value, 1, 1) == "-" then
    return false
  end
  for index = 1, #value do
    local character = string.sub(value, index, index)
    if string.match(character, "[%w@_.:%-]") == nil and character ~= "\\" then
      return false
    end
  end
  return true
end

function Diagnosis.format(snapshot)
  if type(snapshot) ~= "table" or type(snapshot.health) ~= "table" then
    return "Arch Maintenance Center diagnosis\nStatus: unavailable"
  end

  local health = snapshot.health
  local lines = {
    "Arch Maintenance Center diagnosis",
    "Generated: " .. os.date("!%Y-%m-%dT%H:%M:%SZ", math.floor(safeNumber(snapshot.collectedAtMs, 0) / 1000)),
    "Status: " .. tostring(health.severity or "unknown"),
    "Complete: " .. (health.complete == true and "yes" or "no"),
    "Issues: " .. tostring(safeNumber(health.issueCount, 0)),
    "Unavailable modules: " .. tostring(safeNumber(health.unavailableCount, 0)),
  }

  local modules = type(snapshot.modules) == "table" and snapshot.modules or {}
  local updates = modules.updates
  if type(updates) == "table" and updates.state == "ready" then
    local data = updates.data or {}
    table.insert(lines, "Updates: " .. tostring(safeNumber(data.count, 0)) .. " pending")
    if type(data.daysSinceLastUpgrade) == "number" then
      table.insert(lines, "Last full upgrade: " .. tostring(data.daysSinceLastUpgrade) .. " days ago")
    else
      table.insert(lines, "Last full upgrade: unknown")
    end
  else
    table.insert(lines, "Updates: unavailable")
  end

  local services = modules.services
  if type(services) == "table" and services.state == "ready" then
    local data = services.data or {}
    table.insert(lines, "Failed services: " .. tostring(safeNumber(data.count, 0)))
    for _, unit in ipairs(type(data.units) == "table" and data.units or {}) do
      if isSafeUnitName(unit.name) then
        table.insert(lines, "- " .. tostring(unit.scope == "user" and "user" or "system") .. ":" .. unit.name)
      end
    end
  else
    table.insert(lines, "Services: unavailable")
  end

  local disk = modules.disk
  if type(disk) == "table" and disk.state == "ready" then
    table.insert(lines, "Root disk used: " .. tostring(math.floor(safeNumber(disk.data and disk.data.usagePercent, 0) + 0.5)) .. "%")
  else
    table.insert(lines, "Root disk: unavailable")
  end

  return table.concat(lines, "\n")
end

function Diagnosis.commands(snapshot)
  local commands = {
    "checkupdates --nocolor",
    "df -h /",
  }
  local services = type(snapshot) == "table"
    and type(snapshot.modules) == "table"
    and snapshot.modules.services
    or nil
  local units = services ~= nil and services.state == "ready" and services.data and services.data.units or {}

  for _, unit in ipairs(type(units) == "table" and units or {}) do
    if isSafeUnitName(unit.name) then
      local quoted = Diagnosis.shellQuote(unit.name)
      if unit.scope == "user" then
        table.insert(commands, "systemctl --user status --no-pager " .. quoted)
        table.insert(commands, "journalctl --user -u " .. quoted .. " -b --no-pager -n 50")
      else
        table.insert(commands, "systemctl status --no-pager " .. quoted)
        table.insert(commands, "journalctl -u " .. quoted .. " -b --no-pager -n 50")
      end
    end
  end
  return table.concat(commands, "\n")
end

return Diagnosis
