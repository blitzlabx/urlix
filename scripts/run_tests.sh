#!/bin/sh
# Run offline unit tests for Urlix
# Creator: Blitz (blitzlabx)

set -e
cd "$(dirname "$0")/.."

echo "Running Urlix unit tests..."
lua tests/test_url_parser.lua
lua tests/test_ip.lua
lua tests/test_security_basic.lua
echo "All offline tests passed."
