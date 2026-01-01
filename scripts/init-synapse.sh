#!/bin/bash

# Initialize Synapse configuration
# This script helps generate the initial Synapse configuration

set -e

echo "Initializing Synapse configuration..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please create it from .env.example first."
    exit 1
fi

# Source .env file
source .env

# Check if synapse container is running
if ! docker ps | grep -q matrix-synapse; then
    echo "Starting Synapse container..."
    docker-compose up -d synapse
    sleep 5
fi

echo "Generating Synapse configuration..."
docker exec -it matrix-synapse python -m synapse.app.homeserver \
    --config-path /data/homeserver.yaml \
    --generate-config \
    --report-stats=no \
    --server-name="${DOMAIN}" || true

echo "Generating Synapse keys..."
docker exec -it matrix-synapse python -m synapse.app.homeserver \
    --config-path /data/homeserver.yaml \
    --generate-keys || true

echo ""
echo "Synapse initialization completed!"
echo ""
echo "Next steps:"
echo "1. Review synapse/config/homeserver.yaml"
echo "2. Update database configuration if needed"
echo "3. Restart Synapse: docker-compose restart synapse"
echo "4. Create first user: docker exec -it matrix-synapse register_new_matrix_user -c /data/homeserver.yaml -a -u admin -p <password> http://localhost:3708"

