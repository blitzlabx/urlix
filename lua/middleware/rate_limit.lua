-- Simple in-memory rate limiter for Urlix
-- Creator: Blitz (blitzlabx)
-- Note: per-worker; suitable for single-instance / small deployments.
-- For multi-instance production, replace with Redis-backed limiter.

local config = require "config"
local response = require "utils.response"

local _M = {}

-- Shared dict must be declared in nginx.conf
local dict_name = "urlix_ratelimit"

function _M.check()
    if not config.rate_limit.enabled then
        return true
    end

    local dict = ngx.shared[dict_name]
    if not dict then
        -- Shared dict missing; allow (fail open) but log
        ngx.log(ngx.WARN, "rate limit shared dict not found, allowing request")
        return true
    end

    local ip = ngx.var.remote_addr or "unknown"
    local key = "rl:" .. ip
    local window = config.rate_limit.window_seconds
    local limit = config.rate_limit.max_requests

    local current = dict:get(key)
    if current == nil then
        dict:set(key, 1, window)
        return true
    end

    if current >= limit then
        local ttl = dict:ttl(key)
        ngx.header["Retry-After"] = tostring(math.ceil(ttl > 0 and ttl or window))
        ngx.header["X-RateLimit-Limit"] = tostring(limit)
        ngx.header["X-RateLimit-Remaining"] = "0"
        response.error(
            "RATE_LIMITED",
            "Too many requests. Please slow down.",
            {
                limit = limit,
                window_seconds = window,
                retry_after = math.ceil(ttl > 0 and ttl or window)
            },
            429
        )
        return false
    end

    dict:incr(key, 1)
    local remaining = limit - (current + 1)
    ngx.header["X-RateLimit-Limit"] = tostring(limit)
    ngx.header["X-RateLimit-Remaining"] = tostring(math.max(0, remaining))
    return true
end

return _M
