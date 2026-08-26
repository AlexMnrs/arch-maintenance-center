local A = require("./assertions")
local Bytes = require("../arch-maintenance-center/lib/bytes")

A.equal(Bytes.format(0), "0 B", "zero bytes formatted")
A.equal(Bytes.format(1023), "1023 B", "bytes stay in byte unit")
A.equal(Bytes.format(1024), "1.0 KiB", "kibibytes formatted")
A.equal(Bytes.format(1610612736), "1.5 GiB", "gibibytes formatted")
A.equal(Bytes.format(-1), "Unavailable", "negative size unavailable")
A.equal(Bytes.format("1"), "Unavailable", "non-number unavailable")

print("bytes_spec passed")
