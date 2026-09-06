-- Urlix Configuration
-- Creator: Blitz (blitzlabx)

local _M = {}

-- Application metadata
_M.app = {
    name = "Urlix",
    version = "1.0.0",
    creator = "Blitz",
    github = "blitzlabx",
    description = "Public URL Inspection & Analysis Service"
}

-- Server settings (PORT is set by Render)
_M.server = {
    port = tonumber(os.getenv("PORT")) or 8080,
    host = "0.0.0.0"
}

-- Fetch / analysis limits
_M.fetch = {
    timeout_connect = 5,          -- seconds
    timeout_send = 5,
    timeout_read = 10,
    max_redirects = 10,
    max_response_size = 512 * 1024, -- 512 KB
    user_agent = "Urlix/1.0 (+https://github.com/blitzlabx/urlix; public URL analysis)",
    allowed_schemes = { "http", "https" },
    max_url_length = 2048,
}

-- Rate limiting (simple in-memory, per IP)
_M.rate_limit = {
    enabled = true,
    window_seconds = 60,
    max_requests = 30,            -- per window per IP
}

-- Security / SSRF protection
_M.security = {
    block_private_ips = true,
    block_loopback = true,
    block_link_local = true,
    block_metadata_endpoints = true,  -- cloud metadata 169.254.169.254 etc.
    resolve_and_check = true,         -- DNS resolve then re-check IPs
    blocked_hostnames = {
        "localhost",
        "localhost.localdomain",
        "ip6-localhost",
        "ip6-loopback",
    },
}

-- Response schema version
_M.schema_version = "1.0"

return _M
