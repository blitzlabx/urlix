#!/bin/sh
set -e

PORT="${PORT:-8080}"
CONF="/app/conf/nginx.conf"
RUNTIME_CONF="/tmp/nginx-urlix.conf"

# Substitute listen port for Render compatibility
sed "s/listen 8080;/listen ${PORT};/g" "$CONF" > "$RUNTIME_CONF"

echo "Urlix starting on port ${PORT} (Blitz / blitzlabx)"
exec /usr/local/openresty/bin/openresty -g "daemon off;" -c "$RUNTIME_CONF"
