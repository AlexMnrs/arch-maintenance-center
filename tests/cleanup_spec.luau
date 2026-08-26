local A = require("./assertions")
local Cleanup = require("../arch-maintenance-center/lib/cleanup")

local cache = Cleanup.cacheFromDu(0, "3221225472\t/var/cache/pacman/pkg\n")
A.equal(cache.state, "ready", "cache size is ready")
A.equal(cache.data.bytes, 3221225472, "cache bytes retained")

local invalidCache = Cleanup.cacheFromDu(0, "not-a-size")
A.equal(invalidCache.state, "error", "malformed cache rejected")

local orphans = Cleanup.orphansFromSummary(0, "package\tfoo\npackage\tbar\ncount\t9\n")
A.equal(orphans.state, "ready", "orphan sample ready")
A.equal(orphans.data.count, 9, "orphan total retained")
A.equal(#orphans.data.packages, 2, "orphan sample retained")
A.equal(orphans.data.truncated, true, "orphan sample marked truncated")

local noOrphans = Cleanup.orphansFromSummary(1, "count\t0\n")
A.equal(noOrphans.state, "ready", "pacman empty status is handled")
A.equal(noOrphans.data.count, 0, "zero orphans retained")

local malformedOrphans = Cleanup.orphansFromSummary(0, "package\tbad name\ncount\t1\n")
A.equal(malformedOrphans.state, "error", "invalid package name rejected")

A.equal(Cleanup.parseJournalUsage("Archived and active journals take up 428.0M in the file system."), 448790528, "journal megabytes parsed")
local invalidJournal = Cleanup.journalFromUsage(0, "unexpected")
A.equal(invalidJournal.state, "error", "invalid journal output rejected")

local complete = Cleanup.aggregate(cache, orphans, Cleanup.journalFromUsage(0, "Archived and active journals take up 1.0G in the file system."), 1)
A.equal(complete.state, "ready", "cleanup aggregate ready")
A.equal(complete.severity, "info", "orphans are informational")
A.equal(complete.complete, true, "all cleanup sources complete")

local partial = Cleanup.aggregate(cache, Cleanup.error("timeout"), Cleanup.journalFromUsage(0, "Archived and active journals take up 1.0G in the file system."), 1)
A.equal(partial.state, "ready", "partial cleanup retains available data")
A.equal(partial.complete, false, "missing cleanup source is partial")

local unavailable = Cleanup.aggregate(Cleanup.error("missing_cache"), Cleanup.error("missing_pacman"), Cleanup.error("missing_journal"), 1)
A.equal(unavailable.state, "error", "all unavailable cleanup sources fail the module")
A.equal(unavailable.data.cache.detail, "missing_cache", "unavailable cache source remains traceable")
A.equal(unavailable.data.orphans.detail, "missing_pacman", "unavailable orphan source remains traceable")
A.equal(unavailable.data.journal.detail, "missing_journal", "unavailable journal source remains traceable")

print("cleanup_spec passed")
