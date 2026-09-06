-- Unit tests for URL parser
-- Creator: Blitz (blitzlabx)
-- Run: lua tests/test_url_parser.lua  (from project root with LUA_PATH)

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local parser = require "services.url_parser"

local passed = 0
local failed = 0

local function assert_eq(a, b, msg)
  if a == b then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. (msg or "") .. " expected [" .. tostring(b) .. "] got [" .. tostring(a) .. "]")
  end
end

local function assert_true(v, msg)
  if v then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. (msg or "expected true"))
  end
end

-- Basic HTTPS
local p = parser.parse("https://example.com/path?q=1#frag")
assert_true(p.is_valid_structure, "valid structure")
assert_eq(p.scheme, "https", "scheme")
assert_eq(p.hostname, "example.com", "hostname")
assert_eq(p.port, 443, "default https port")
assert_eq(p.path, "/path", "path")
assert_eq(p.query, "q=1", "query")
assert_eq(p.fragment, "frag", "fragment")
assert_eq(p.query_params.q, "1", "query param")

-- HTTP with port
p = parser.parse("http://localhost:8080/")
assert_eq(p.scheme, "http", "http scheme")
assert_eq(p.port, 8080, "custom port")
assert_eq(p.hostname, "localhost", "localhost host")

-- Userinfo
p = parser.parse("https://user:pass@example.com/a")
assert_eq(p.username, "user", "username")
assert_eq(p.password, "pass", "password")
assert_eq(p.hostname, "example.com", "host after userinfo")

-- Query multi
p = parser.parse("https://ex.com/?a=1&b=2&a=3")
assert_true(type(p.query_params.a) == "table", "multi value a")
assert_eq(p.query_params.b, "2", "param b")

-- Invalid
p = parser.parse("not-a-url")
assert_true(not p.is_valid_structure, "invalid structure")

-- IPv6
p = parser.parse("https://[2001:db8::1]:8443/x")
assert_eq(p.hostname, "2001:db8::1", "ipv6 host")
assert_eq(p.port, 8443, "ipv6 port")

print(string.format("url_parser: %d passed, %d failed", passed, failed))
os.exit(failed > 0 and 1 or 0)
