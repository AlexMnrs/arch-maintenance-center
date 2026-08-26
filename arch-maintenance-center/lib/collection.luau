local Collection = {}

function Collection.new(id, checkedAtMs, deadlineAtMs, names)
  local pending = {}
  local order = {}
  for _, name in ipairs(names or {}) do
    if pending[name] ~= true then
      pending[name] = true
      table.insert(order, name)
    end
  end
  return {
    id = id,
    checkedAtMs = checkedAtMs,
    deadlineAtMs = deadlineAtMs,
    pending = pending,
    pendingCount = #order,
    order = order,
  }
end

function Collection.complete(run, id, name)
  if type(run) ~= "table" or run.id ~= id or run.pending[name] ~= true then
    return false, false
  end
  run.pending[name] = nil
  run.pendingCount = run.pendingCount - 1
  return true, run.pendingCount == 0
end

function Collection.pendingNames(run)
  local names = {}
  if type(run) ~= "table" then
    return names
  end
  for _, name in ipairs(run.order or {}) do
    if run.pending[name] == true then
      table.insert(names, name)
    end
  end
  return names
end

function Collection.expired(run, nowMs)
  return type(run) == "table"
    and type(run.deadlineAtMs) == "number"
    and type(nowMs) == "number"
    and nowMs >= run.deadlineAtMs
end

function Collection.nextRefreshAtMs(completedAtMs, intervalMs)
  if type(completedAtMs) ~= "number" or type(intervalMs) ~= "number" then
    return nil
  end
  return completedAtMs + intervalMs
end

function Collection.isDue(nextAtMs, nowMs)
  return type(nextAtMs) == "number" and type(nowMs) == "number" and nowMs >= nextAtMs
end

return Collection
