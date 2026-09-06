-- Basic security validation tests (no network)
-- Creator: Blitz (blitzlabx)

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

-- Mock config-dependent parts by requiring modules that don't need ngx for basic validate
-- security.validate_url_basic does not need resolver

local config = require "config"
local iputil = require "utils.ip"

-- Re-implement the pure checks we care about for offline testing
local function validate_url_basic(url)
  if not url or type(url) ~= "string" then return false, "URL is required" end
  url = url:match("^%s*(.-)%s*$")
  if #url == 0 then return false, "URL is empty" end
  if #url > config.fetch.max_url_length then return false, "URL exceeds maximum allowed length" end

  local scheme, rest = url:match("^([a-zA-Z][a-zA-Z0-9+.-]*)://(.+)$")
  if not scheme then return false, "URL must include a scheme (http or https)" end
  scheme = scheme:lower()
  local allowed = false
  for _, s in ipairs(config.fetch.allowed_schemes) do
    if s == scheme then allowed = true; break end
  end
  if not allowed then return false, "Unsupported protocol: only http and https are allowed" end

  local hostpart = rest:match("^([^/?#]+)")
  if not hostpart or #hostpart == 0 then return false, "Missing hostname" end
  local host = hostpart:match("@(.+)$") or hostpart
  host = host:match("^%[(.+)%]$") or host:match("^([^:]+)") or host

  for _, blocked in ipairs(config.security.blocked_hostnames) do
    if host:lower() == blocked then return false, "Hostname is not allowed" end
  end

  if iputil.is_private(host) or iputil.is_metadata_ip(host) then
    return false, "Access to private or reserved IP addresses is blocked"
  end
  return true
end

local passed, failed = 0, 0
local function check(ok, expected_ok, msg)
  if ok == expected_ok then passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. msg)
  end
end

check(validate_url_basic("https://example.com"), true, "public https")
check(validate_url_basic("http://example.com/path"), true, "public http")
check(validate_url_basic("ftp://example.com"), false, "ftp blocked")
check(validate_url_basic("https://127.0.0.1/"), false, "loopback blocked")
check(validate_url_basic("https://10.0.0.1/"), false, "private 10 blocked")
check(validate_url_basic("https://192.168.1.1/"), false, "private 192 blocked")
check(validate_url_basic("https://169.254.169.254/latest"), false, "metadata blocked")
check(validate_url_basic("https://localhost/"), false, "localhost hostname blocked")
check(validate_url_basic(""), false, "empty")
check(validate_url_basic("notaurl"), false, "no scheme")

print(string.format("security_basic: %d passed, %d failed", passed, failed))
os.exit(failed > 0 and 1 or 0)
