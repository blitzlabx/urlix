-- IP address helpers and private range checks for Urlix
-- Creator: Blitz (blitzlabx)

local _M = {}

-- Parse IPv4 string to number (or nil)
local function ipv4_to_num(ip)
    local a, b, c, d = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not a then return nil end
    a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    if not a or a > 255 or b > 255 or c > 255 or d > 255 then
        return nil
    end
    return a * 16777216 + b * 65536 + c * 256 + d
end

-- Check if IPv4 is in private / reserved ranges
function _M.is_private_ipv4(ip)
    local n = ipv4_to_num(ip)
    if not n then return false end

    -- 0.0.0.0/8
    if n >= 0 and n <= 16777215 then return true end
    -- 10.0.0.0/8
    if n >= 167772160 and n <= 184549375 then return true end
    -- 100.64.0.0/10 (CGNAT)
    if n >= 1681915904 and n <= 1686110207 then return true end
    -- 127.0.0.0/8
    if n >= 2130706432 and n <= 2147483647 then return true end
    -- 169.254.0.0/16 (link-local / metadata)
    if n >= 2851995648 and n <= 2852061183 then return true end
    -- 172.16.0.0/12
    if n >= 2886729728 and n <= 2887778303 then return true end
    -- 192.0.0.0/24
    if n >= 3221225472 and n <= 3221225727 then return true end
    -- 192.0.2.0/24 (TEST-NET-1)
    if n >= 3221225984 and n <= 3221226239 then return true end
    -- 192.168.0.0/16
    if n >= 3232235520 and n <= 3232301055 then return true end
    -- 198.18.0.0/15 (benchmark)
    if n >= 3323068416 and n <= 3323199487 then return true end
    -- 198.51.100.0/24 (TEST-NET-2)
    if n >= 3325256704 and n <= 3325256959 then return true end
    -- 203.0.113.0/24 (TEST-NET-3)
    if n >= 3405803776 and n <= 3405804031 then return true end
    -- 224.0.0.0/4 (multicast)
    if n >= 3758096384 and n <= 4026531839 then return true end
    -- 240.0.0.0/4 (reserved)
    if n >= 4026531840 then return true end

    return false
end

-- Basic IPv6 private / special checks (string based)
function _M.is_private_ipv6(ip)
    if not ip or type(ip) ~= "string" then return false end
    local lower = ip:lower()

    -- Loopback
    if lower == "::1" then return true end
    -- Unspecified
    if lower == "::" or lower == "0:0:0:0:0:0:0:0" then return true end
    -- Link-local fe80::/10
    if lower:match("^fe[89ab]") then return true end
    -- Unique local fc00::/7
    if lower:match("^f[cd]") then return true end
    -- Multicast ff00::/8
    if lower:match("^ff") then return true end
    -- IPv4-mapped ::ffff:0:0/96 – check embedded IPv4
    local mapped = lower:match("^::ffff:(%d+%.%d+%.%d+%.%d+)$")
        or lower:match("^0:0:0:0:0:ffff:(%d+%.%d+%.%d+%.%d+)$")
    if mapped and _M.is_private_ipv4(mapped) then
        return true
    end

    return false
end

function _M.is_private(ip)
    if not ip then return true end
    if ip:find(":", 1, true) then
        return _M.is_private_ipv6(ip)
    end
    return _M.is_private_ipv4(ip)
end

function _M.is_metadata_ip(ip)
    if not ip then return false end
    -- Classic cloud metadata
    if ip == "169.254.169.254" then return true end
    if ip == "169.254.170.2" then return true end  -- AWS ECS
    if ip == "10.255.255.254" then return true end -- some providers
    return false
end

return _M
