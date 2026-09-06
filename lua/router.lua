-- Simple router for Urlix
-- Creator: Blitz (blitzlabx)

local response = require "utils.response"
local health = require "handlers.health"
local analyze = require "handlers.analyze"
local config = require "config"

local _M = {}

function _M.dispatch()
    local uri = ngx.var.uri
    local method = ngx.req.get_method()

    -- Normalize trailing slash for API routes (keep root)
    if uri ~= "/" and uri:sub(-1) == "/" then
        uri = uri:sub(1, -2)
    end

    -- Health endpoints (UptimeRobot friendly)
    if uri == "/ping" and method == "GET" then
        return health.ping()
    end
    if (uri == "/health" or uri == "/healthz") and method == "GET" then
        return health.health()
    end

    -- API
    if uri == "/api/v1/analyze" then
        return analyze.handle()
    end

    -- API info
    if uri == "/api" or uri == "/api/v1" then
        return response.success({
            name = config.app.name,
            version = config.app.version,
            creator = config.app.creator,
            github = config.app.github,
            endpoints = {
                { method = "GET", path = "/ping", description = "Liveness probe" },
                { method = "GET", path = "/health", description = "Health check" },
                { method = "GET|POST", path = "/api/v1/analyze", description = "Analyze a URL" },
            },
            docs = "See README.md or / for the web interface"
        })
    end

    -- Static / SPA fallback is handled by nginx; if we reach here for unknown API
    if uri:match("^/api") then
        return response.error("NOT_FOUND", "Endpoint not found", { path = uri }, 404)
    end

    -- Let nginx serve static for everything else
    return ngx.exec("@static")
end

return _M
