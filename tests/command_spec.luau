local A = require("./assertions")
local Command = require("../arch-maintenance-center/lib/command")

A.equal(Command.failure(nil), "command_failed", "missing result fails")
A.equal(Command.failure({ timedOut = true }), "command_timed_out", "timeout is classified")
A.equal(Command.failure({ stdoutTruncated = true }), "command_output_truncated", "truncated stdout is classified")
A.equal(Command.failure({ stderrTruncated = true }), "command_output_truncated", "truncated stderr is classified")
A.equal(Command.failure({ exitCode = 1 }), nil, "exit status is left to the module parser")

print("command_spec passed")
