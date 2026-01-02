#!/bin/bash

# Install Matrix LiveKit integration in Synapse
# This script helps install the LiveKit integration module and configure it

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env to get SERVICE_NAME
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

SERVICE_NAME="${SERVICE_NAME:-messenger}"

echo "Installing Matrix LiveKit integration..."

# Find running Synapse container (supports blue/green deployment)
SYNAPSE_CONTAINER=$(docker ps --filter "name=${SERVICE_NAME}-synapse" --format "{{.Names}}" | head -1)

if [ -z "$SYNAPSE_CONTAINER" ]; then
    echo "Error: Synapse container is not running. Please start it first."
    echo "For microservice deployment: ./scripts/deploy.sh"
    echo "For standalone deployment: docker compose -f docker-compose.standalone.yml up -d synapse"
    exit 1
fi

echo "Found Synapse container: $SYNAPSE_CONTAINER"

# Install the integration
echo "Installing matrix-livekit-integration module..."
docker exec "$SYNAPSE_CONTAINER" pip install matrix-livekit-integration

echo ""
echo "✅ LiveKit integration module installed successfully!"
echo ""
echo "⚠️  IMPORTANT: The homeserver.yaml must be configured with Matrix RTC focus."
echo "   Run ./scripts/setup-config.sh to regenerate config with RTC settings."
echo ""
echo "Next steps:"
echo "1. Ensure LIVEKIT_URL, LIVEKIT_API_KEY, and LIVEKIT_API_SECRET are set in .env"
echo "2. Run: ./scripts/setup-config.sh (to update homeserver.yaml with RTC config)"
echo "3. Restart Synapse: docker restart $SYNAPSE_CONTAINER"
echo ""
echo "For more information, see: https://github.com/livekit/matrix-livekit-integration"

