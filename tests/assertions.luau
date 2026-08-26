local Assertions = {}

function Assertions.equal(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
  end
end

function Assertions.truthy(value, message)
  if not value then
    error(message)
  end
end

return Assertions
