#!/bin/bash

# Install Matrix LiveKit integration in Synapse
# This script helps install the LiveKit integration module

set -e

echo "Installing Matrix LiveKit integration..."

# Check if synapse container is running
if ! docker ps | grep -q matrix-synapse; then
    echo "Error: Synapse container is not running. Please start it first with: docker-compose up -d synapse"
    exit 1
fi

# Install the integration
echo "Installing livekit integration module..."
docker exec -it matrix-synapse pip install matrix-livekit-integration

echo ""
echo "LiveKit integration installed successfully!"
echo ""
echo "Next steps:"
echo "1. Configure the integration in Synapse config"
echo "2. Set LIVEKIT_URL, LIVEKIT_API_KEY, and LIVEKIT_API_SECRET in your .env file"
echo "3. Restart Synapse: docker-compose restart synapse"
echo ""
echo "For more information, see: https://github.com/livekit/matrix-livekit-integration"

