-- Health and ping endpoints for Urlix
-- Creator: Blitz (blitzlabx)

local response = require "utils.response"
local config = require "config"

local _M = {}

function _M.ping()
    response.raw_json({
        status = "ok",
        service = config.app.name,
        version = config.app.version,
        creator = config.app.creator
    }, 200)
end

function _M.health()
    -- Basic liveness; can be extended with dependency checks
    local ok = true
    local checks = {
        {
            name = "process",
            status = "ok"
        }
    }

    response.raw_json({
        status = ok and "healthy" or "unhealthy",
        service = config.app.name,
        version = config.app.version,
        creator = config.app.creator,
        timestamp = ngx.now(),
        checks = checks
    }, ok and 200 or 503)
end

return _M
