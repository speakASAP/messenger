#!/bin/bash

# Setup configuration files using envsubst
# This script uses envsubst to substitute .env variables into template files
# Much simpler than sed replacements - just one command per file

set -e

if [ ! -f .env ]; then
    echo "Error: .env file not found. Please create it from .env.example first."
    exit 1
fi

# Source .env file to make variables available
set -a
source .env
set +a

echo "Setting up configuration files using envsubst..."

# Process Synapse config template
if [ -f synapse/config/homeserver.yaml.template ]; then
    echo "Processing Synapse configuration..."
    mkdir -p synapse/data
    envsubst < synapse/config/homeserver.yaml.template > synapse/data/homeserver.yaml
    echo "✅ Synapse config generated"
fi

# Process LiveKit config template
if [ -f livekit/config.yaml.template ]; then
    echo "Processing LiveKit configuration..."
    # Extract domain from LIVEKIT_URL for LIVEKIT_DOMAIN variable
    export LIVEKIT_DOMAIN="${LIVEKIT_URL#https://}"
    export LIVEKIT_DOMAIN="${LIVEKIT_DOMAIN#http://}"
    envsubst < livekit/config.yaml.template > livekit/config.yaml
    echo "✅ LiveKit config generated"
fi

# Process Element config template
if [ -f element/config.json.template ]; then
    echo "Processing Element configuration..."
    envsubst < element/config.json.template > element/config.json
    echo "✅ Element config generated"
fi

echo ""
echo "✅ All configuration files generated successfully!"
echo "No manual editing needed - all values come from .env"
