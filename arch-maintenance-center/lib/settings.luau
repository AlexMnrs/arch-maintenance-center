local Settings = {}

local REFRESH_INTERVALS = {
  ["15"] = 15,
  ["30"] = 30,
  ["60"] = 60,
}

function Settings.refreshIntervalMinutes(value)
  return REFRESH_INTERVALS[value] or 15
end

function Settings.refreshIntervalMs(value)
  return Settings.refreshIntervalMinutes(value) * 60 * 1000
end

return Settings
