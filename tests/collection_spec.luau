local A = require("./assertions")
local Collection = require("../arch-maintenance-center/lib/collection")

local run = Collection.new(7, 100, 135, { "updates", "services", "disk" })
A.equal(#Collection.pendingNames(run), 3, "all modules start pending")
A.equal(Collection.expired(run, 134), false, "deadline has not elapsed")
A.equal(Collection.expired(run, 135), true, "deadline is inclusive")

local accepted, complete = Collection.complete(run, 7, "updates")
A.equal(accepted, true, "current callback accepted")
A.equal(complete, false, "partial completion remains active")
A.equal(#Collection.pendingNames(run), 2, "deadline leaves only pending modules")

local duplicateAccepted, duplicateComplete = Collection.complete(run, 7, "updates")
A.equal(duplicateAccepted, false, "duplicate callback ignored")
A.equal(duplicateComplete, false, "duplicate cannot complete run")

local successor = Collection.new(8, 200, 235, { "updates", "services", "disk" })
local lateAccepted, lateComplete = Collection.complete(successor, 7, "services")
A.equal(lateAccepted, false, "older generation callback ignored")
A.equal(lateComplete, false, "older generation cannot complete run")

A.equal(Collection.complete(run, 7, "services"), true, "second module accepted")
local finalAccepted, finalComplete = Collection.complete(run, 7, "disk")
A.equal(finalAccepted, true, "last module accepted")
A.equal(finalComplete, true, "normal collection completes")
A.equal(#Collection.pendingNames(run), 0, "no modules remain after completion")

local nextAtMs = Collection.nextRefreshAtMs(1000, 900000)
A.equal(nextAtMs, 901000, "automatic refresh is scheduled from completion")
A.equal(Collection.isDue(nextAtMs, 900999), false, "automatic refresh waits for interval")
A.equal(Collection.isDue(nextAtMs, 901000), true, "automatic refresh is due at interval")

print("collection_spec passed")
