-- Safe HTTP fetcher with redirect following for Urlix
-- Creator: Blitz (blitzlabx)

local http = require "resty.http"
local config = require "config"
local security = require "services.security"
local url_parser = require "services.url_parser"
local iputil = require "utils.ip"

local _M = {}

local function extract_title(body)
    if not body then return nil end
    local title = body:match("<[Tt][Ii][Tt][Ll][Ee][^>]*>(.-)</[Tt][Ii][Tt][Ll][Ee]>")
    if title then
        title = title:gsub("%s+", " "):match("^%s*(.-)%s*$")
        if #title > 300 then title = title:sub(1, 297) .. "..." end
        return title
    end
    return nil
end

local function extract_meta(body, name)
    if not body then return nil end
    -- name= or property=
    local pattern1 = '<[Mm][Ee][Tt][Aa][^>]+[Nn][Aa][Mm][Ee]=["\']' .. name .. '["\'][^>]+[Cc][Oo][Nn][Tt][Ee][Nn][Tt]=["\'](.-)["\']'
    local pattern2 = '<[Mm][Ee][Tt][Aa][^>]+[Cc][Oo][Nn][Tt][Ee][Nn][Tt]=["\'](.-)["\'][^>]+[Nn][Aa][Mm][Ee]=["\']' .. name .. '["\']'
    local pattern3 = '<[Mm][Ee][Tt][Aa][^>]+[Pp][Rr][Oo][Pp][Ee][Rr][Tt][Yy]=["\']' .. name .. '["\'][^>]+[Cc][Oo][Nn][Tt][Ee][Nn][Tt]=["\'](.-)["\']'
    local pattern4 = '<[Mm][Ee][Tt][Aa][^>]+[Cc][Oo][Nn][Tt][Ee][Nn][Tt]=["\'](.-)["\'][^>]+[Pp][Rr][Oo][Pp][Ee][Rr][Tt][Yy]=["\']' .. name .. '["\']'

    local v = body:match(pattern1) or body:match(pattern2) or body:match(pattern3) or body:match(pattern4)
    if v then
        v = v:gsub("%s+", " "):match("^%s*(.-)%s*$")
        if #v > 500 then v = v:sub(1, 497) .. "..." end
        return v
    end
    return nil
end

local function extract_canonical(body)
    if not body then return nil end
    local href = body:match('<[Ll][Ii][Nn][Kk][^>]+[Rr][Ee][Ll]=["\']canonical["\'][^>]+[Hh][Rr][Ee][Ff]=["\'](.-)["\']')
        or body:match('<[Ll][Ii][Nn][Kk][^>]+[Hh][Rr][Ee][Ff]=["\'](.-)["\'][^>]+[Rr][Ee][Ll]=["\']canonical["\']')
    return href
end

local function normalize_headers(headers)
    local out = {}
    if not headers then return out end
    for k, v in pairs(headers) do
        if type(k) == "string" then
            local key = k:lower()
            if type(v) == "table" then
                out[key] = table.concat(v, ", ")
            else
                out[key] = tostring(v)
            end
        end
    end
    return out
end

local function build_request_url(parsed)
    local port = parsed.port
    local default = (parsed.scheme == "https") and 443 or 80
    local hostpart = parsed.hostname
    if parsed.hostname:find(":", 1, true) then
        hostpart = "[" .. parsed.hostname .. "]"
    end
    if port and port ~= default then
        hostpart = hostpart .. ":" .. tostring(port)
    end
    local path = parsed.path or "/"
    local q = parsed.query and ("?" .. parsed.query) or ""
    return parsed.scheme .. "://" .. hostpart .. path .. q
end

function _M.fetch(url, opts)
    opts = opts or {}
    local max_redirects = opts.max_redirects or config.fetch.max_redirects
    local timeout_connect = opts.timeout_connect or config.fetch.timeout_connect
    local timeout_send = opts.timeout_send or config.fetch.timeout_send
    local timeout_read = opts.timeout_read or config.fetch.timeout_read
    local max_size = opts.max_response_size or config.fetch.max_response_size

    local chain = {}
    local current = url
    local final_body = nil
    local final_headers = nil
    local final_status = nil
    local final_url = url
    local total_time = 0
    local issues = {}

    for hop = 0, max_redirects do
        -- Security check on every hop (prevents redirect-to-private)
        local ok, err = security.check_url(current)
        if not ok then
            table.insert(issues, {
                type = "security",
                message = err,
                url = current,
                hop = hop
            })
            return {
                success = false,
                error = err,
                error_code = "SECURITY_BLOCKED",
                redirect_chain = chain,
                issues = issues,
                hops = hop
            }
        end

        local parsed = url_parser.parse(current)
        if not parsed.is_valid_structure then
            table.insert(issues, { type = "parse", message = "Invalid URL structure", url = current })
            return {
                success = false,
                error = "Invalid URL structure at hop " .. hop,
                error_code = "INVALID_URL",
                redirect_chain = chain,
                issues = issues
            }
        end

        local httpc = http.new()
        httpc:set_timeouts(timeout_connect * 1000, timeout_send * 1000, timeout_read * 1000)

        local start = ngx.now()
        local res, req_err = httpc:request_uri(current, {
            method = "GET",
            headers = {
                ["User-Agent"] = config.fetch.user_agent,
                ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                ["Accept-Language"] = "en-US,en;q=0.5",
                ["Connection"] = "close",
            },
            ssl_verify = true,
            keepalive = false,
            max_body_size = max_size,
        })
        local elapsed = ngx.now() - start
        total_time = total_time + elapsed

        if not res then
            local err_msg = req_err or "request failed"
            -- Map common OpenSSL errors to clearer messages
            if type(err_msg) == "string" and err_msg:find("certificate", 1, true) then
                err_msg = "TLS certificate verification failed: " .. err_msg
                    .. " (ensure system CA certificates are available)"
            end
            table.insert(issues, {
                type = "network",
                message = err_msg,
                url = current,
                hop = hop
            })
            httpc:close()
            return {
                success = false,
                error = err_msg,
                error_code = "FETCH_FAILED",
                redirect_chain = chain,
                issues = issues,
                timing = { total_seconds = total_time }
            }
        end

        local hop_info = {
            url = current,
            status = res.status,
            status_text = res.reason or "",
            headers = normalize_headers(res.headers),
            timing_seconds = elapsed,
            hop = hop,
        }
        table.insert(chain, hop_info)

        final_status = res.status
        final_headers = hop_info.headers
        final_url = current
        final_body = res.body

        -- Redirect?
        if res.status >= 300 and res.status < 400 and res.headers["Location"] then
            local location = res.headers["Location"]
            if type(location) == "table" then location = location[1] end
            location = tostring(location)

            -- Resolve relative redirects
            if not location:match("^https?://") then
                local base = parsed.scheme .. "://" .. (parsed.hostname:find(":") and ("[" .. parsed.hostname .. "]") or parsed.hostname)
                if parsed.port and parsed.port ~= ((parsed.scheme == "https") and 443 or 80) then
                    base = base .. ":" .. parsed.port
                end
                if location:sub(1, 1) == "/" then
                    location = base .. location
                else
                    local dir = (parsed.path or "/"):match("(.*/)") or "/"
                    location = base .. dir .. location
                end
            end

            current = location
            httpc:close()

            if hop >= max_redirects then
                table.insert(issues, {
                    type = "redirect",
                    message = "Exceeded maximum redirect limit (" .. max_redirects .. ")",
                    url = current
                })
                return {
                    success = false,
                    error = "Too many redirects",
                    error_code = "TOO_MANY_REDIRECTS",
                    redirect_chain = chain,
                    issues = issues,
                    timing = { total_seconds = total_time }
                }
            end
        else
            httpc:close()
            break
        end
    end

    -- Parse final page metadata if HTML-ish
    local content_type = final_headers and (final_headers["content-type"] or "") or ""
    local title, description, canonical = nil, nil, nil
    if final_body and (content_type:find("text/html") or content_type:find("application/xhtml") or content_type == "") then
        title = extract_title(final_body)
        description = extract_meta(final_body, "description")
            or extract_meta(final_body, "og:description")
        canonical = extract_canonical(final_body)
    end

    -- Security headers analysis
    local security_headers = {
        strict_transport_security = final_headers and final_headers["strict-transport-security"] or nil,
        content_security_policy = final_headers and final_headers["content-security-policy"] or nil,
        x_frame_options = final_headers and final_headers["x-frame-options"] or nil,
        x_content_type_options = final_headers and final_headers["x-content-type-options"] or nil,
        referrer_policy = final_headers and final_headers["referrer-policy"] or nil,
        permissions_policy = final_headers and final_headers["permissions-policy"] or nil,
    }

    return {
        success = true,
        final_url = final_url,
        status = final_status,
        headers = final_headers,
        content_type = content_type,
        title = title,
        description = description,
        canonical = canonical,
        redirect_chain = chain,
        hops = #chain,
        timing = {
            total_seconds = total_time,
        },
        security_headers = security_headers,
        body_size = final_body and #final_body or 0,
        issues = issues,
    }
end

return _M
