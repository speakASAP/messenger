#!/bin/bash

# Test LiveKit server connectivity
# This script tests if LiveKit server is accessible and working

set -e

LIVEKIT_URL=${LIVEKIT_URL:-https://livekit.example.com}
LIVEKIT_PORT=${LIVEKIT_PORT:-7882}

echo "Testing LiveKit server connectivity..."
echo "URL: $LIVEKIT_URL"
echo ""

# Test HTTPS endpoint
echo "1. Testing HTTPS endpoint..."
if curl -f -s "$LIVEKIT_URL" > /dev/null; then
    echo "   ✓ HTTPS endpoint is accessible"
else
    echo "   ✗ HTTPS endpoint is not accessible"
    exit 1
fi

# Test health endpoint
echo "2. Testing health endpoint..."
if curl -f -s "$LIVEKIT_URL/health" > /dev/null; then
    echo "   ✓ Health endpoint is accessible"
else
    echo "   ⚠ Health endpoint is not accessible (may not be implemented)"
fi

# Test UDP port (if nc is available)
if command -v nc &> /dev/null; then
    echo "3. Testing UDP port $LIVEKIT_PORT..."
    DOMAIN=$(echo $LIVEKIT_URL | sed 's|https\?://||' | sed 's|/.*||')
    if timeout 3 nc -u -v "$DOMAIN" "$LIVEKIT_PORT" 2>&1 | grep -q "succeeded"; then
        echo "   ✓ UDP port is accessible"
    else
        echo "   ⚠ UDP port test failed (may require external network access)"
    fi
else
    echo "3. Skipping UDP test (nc not available)"
fi

echo ""
echo "LiveKit server connectivity test completed!"

