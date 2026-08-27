local Platform = {}

local MAX_OS_RELEASE_BYTES = 64 * 1024

local function trim(value)
  return (string.gsub(value or "", "^%s*(.-)%s*$", "%1"))
end

local function parseId(value)
  value = trim(value)
  local first = string.sub(value, 1, 1)
  if first == '"' or first == "'" then
    if #value < 2 or string.sub(value, -1) ~= first then
      return nil, "malformed_id"
    end
    value = string.sub(value, 2, -2)
  end

  if value == "" or #value > 128 or string.match(value, "^[a-z0-9][a-z0-9._-]*$") == nil then
    return nil, "malformed_id"
  end
  return value
end

function Platform.parseOsRelease(contents)
  if type(contents) ~= "string" then
    return nil, "invalid_output"
  elseif #contents > MAX_OS_RELEASE_BYTES then
    return nil, "output_too_large"
  end

  local id = nil
  for rawLine in string.gmatch(contents .. "\n", "(.-)\r?\n") do
    local line = trim(rawLine)
    if line ~= "" and string.sub(line, 1, 1) ~= "#" then
      local key, value = string.match(line, "^([A-Z0-9_]+)=(.*)$")
      if key == "ID" then
        if id ~= nil then
          return nil, "duplicate_id"
        end
        local parsed, parseError = parseId(value)
        if parsed == nil then
          return nil, parseError
        end
        id = parsed
      end
    end
  end

  if id == nil then
    return nil, "missing_id"
  end
  return id
end

function Platform.classify(contents)
  local id, parseError = Platform.parseOsRelease(contents)
  if id == nil then
    return { state = "error", detail = parseError }
  elseif id == "arch" then
    return { state = "supported", id = id }
  end
  return { state = "unsupported", id = id }
end

function Platform.maxOsReleaseBytes()
  return MAX_OS_RELEASE_BYTES
end

return Platform
