# Urlix

**Public URL Inspection & Analysis Service**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Lua](https://img.shields.io/badge/Lua-5.1%20%2F%20LuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org/)
[![OpenResty](https://img.shields.io/badge/OpenResty-ready-00A651)](https://openresty.org/)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Render](https://img.shields.io/badge/Render-deploy-46E3B7)](https://render.com/)
[![Creator](https://img.shields.io/badge/Creator-Blitz-3B82F6)](https://github.com/blitzlabx)
[![GitHub](https://img.shields.io/badge/GitHub-blitzlabx-181717?logo=github)](https://github.com/blitzlabx)

Created and maintained by **Blitz** ([blitzlabx](https://github.com/blitzlabx)).

---

## Overview

**Urlix** is a lightweight, production-ready public REST API and web interface for inspecting and analyzing URLs. It parses structure, follows redirect chains, captures status codes and headers, extracts basic page metadata, measures timing, and applies strong SSRF and safety protections — with **no authentication** required.

It is designed for developers who need a clean, fast, and secure way to understand what a public URL resolves to and returns.

### Why Urlix?

- Pure Lua / OpenResty stack — high performance, low footprint
- Explicit SSRF protection (private IPs, metadata endpoints, DNS rebinding checks)
- Configurable redirect limits, timeouts, and response size caps
- Consistent JSON schemas and clear error codes
- Polished developer-focused web UI
- Ready for Docker and Render deployment

---

## Features

### Analysis

- URL structure breakdown (scheme, host, port, path, query, fragment, userinfo)
- Query parameter parsing
- Redirect chain following with hop-by-hop status and timing
- Final HTTP status code and response headers
- Content-Type, page title, meta description, canonical URL
- Selected security-related response headers
- Response timing and body size (capped)

### Safety & reliability

- HTTP / HTTPS only
- Private, loopback, link-local, and reserved IP blocking
- Cloud metadata endpoint blocking (e.g. `169.254.169.254`)
- DNS resolution + post-resolve IP checks
- Hostname blocklist (`localhost`, etc.)
- Redirect limit enforcement
- Connect / send / read timeouts
- Response body size limit
- Simple per-IP rate limiting
- Request validation and structured error responses

### Operations

- `GET /ping` and `GET /health` for UptimeRobot and load balancers
- Docker image based on official OpenResty
- Render blueprint (`render.yaml`)
- Environment-aware `PORT` binding

---

## Architecture

```
urlix/
├── conf/nginx.conf          # OpenResty server config
├── lua/
│   ├── config.lua           # Central configuration
│   ├── router.lua           # Request routing
│   ├── handlers/
│   │   ├── analyze.lua      # /api/v1/analyze
│   │   └── health.lua       # /ping, /health
│   ├── services/
│   │   ├── security.lua     # SSRF & URL safety
│   │   ├── url_parser.lua   # Structure parsing
│   │   └── fetcher.lua      # HTTP client + redirects
│   ├── middleware/
│   │   └── rate_limit.lua   # In-memory rate limit
│   └── utils/
│       ├── ip.lua           # Private IP detection
│       ├── json.lua
│       └── response.lua     # Standard JSON envelopes
├── static/                  # Web UI
├── tests/                   # Offline unit tests
├── scripts/
│   ├── entrypoint.sh        # PORT-aware startup
│   └── run_tests.sh
├── Dockerfile
├── render.yaml
└── README.md
```

**Runtime:** OpenResty (Nginx + LuaJIT). Outbound HTTP uses `lua-resty-http`. DNS uses `resty.dns.resolver`. Rate limits use `ngx.shared` dict.

---

## API Documentation

Base path: `/api/v1`

All JSON responses include:

```json
{
  "success": true|false,
  "schema_version": "1.0",
  "data": { ... },
  "meta": {
    "service": "Urlix",
    "version": "1.0.0",
    "creator": "Blitz"
  }
}
```

Error responses:

```json
{
  "success": false,
  "schema_version": "1.0",
  "error": {
    "code": "URL_BLOCKED",
    "message": "Access to private or reserved IP addresses is blocked",
    "details": { ... }
  },
  "meta": { ... }
}
```

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/ping` | Liveness — returns `{ "status": "ok" }` |
| `GET` | `/health` or `/healthz` | Health check for monitors |
| `GET` | `/api` or `/api/v1` | Service & endpoint info |
| `GET` | `/api/v1/analyze?url=` | Analyze a URL |
| `POST` | `/api/v1/analyze` | Analyze a URL (JSON body) |

### Analyze — query parameters / body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `url` | string | yes | Target URL (`http` or `https`) |

Aliases: query `u`, JSON `target`.

### Example success response (abbreviated)

```json
{
  "success": true,
  "schema_version": "1.0",
  "data": {
    "input_url": "https://example.com",
    "parsed": {
      "scheme": "https",
      "hostname": "example.com",
      "port": 443,
      "path": "/",
      "query": null,
      "query_params": {},
      "fragment": null
    },
    "final_url": "https://example.com/",
    "status_code": 200,
    "content_type": "text/html; charset=UTF-8",
    "title": "Example Domain",
    "description": null,
    "canonical_url": null,
    "headers": { "server": "...", "content-type": "..." },
    "security_headers": { ... },
    "redirect_chain": [
      {
        "url": "https://example.com",
        "status": 200,
        "timing_seconds": 0.12,
        "hop": 0
      }
    ],
    "hops": 1,
    "timing": { "total_seconds": 0.12 },
    "body_size_bytes": 1256,
    "issues": []
  },
  "meta": {
    "service": "Urlix",
    "version": "1.0.0",
    "creator": "Blitz"
  }
}
```

### Common error codes

| Code | HTTP | Meaning |
|------|------|---------|
| `MISSING_URL` | 400 | No `url` provided |
| `INVALID_URL` | 400 | Malformed URL |
| `URL_BLOCKED` | 400 | SSRF / private / blocked target |
| `RATE_LIMITED` | 429 | Too many requests from IP |
| `TOO_MANY_REDIRECTS` | 422 | Redirect limit exceeded |
| `FETCH_FAILED` | 502 | Network / upstream failure |
| `METHOD_NOT_ALLOWED` | 405 | Unsupported HTTP method |
| `NOT_FOUND` | 404 | Unknown API path |

---

## Request examples

### cURL

```bash
# Simple GET
curl -sS "https://your-urlix.onrender.com/api/v1/analyze?url=https://example.com" | jq

# POST JSON
curl -sS -X POST "https://your-urlix.onrender.com/api/v1/analyze" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://httpbin.org/redirect/2"}' | jq

# Health
curl -sS "https://your-urlix.onrender.com/health"
curl -sS "https://your-urlix.onrender.com/ping"
```

### Lua (lua-resty-http)

```lua
local http = require "resty.http"
local cjson = require "cjson.safe"

local httpc = http.new()
local res, err = httpc:request_uri("https://your-urlix.onrender.com/api/v1/analyze", {
  method = "GET",
  query = { url = "https://example.com" },
  headers = { Accept = "application/json" },
})
if not res then
  ngx.log(ngx.ERR, err)
  return
end
local body = cjson.decode(res.body)
print(body.data.status_code)
```

### JavaScript (fetch)

```javascript
const res = await fetch(
  "/api/v1/analyze?url=" + encodeURIComponent("https://example.com")
);
const data = await res.json();
if (data.success) {
  console.log(data.data.final_url, data.data.status_code);
}
```

---

## Installation & local development

### Prerequisites

- Docker (recommended), **or**
- OpenResty with `lua-resty-http` and LuaJIT
- Lua 5.1+ / LuaJIT for offline unit tests

### Clone

```bash
git clone https://github.com/blitzlabx/urlix.git
cd urlix
```

### Run with Docker (recommended)

```bash
docker build -t urlix .
docker run --rm -p 8080:8080 -e PORT=8080 urlix
```

Open http://localhost:8080

### Run tests (offline)

```bash
chmod +x scripts/run_tests.sh
./scripts/run_tests.sh
```

Requires a system `lua` interpreter (Lua 5.1+ or LuaJIT compatible).

---

## Docker usage

```bash
# Build
docker build -t urlix:1.0.0 .

# Run
docker run --rm -p 8080:8080 \
  -e PORT=8080 \
  --name urlix \
  urlix:1.0.0

# Health
curl http://localhost:8080/health
```

The entrypoint substitutes `PORT` into the Nginx listen directive so the same image works on Render and locally.

---

## Render deployment

1. Push the repository to GitHub (e.g. `blitzlabx/urlix`).
2. In Render: **New → Blueprint** and connect the repo, **or** create a **Web Service** with:
   - Runtime: **Docker**
   - Dockerfile path: `./Dockerfile`
   - Health check path: `/health`
3. Render sets `PORT` automatically; the entrypoint binds to it.
4. Optional: use the included `render.yaml` for Infrastructure-as-Code.

After deploy, verify:

```bash
curl https://<your-service>.onrender.com/ping
curl "https://<your-service>.onrender.com/api/v1/analyze?url=https://example.com"
```

---

## Configuration

Primary settings live in `lua/config.lua`:

| Key | Default | Description |
|-----|---------|-------------|
| `fetch.timeout_connect` | 5s | Connect timeout |
| `fetch.timeout_send` | 5s | Send timeout |
| `fetch.timeout_read` | 10s | Read timeout |
| `fetch.max_redirects` | 10 | Max redirect hops |
| `fetch.max_response_size` | 512 KiB | Max body size |
| `fetch.max_url_length` | 2048 | Max input URL length |
| `rate_limit.window_seconds` | 60 | Rate limit window |
| `rate_limit.max_requests` | 30 | Max requests per IP per window |
| `security.block_private_ips` | true | Block RFC1918 / reserved |
| `security.resolve_and_check` | true | DNS + re-validate IPs |

`PORT` is read from the environment (Render injects it).

---

## Rate limits

- Default: **30 requests per 60 seconds per client IP**
- Enforced via `ngx.shared` dictionary (per OpenResty worker group)
- Exceeded requests receive **HTTP 429** with `Retry-After` and `X-RateLimit-*` headers
- For multi-instance horizontal scaling, replace the in-memory limiter with Redis or an edge rate limiter

---

## Security & SSRF protection

Urlix is intentionally conservative:

1. **Scheme allowlist** — only `http` and `https`
2. **Hostname blocklist** — `localhost` and similar
3. **Literal IP checks** — private, loopback, link-local, multicast, reserved, and known metadata addresses are rejected before any connection
4. **DNS resolution** — hostnames are resolved; if any address is private/reserved/metadata, the request is rejected (mitigates basic DNS rebinding)
5. **Per-hop validation** — every redirect target is re-checked
6. **Timeouts & size limits** — reduce resource exhaustion risk
7. **No authentication** — suitable for public read-only analysis; do not expose as an open proxy for arbitrary internal traffic

**Important:** This is not a guarantee against every sophisticated SSRF or DNS-rebinding attack. For high-risk environments, place Urlix behind additional network policy, egress filtering, and monitoring.

---

## Troubleshooting

| Symptom | Things to check |
|---------|------------------|
| Container exits immediately | Logs; ensure `entrypoint.sh` is executable; `PORT` valid |
| `listen` / bind errors | Confirm `PORT` and that nothing else binds the same port |
| DNS / resolve failures | Container must reach `8.8.8.8` / `1.1.1.1` (or change resolver in `nginx.conf`) |
| Rate limited unexpectedly | Shared dict size; multiple workers; client IP via `X-Forwarded-For` |
| TLS errors to targets | CA certificates present in image (`ca-certificates` is installed) |
| 502 on analyze | Target unreachable, timeout, or TLS problem — inspect `error` in JSON |

View logs:

```bash
docker logs urlix
# or on Render: service logs
```

---

## Limitations

- In-memory rate limiting is per instance / worker group (not global across many replicas)
- HTML metadata extraction is heuristic (regex), not a full DOM parser
- Response body is truncated by size limit; large pages are not fully stored
- IPv6 private detection is pattern-based and may not cover every special range
- No authentication, quotas per user, or persistent history
- Does not execute JavaScript or render pages

---

## Contributing

Contributions that improve safety, correctness, or clarity are welcome.

1. Fork the repository
2. Create a feature branch
3. Add or update tests under `tests/`
4. Ensure `./scripts/run_tests.sh` passes
5. Open a pull request against the main branch

Please keep the public API stable unless versioning is explicitly bumped.

---

## Credits

**Urlix** is created by **Blitz** ([blitzlabx](https://github.com/blitzlabx)).

All project credit belongs to Blitz.

Built with:

- [OpenResty](https://openresty.org/)
- [LuaJIT](https://luajit.org/)
- [lua-resty-http](https://github.com/ledgetech/lua-resty-http)

---

## License

MIT License — see [LICENSE](LICENSE) for details.

Copyright (c) Blitz (blitzlabx)
