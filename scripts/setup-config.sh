#!/bin/bash

# Setup configuration files with values from .env
# This script replaces placeholders in config files with actual values from .env

set -e

if [ ! -f .env ]; then
    echo "Error: .env file not found. Please create it from .env.example first."
    exit 1
fi

# Source .env file
source .env

echo "Setting up configuration files..."

# Update synapse config
if [ -f synapse/config/homeserver.yaml ]; then
    echo "Updating Synapse configuration..."
    sed -i.bak "s|REPLACE_WITH_POSTGRES_PASSWORD|${POSTGRES_PASSWORD}|g" synapse/config/homeserver.yaml
    sed -i.bak "s|REPLACE_WITH_REDIS_PASSWORD|${REDIS_PASSWORD}|g" synapse/config/homeserver.yaml
    sed -i.bak "s|REPLACE_WITH_SYNAPSE_REGISTRATION_SECRET|${SYNAPSE_REGISTRATION_SECRET}|g" synapse/config/homeserver.yaml
    sed -i.bak "s|messenger.statex.cz|${DOMAIN}|g" synapse/config/homeserver.yaml
    sed -i.bak "s|\${SERVICE_NAME:-messenger}-postgres|${SERVICE_NAME:-messenger}-postgres|g" synapse/config/homeserver.yaml
    sed -i.bak "s|\${SERVICE_NAME:-messenger}-redis|${SERVICE_NAME:-messenger}-redis|g" synapse/config/homeserver.yaml
    rm -f synapse/config/homeserver.yaml.bak
fi

# Update element config
if [ -f element/config.json ]; then
    echo "Updating Element configuration..."
    sed -i.bak "s|messenger.statex.cz|${DOMAIN}|g" element/config.json
    sed -i.bak "s|https://messenger.statex.cz|${LIVEKIT_URL}|g" element/config.json
    rm -f element/config.json.bak
fi

# Update livekit config
if [ -f livekit/config.yaml ]; then
    echo "Updating LiveKit configuration..."
    sed -i.bak "s|messenger.statex.cz|${LIVEKIT_URL#https://}|g" livekit/config.yaml
    sed -i.bak "s|port: 7880|port: ${LIVEKIT_HTTP_PORT:-7880}|g" livekit/config.yaml
    sed -i.bak "s|tcp_port: 7881|tcp_port: ${LIVEKIT_HTTPS_PORT:-7881}|g" livekit/config.yaml
    sed -i.bak "s|port_range_start: 50000|port_range_start: ${LIVEKIT_RTC_PORT_START:-50000}|g" livekit/config.yaml
    sed -i.bak "s|port_range_end: 60000|port_range_end: ${LIVEKIT_RTC_PORT_END:-60000}|g" livekit/config.yaml
    sed -i.bak "s|tls_port: 7882|tls_port: ${LIVEKIT_TURN_PORT:-7882}|g" livekit/config.yaml
    sed -i.bak "s|udp_port: 7882|udp_port: ${LIVEKIT_TURN_PORT:-7882}|g" livekit/config.yaml
    rm -f livekit/config.yaml.bak
    echo "  NOTE: You need to manually update LIVEKIT_API_KEY and LIVEKIT_API_SECRET in livekit/config.yaml"
fi

echo ""
echo "Configuration files updated successfully!"
echo ""
echo "IMPORTANT: Review and update the following manually:"
echo "  - livekit/config.yaml: Update API_KEY and API_SECRET with your LiveKit credentials"
echo "  - synapse/config/homeserver.yaml: Verify all settings are correct"

