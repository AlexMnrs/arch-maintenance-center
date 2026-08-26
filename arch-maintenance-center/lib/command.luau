local Command = {}

function Command.failure(result)
  if type(result) ~= "table" then
    return "command_failed"
  elseif result.timedOut == true then
    return "command_timed_out"
  elseif result.stdoutTruncated == true or result.stderrTruncated == true then
    return "command_output_truncated"
  end
  return nil
end

return Command
