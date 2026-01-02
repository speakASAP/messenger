#!/bin/bash

# Fix Matrix RTC Focus configuration
# This script verifies and fixes the MISSING_MATRIX_RTC_FOCUS error

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

SERVICE_NAME="${SERVICE_NAME:-messenger}"

echo "🔧 Fixing Matrix RTC Focus configuration..."
echo ""

# Check if required environment variables are set
echo "Checking environment variables..."
MISSING_VARS=()

if [ -z "$LIVEKIT_URL" ]; then
    MISSING_VARS+=("LIVEKIT_URL")
fi

if [ -z "$LIVEKIT_API_KEY" ]; then
    MISSING_VARS+=("LIVEKIT_API_KEY")
fi

if [ -z "$LIVEKIT_API_SECRET" ]; then
    MISSING_VARS+=("LIVEKIT_API_SECRET")
fi

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ Missing required environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "   - $var"
    done
    echo ""
    echo "Please set these in your .env file and run this script again."
    exit 1
fi

echo "✅ All required environment variables are set"
echo ""

# Find running Synapse container
SYNAPSE_CONTAINER=$(docker ps --filter "name=${SERVICE_NAME}-synapse" --format "{{.Names}}" | head -1)

if [ -z "$SYNAPSE_CONTAINER" ]; then
    echo "⚠️  Synapse container is not running."
    echo "   This script will prepare the configuration, but you'll need to start Synapse to apply it."
    echo ""
else
    echo "Found Synapse container: $SYNAPSE_CONTAINER"
    echo ""
fi

# Step 1: Install matrix-livekit-integration if not installed
if [ -n "$SYNAPSE_CONTAINER" ]; then
    echo "Step 1: Checking matrix-livekit-integration installation..."
    if docker exec "$SYNAPSE_CONTAINER" pip show matrix-livekit-integration > /dev/null 2>&1; then
        echo "✅ matrix-livekit-integration is already installed"
    else
        echo "📦 Installing matrix-livekit-integration..."
        docker exec "$SYNAPSE_CONTAINER" pip install matrix-livekit-integration
        echo "✅ matrix-livekit-integration installed"
    fi
    echo ""
fi

# Step 2: Regenerate homeserver.yaml with RTC configuration
echo "Step 2: Regenerating Synapse configuration with RTC focus..."
cd "$PROJECT_ROOT"
./scripts/setup-config.sh
echo "✅ Configuration regenerated"
echo ""

# Step 3: Verify homeserver.yaml contains matrix_rtc_focus
echo "Step 3: Verifying configuration..."
if [ -f "$PROJECT_ROOT/synapse/data/homeserver.yaml" ]; then
    if grep -q "matrix_rtc_focus:" "$PROJECT_ROOT/synapse/data/homeserver.yaml"; then
        echo "✅ matrix_rtc_focus configuration found in homeserver.yaml"
        
        # Check if values are properly substituted
        if grep -q "\${LIVEKIT" "$PROJECT_ROOT/synapse/data/homeserver.yaml"; then
            echo "⚠️  Warning: Some environment variables were not substituted!"
            echo "   This might indicate missing variables in .env"
        else
            echo "✅ All environment variables properly substituted"
        fi
    else
        echo "❌ matrix_rtc_focus configuration NOT found in homeserver.yaml"
        echo "   Please check synapse/config/homeserver.yaml.template"
        exit 1
    fi
else
    echo "⚠️  homeserver.yaml not found. It will be created when Synapse starts."
fi
echo ""

# Step 4: Restart Synapse if running
if [ -n "$SYNAPSE_CONTAINER" ]; then
    echo "Step 4: Restarting Synapse to apply configuration..."
    docker restart "$SYNAPSE_CONTAINER"
    echo "✅ Synapse restarted"
    echo ""
    
    echo "Waiting for Synapse to start..."
    sleep 5
    
    # Check if Synapse is healthy
    if docker exec "$SYNAPSE_CONTAINER" curl -f http://localhost:${SYNAPSE_PORT:-3708}/health > /dev/null 2>&1; then
        echo "✅ Synapse is healthy"
    else
        echo "⚠️  Synapse health check failed. Check logs:"
        echo "   docker logs $SYNAPSE_CONTAINER"
    fi
fi

echo ""
echo "✅ Matrix RTC Focus configuration fix completed!"
echo ""
echo "Next steps:"
echo "1. Test a call in Element to verify the fix"
echo "2. Check Synapse logs if issues persist:"
echo "   docker logs $SYNAPSE_CONTAINER | grep -i rtc"
echo ""

