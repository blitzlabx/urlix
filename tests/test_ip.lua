-- Unit tests for IP utilities
-- Creator: Blitz (blitzlabx)

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local ip = require "utils.ip"

local passed, failed = 0, 0

local function assert_eq(a, b, msg)
  if a == b then passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. (msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
  end
end

-- Private IPv4
assert_eq(ip.is_private_ipv4("10.0.0.1"), true, "10.x")
assert_eq(ip.is_private_ipv4("192.168.1.1"), true, "192.168")
assert_eq(ip.is_private_ipv4("172.16.0.1"), true, "172.16")
assert_eq(ip.is_private_ipv4("127.0.0.1"), true, "loopback")
assert_eq(ip.is_private_ipv4("169.254.169.254"), true, "link-local")
assert_eq(ip.is_private_ipv4("8.8.8.8"), false, "public google")
assert_eq(ip.is_private_ipv4("1.1.1.1"), false, "public cf")

-- Metadata
assert_eq(ip.is_metadata_ip("169.254.169.254"), true, "metadata")
assert_eq(ip.is_metadata_ip("8.8.8.8"), false, "not metadata")

-- IPv6
assert_eq(ip.is_private_ipv6("::1"), true, "v6 loopback")
assert_eq(ip.is_private_ipv6("fe80::1"), true, "link local")
assert_eq(ip.is_private_ipv6("fc00::1"), true, "ula")
assert_eq(ip.is_private("2001:db8::1"), false, "doc prefix treated carefully - not private by our rules")

print(string.format("ip: %d passed, %d failed", passed, failed))
os.exit(failed > 0 and 1 or 0)
