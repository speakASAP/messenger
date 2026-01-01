#!/bin/sh
# Entrypoint script for Synapse to run as non-root user
# Fixes ownership and switches to statex user (1001:1001)

set -e

# Fix ownership of /data directory to statex user (1001:1001)
if [ -d /data ]; then
    chown -R 1001:1001 /data 2>/dev/null || true
    chmod -R 755 /data 2>/dev/null || true
fi

# Switch to non-root user and run Synapse
exec su-exec 1001:1001 /start.py "$@"

