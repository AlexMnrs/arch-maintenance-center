local Bytes = {}

local UNITS = { "B", "KiB", "MiB", "GiB", "TiB", "PiB" }

function Bytes.format(value)
  if type(value) ~= "number" or value < 0 then
    return "Unavailable"
  end

  local index = 1
  while value >= 1024 and index < #UNITS do
    value = value / 1024
    index = index + 1
  end

  if index == 1 then
    return tostring(math.floor(value + 0.5)) .. " " .. UNITS[index]
  end
  return string.format("%.1f %s", value, UNITS[index])
end

return Bytes
