#!/bin/sh
# Entrypoint script for LiveKit to run as non-root user
# Fixes ownership and switches to statex user (1001:1001)

set -e

# Fix ownership if needed
if [ -f /etc/livekit.yaml ]; then
    chown 1001:1001 /etc/livekit.yaml 2>/dev/null || true
fi

# Switch to non-root user and run LiveKit
exec su-exec 1001:1001 /livekit-server "$@"

