local function import(name)
  local ok, value = pcall(require, "./" .. name .. ".luau")
  if ok then
    return value
  end
  return require("./" .. name)
end

local Fixtures = import("fixtures")

local Demo = {}

function Demo.isFixture(snapshot)
  return type(snapshot) == "table"
    and type(snapshot.source) == "table"
    and snapshot.source.kind == "fixture"
end

function Demo.fixtureId(snapshot)
  return Demo.isFixture(snapshot) and type(snapshot.source.fixtureId) == "string" and snapshot.source.fixtureId or nil
end

function Demo.shouldCollect(fixtureId)
  return fixtureId == nil
end

function Demo.acceptRealCallback(expectedGeneration, currentGeneration, fixtureId)
  return Demo.shouldCollect(fixtureId)
    and type(expectedGeneration) == "number"
    and expectedGeneration == currentGeneration
end

function Demo.routeRefresh(fixtureId, nowMs, publishFixture, collectReal)
  if Fixtures.contains(fixtureId) then
    local fixture = Fixtures.build(fixtureId, nowMs)
    if fixture ~= nil then
      publishFixture(fixture)
      return "fixture"
    end
  end
  collectReal()
  return "real"
end

function Demo.requestedId(request, enabled, minimumNonce)
  if enabled ~= true
    or type(request) ~= "table"
    or type(request.id) ~= "string"
    or type(request.nonce) ~= "number"
    or request.nonce ~= request.nonce
    or request.nonce == math.huge
    or request.nonce < 0
    or (type(minimumNonce) == "number" and request.nonce <= minimumNonce)
  then
    return nil
  end
  if request.id == "real" or Fixtures.contains(request.id) then
    return request.id
  end
  return nil
end

return Demo
