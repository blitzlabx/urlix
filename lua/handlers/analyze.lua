-- URL analysis endpoint for Urlix
-- Creator: Blitz (blitzlabx)

local response = require "utils.response"
local config = require "config"
local security = require "services.security"
local url_parser = require "services.url_parser"
local fetcher = require "services.fetcher"
local rate_limit = require "middleware.rate_limit"

local _M = {}

local function get_request_url()
    local method = ngx.req.get_method()
    local url = nil

    if method == "GET" then
        local args = ngx.req.get_uri_args()
        url = args.url or args.u
    elseif method == "POST" then
        ngx.req.read_body()
        local body = ngx.req.get_body_data()
        if body then
            local cjson = require "cjson.safe"
            local data = cjson.decode(body)
            if data and type(data) == "table" then
                url = data.url or data.target
            end
        end
        if not url then
            local args = ngx.req.get_post_args()
            url = args.url or args.target
        end
    end

    return url
end

function _M.handle()
    if not rate_limit.check() then
        return -- already responded
    end

    local method = ngx.req.get_method()
    if method ~= "GET" and method ~= "POST" then
        return response.error("METHOD_NOT_ALLOWED", "Only GET and POST are supported", nil, 405)
    end

    local url = get_request_url()
    if not url or url == "" then
        return response.error(
            "MISSING_URL",
            "Query parameter or JSON body field 'url' is required",
            { example = "/api/v1/analyze?url=https://example.com" },
            400
        )
    end

    -- Basic validation + SSRF pre-check
    local ok, err = security.check_url(url)
    if not ok then
        return response.error(
            "URL_BLOCKED",
            err or "URL failed security checks",
            { url = url },
            400
        )
    end

    -- Parse structure
    local parsed, parse_err = url_parser.parse(url)
    if not parsed or not parsed.is_valid_structure then
        return response.error(
            "INVALID_URL",
            parse_err or "Could not parse URL",
            { url = url },
            400
        )
    end

    -- Fetch with redirects
    local result = fetcher.fetch(url)

    if not result.success then
        local status = 422
        if result.error_code == "SECURITY_BLOCKED" then status = 400 end
        if result.error_code == "TOO_MANY_REDIRECTS" then status = 422 end
        if result.error_code == "FETCH_FAILED" then status = 502 end

        return response.error(
            result.error_code or "ANALYSIS_FAILED",
            result.error or "Analysis failed",
            {
                url = url,
                redirect_chain = result.redirect_chain,
                issues = result.issues,
                timing = result.timing
            },
            status
        )
    end

    -- Build clean response data
    local data = {
        input_url = url,
        parsed = {
            scheme = parsed.scheme,
            username = parsed.username,
            host = parsed.host,
            hostname = parsed.hostname,
            port = parsed.port,
            path = parsed.path,
            query = parsed.query,
            query_params = parsed.query_params,
            fragment = parsed.fragment,
        },
        final_url = result.final_url,
        status_code = result.status,
        content_type = result.content_type,
        title = result.title,
        description = result.description,
        canonical_url = result.canonical,
        headers = result.headers,
        security_headers = result.security_headers,
        redirect_chain = result.redirect_chain,
        hops = result.hops,
        timing = result.timing,
        body_size_bytes = result.body_size,
        issues = result.issues,
    }

    return response.success(data, 200)
end

return _M
