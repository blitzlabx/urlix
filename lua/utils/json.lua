-- Minimal JSON helpers for Urlix
-- Creator: Blitz (blitzlabx)

local cjson = require "cjson.safe"

local _M = {}

function _M.encode(tbl)
    return cjson.encode(tbl)
end

function _M.decode(str)
    return cjson.decode(str)
end

function _M.pretty(tbl)
    -- cjson does not pretty-print; return compact for production
    return cjson.encode(tbl)
end

return _M
