#!/bin/bash

# Generate secrets for Matrix deployment
# This script generates all required secrets and outputs them for .env file

echo "# Generated secrets for Matrix deployment"
echo "# Add these to your .env file"
echo ""
echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)"
echo "SYNAPSE_SECRET_KEY=$(openssl rand -base64 32)"
echo "SYNAPSE_REGISTRATION_SECRET=$(openssl rand -base64 32)"
echo "LIVEKIT_API_KEY=$(openssl rand -hex 16)"
echo "LIVEKIT_API_SECRET=$(openssl rand -base64 32)"
echo "REDIS_PASSWORD=$(openssl rand -base64 32)"
echo ""
echo "# Note: LiveKit API keys should be generated using LiveKit CLI:"
echo "# livekit-cli token create --api-key <key> --api-secret <secret> --join --room <room>"

