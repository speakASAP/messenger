#!/bin/bash

# Helper script to detect current user's UID/GID for container configuration
# This ensures containers run with the same user as the host system

set -e

echo "Detecting current user's UID and GID..."
echo ""

CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)
CURRENT_USER=$(whoami)

echo "Current user: $CURRENT_USER"
echo "UID: $CURRENT_UID"
echo "GID: $CURRENT_GID"
echo ""

if [ "$CURRENT_UID" = "0" ] || [ "$CURRENT_GID" = "0" ]; then
    echo "WARNING: You are running as root (UID/GID 0)."
    echo "Containers cannot run as root for security reasons."
    echo "Please run this script as a non-root user."
    exit 1
fi

echo "Add these lines to your .env file:"
echo ""
echo "CONTAINER_USER_UID=$CURRENT_UID"
echo "CONTAINER_USER_GID=$CURRENT_GID"
echo ""
echo "This ensures all containers run with the same user as your host system."

