local A = require("./assertions")
local Platform = require("../arch-maintenance-center/lib/platform")

A.equal(Platform.parseOsRelease("# comment\nNAME=Arch\nID=arch\n"), "arch", "plain Arch id parsed")
A.equal(Platform.parseOsRelease("ID=\"arch\"\n"), "arch", "double quoted id parsed")
A.equal(Platform.parseOsRelease("ID='arch'\n"), "arch", "single quoted id parsed")

local unsupported = Platform.classify("ID=endeavouros\nID_LIKE=arch\n")
A.equal(unsupported.state, "unsupported", "Arch derivatives remain unsupported")

local missing, missingError = Platform.parseOsRelease("NAME=Arch Linux\n")
A.equal(missing, nil, "missing id rejected")
A.equal(missingError, "missing_id", "missing id traced")

local duplicate, duplicateError = Platform.parseOsRelease("ID=arch\nID=arch\n")
A.equal(duplicate, nil, "duplicate ids rejected")
A.equal(duplicateError, "duplicate_id", "duplicate id traced")

local hostile, hostileError = Platform.parseOsRelease("ID=arch;rm\n")
A.equal(hostile, nil, "hostile id rejected")
A.equal(hostileError, "malformed_id", "hostile id traced")

local oversized, oversizedError = Platform.parseOsRelease(string.rep("x", Platform.maxOsReleaseBytes() + 1))
A.equal(oversized, nil, "oversized output rejected")
A.equal(oversizedError, "output_too_large", "oversized output traced")

local supported = Platform.classify("ID=arch\n")
A.equal(supported.state, "supported", "Arch is supported")
A.equal(supported.id, "arch", "Arch id retained")

local readFailure = Platform.classify(nil)
A.equal(readFailure.state, "error", "missing platform output becomes an error")
A.equal(readFailure.detail, "invalid_output", "platform parse errors stay traceable")

print("platform_spec passed")
