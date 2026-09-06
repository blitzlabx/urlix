# Urlix - Production Dockerfile
# Creator: Blitz (blitzlabx)
# OpenResty + LuaJIT

FROM openresty/openresty:jammy

LABEL maintainer="Blitz <blitzlabx>"
LABEL org.opencontainers.image.title="Urlix"
LABEL org.opencontainers.image.description="Public URL Inspection & Analysis Service"
LABEL org.opencontainers.image.authors="Blitz (blitzlabx)"
LABEL org.opencontainers.image.version="1.0.0"

# CA certs required for outbound HTTPS verification (lua-resty-http)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Point OpenSSL / tools at the system CA bundle
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_DIR=/etc/ssl/certs
ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

WORKDIR /app

# Vendored: lua-resty-http + lua-resty-dns under lua/resty/
COPY conf/ /app/conf/
COPY lua/ /app/lua/
COPY static/ /app/static/
COPY scripts/entrypoint.sh /app/scripts/entrypoint.sh

RUN chmod +x /app/scripts/entrypoint.sh \
    && test -f /etc/ssl/certs/ca-certificates.crt

ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/health" || exit 1

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
