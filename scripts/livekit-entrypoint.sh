#!/bin/sh
# Entrypoint script for LiveKit to run as non-root user
# Fixes ownership and switches to statex user (1001:1001)

set -e

# Fix ownership if needed
if [ -f /etc/livekit.yaml ]; then
    chown 1001:1001 /etc/livekit.yaml 2>/dev/null || true
fi

# Create user if it doesn't exist
if ! id -u 1001 >/dev/null 2>&1; then
    groupadd -g 1001 statex 2>/dev/null || true
    useradd -u 1001 -g 1001 -m -s /bin/sh statex 2>/dev/null || true
fi

# Switch to non-root user and run LiveKit
exec su -s /bin/sh -c "/livekit-server $*" 1001

