-- SSRF protection and URL safety checks for Urlix
-- Creator: Blitz (blitzlabx)

local config = require "config"
local iputil = require "utils.ip"
local resolver = require "resty.dns.resolver"

local _M = {}

local function is_blocked_hostname(host)
    if not host then return true end
    local h = host:lower()
    for _, blocked in ipairs(config.security.blocked_hostnames) do
        if h == blocked then return true end
    end
    -- Numeric-looking hostnames that resolve to private are caught later
    return false
end

-- Validate scheme and basic structure before any network activity
function _M.validate_url_basic(url)
    if not url or type(url) ~= "string" then
        return false, "URL is required"
    end

    url = url:match("^%s*(.-)%s*$") -- trim
    if #url == 0 then
        return false, "URL is empty"
    end
    if #url > config.fetch.max_url_length then
        return false, "URL exceeds maximum allowed length"
    end

    -- Must look like a URL with scheme
    local scheme, rest = url:match("^([a-zA-Z][a-zA-Z0-9+.-]*)://(.+)$")
    if not scheme then
        return false, "URL must include a scheme (http or https)"
    end

    scheme = scheme:lower()
    local allowed = false
    for _, s in ipairs(config.fetch.allowed_schemes) do
        if s == scheme then allowed = true; break end
    end
    if not allowed then
        return false, "Unsupported protocol: only http and https are allowed"
    end

    -- Extract host roughly for early rejection
    local hostpart = rest:match("^([^/?#]+)")
    if not hostpart or #hostpart == 0 then
        return false, "Missing hostname"
    end

    -- Strip userinfo if present
    local host = hostpart:match("@(.+)$") or hostpart
    -- Strip port
    host = host:match("^%[(.+)%]$") or host:match("^([^:]+)") or host

    if is_blocked_hostname(host) then
        return false, "Hostname is not allowed"
    end

    -- Immediate reject of literal private IPs in the URL
    if iputil.is_private(host) or iputil.is_metadata_ip(host) then
        return false, "Access to private or reserved IP addresses is blocked"
    end

    return true, nil, scheme, host
end

-- Resolve hostname and ensure no private/metadata IPs
function _M.resolve_and_validate(host)
    if not config.security.resolve_and_check then
        return true, nil
    end

    -- If host is already an IP literal, we already checked it
    if host:match("^%d+%.%d+%.%d+%.%d+$") or host:find(":", 1, true) then
        if iputil.is_private(host) or iputil.is_metadata_ip(host) then
            return false, "Resolved address is private or reserved"
        end
        return true, { host }
    end

    local r, err = resolver:new{
        nameservers = { "8.8.8.8", "1.1.1.1", "8.8.4.4" },
        retrans = 2,
        timeout = 3000,
    }
    if not r then
        return false, "DNS resolver initialization failed: " .. (err or "unknown")
    end

    local answers, err = r:query(host, { qtype = r.TYPE_A })
    if not answers then
        -- try AAAA
        answers, err = r:query(host, { qtype = r.TYPE_AAAA })
    end

    if not answers then
        return false, "DNS resolution failed: " .. (err or "no answers")
    end

    if answers.errcode then
        return false, "DNS error: " .. (answers.errstr or tostring(answers.errcode))
    end

    local ips = {}
    for _, ans in ipairs(answers) do
        if ans.address then
            table.insert(ips, ans.address)
            if iputil.is_private(ans.address) or iputil.is_metadata_ip(ans.address) then
                return false, "Hostname resolves to a private or reserved address"
            end
        end
    end

    if #ips == 0 then
        return false, "No usable IP addresses resolved"
    end

    return true, ips
end

-- Full pre-flight check
function _M.check_url(url)
    local ok, err, scheme, host = _M.validate_url_basic(url)
    if not ok then
        return false, err
    end

    local ok2, err2 = _M.resolve_and_validate(host)
    if not ok2 then
        return false, err2
    end

    return true, nil, scheme, host
end

return _M
