#!/bin/bash

# Setup script - ensures .env exists and sets CURRENT_UID/GID from current user
# Also processes config templates using envsubst

set -e

if [ ! -f .env ]; then
    echo "Error: .env file not found. Please create it from .env.example first."
    exit 1
fi

# Detect current user's UID and GID (avoid readonly UID variable)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Validate that we're not root
if [ "$CURRENT_UID" = "0" ] || [ "$CURRENT_GID" = "0" ]; then
    echo "ERROR: Cannot run as root user (UID/GID 0)."
    echo "Please run this script as a non-root user."
    exit 1
fi

# Add or update CURRENT_UID and CURRENT_GID in .env
if grep -q "^CURRENT_UID=" .env; then
    sed -i.bak "s/^CURRENT_UID=.*/CURRENT_UID=${CURRENT_UID}/" .env
else
    echo "CURRENT_UID=${CURRENT_UID}" >> .env
fi

if grep -q "^CURRENT_GID=" .env; then
    sed -i.bak "s/^CURRENT_GID=.*/CURRENT_GID=${CURRENT_GID}/" .env
else
    echo "CURRENT_GID=${CURRENT_GID}" >> .env
fi

# Clean up backup file if created
rm -f .env.bak

echo "✅ .env updated with current user UID/GID (${CURRENT_UID}:${CURRENT_GID})"

# Source .env file to make variables available for envsubst
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
echo "✅ Containers will run as non-root user (${CURRENT_UID}:${CURRENT_GID})"
echo "✅ No hardcoded UIDs - portable across servers and OS"
