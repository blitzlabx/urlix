-- URL structure parser for Urlix
-- Creator: Blitz (blitzlabx)

local _M = {}

-- Parse a URL into components without network activity
function _M.parse(url)
    if not url or type(url) ~= "string" then
        return nil, "invalid input"
    end

    url = url:match("^%s*(.-)%s*$")

    local result = {
        raw = url,
        scheme = nil,
        userinfo = nil,
        username = nil,
        password = nil,
        host = nil,
        hostname = nil,
        port = nil,
        path = nil,
        query = nil,
        query_params = {},
        fragment = nil,
        is_valid_structure = false,
    }

    -- Scheme
    local scheme, rest = url:match("^([a-zA-Z][a-zA-Z0-9+.-]*)://(.*)$")
    if not scheme then
        return result, "missing or invalid scheme"
    end
    result.scheme = scheme:lower()

    -- Fragment
    local before_frag, frag = rest:match("^(.-)#(.*)$")
    if before_frag then
        rest = before_frag
        result.fragment = frag
    end

    -- Query
    local before_query, query = rest:match("^(.-)%?(.*)$")
    if before_query then
        rest = before_query
        result.query = query
        result.query_params = _M.parse_query(query)
    end

    -- Authority and path
    local authority, path = rest:match("^([^/]*)(.*)$")
    if path == "" then path = "/" end
    result.path = path

    if authority and #authority > 0 then
        -- userinfo
        local userinfo, hostport = authority:match("^([^@]+)@(.+)$")
        if userinfo then
            result.userinfo = userinfo
            local user, pass = userinfo:match("^([^:]+):(.*)$")
            if user then
                result.username = user
                result.password = pass
            else
                result.username = userinfo
            end
            authority = hostport
        end

        -- IPv6 in brackets
        local ipv6, port = authority:match("^%[([^%]]+)%]:?(%d*)$")
        if ipv6 then
            result.host = ipv6
            result.hostname = ipv6
            if port and #port > 0 then
                result.port = tonumber(port)
            end
        else
            local host, p = authority:match("^([^:]+):?(%d*)$")
            if host then
                result.host = host
                result.hostname = host
                if p and #p > 0 then
                    result.port = tonumber(p)
                end
            else
                result.host = authority
                result.hostname = authority
            end
        end
    end

    -- Default ports
    if not result.port then
        if result.scheme == "https" then
            result.port = 443
        elseif result.scheme == "http" then
            result.port = 80
        end
    end

    result.is_valid_structure = (result.scheme ~= nil and result.hostname ~= nil and #result.hostname > 0)

    return result, nil
end

function _M.parse_query(qs)
    local params = {}
    if not qs or qs == "" then return params end

    for pair in qs:gmatch("([^&]+)") do
        local k, v = pair:match("^([^=]*)=?(.*)$")
        if k then
            k = _M.url_decode(k)
            v = _M.url_decode(v or "")
            if params[k] == nil then
                params[k] = v
            elseif type(params[k]) == "table" then
                table.insert(params[k], v)
            else
                params[k] = { params[k], v }
            end
        end
    end
    return params
end

function _M.url_decode(s)
    if not s then return "" end
    s = s:gsub("+", " ")
    s = s:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end)
    return s
end

function _M.url_encode(s)
    if not s then return "" end
    s = tostring(s)
    s = s:gsub("([^%w%-%.%_%~ ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    s = s:gsub(" ", "+")
    return s
end

return _M
