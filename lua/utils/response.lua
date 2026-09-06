-- Standardized API responses for Urlix
-- Creator: Blitz (blitzlabx)

local json = require "utils.json"
local config = require "config"

local _M = {}

local function set_json_headers(status)
    ngx.status = status
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.header["X-Content-Type-Options"] = "nosniff"
    ngx.header["X-Frame-Options"] = "DENY"
    ngx.header["Referrer-Policy"] = "no-referrer"
    ngx.header["Cache-Control"] = "no-store"
    ngx.header["X-Urlix-Version"] = config.app.version
end

function _M.success(data, status)
    status = status or 200
    set_json_headers(status)
    local body = {
        success = true,
        schema_version = config.schema_version,
        data = data,
        meta = {
            service = config.app.name,
            version = config.app.version,
            creator = config.app.creator
        }
    }
    ngx.say(json.encode(body))
    return ngx.exit(status)
end

function _M.error(code, message, details, status)
    status = status or 400
    set_json_headers(status)
    local body = {
        success = false,
        schema_version = config.schema_version,
        error = {
            code = code,
            message = message,
            details = details or ngx.null
        },
        meta = {
            service = config.app.name,
            version = config.app.version,
            creator = config.app.creator
        }
    }
    ngx.say(json.encode(body))
    return ngx.exit(status)
end

function _M.raw_json(tbl, status)
    status = status or 200
    set_json_headers(status)
    ngx.say(json.encode(tbl))
    return ngx.exit(status)
end

return _M
