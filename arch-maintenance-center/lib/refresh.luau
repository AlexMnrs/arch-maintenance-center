local Refresh = {}

function Refresh.new()
  return { inFlight = false, queued = false }
end

function Refresh.request(gate)
  if gate.inFlight then
    gate.queued = true
    return false
  end
  gate.inFlight = true
  return true
end

function Refresh.complete(gate)
  local rerun = gate.queued == true
  gate.inFlight = false
  gate.queued = false
  return rerun
end

return Refresh
