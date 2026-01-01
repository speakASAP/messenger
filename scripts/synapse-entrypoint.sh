#!/bin/sh
# Entrypoint script for Synapse to run as non-root user
# Fixes ownership and switches to statex user (1001:1001)

set -e

# Fix ownership of /data directory to statex user (1001:1001)
if [ -d /data ]; then
    chown -R 1001:1001 /data 2>/dev/null || true
    chmod -R 755 /data 2>/dev/null || true
fi

# Create user if it doesn't exist
if ! id -u 1001 >/dev/null 2>&1; then
    groupadd -g 1001 statex 2>/dev/null || true
    useradd -u 1001 -g 1001 -m -s /bin/sh statex 2>/dev/null || true
fi

# Switch to non-root user and run Synapse
exec su -s /bin/sh -c "/start.py $*" 1001

