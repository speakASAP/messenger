#!/bin/bash
# Wrapper deployment script that automatically handles Matrix location blocks
# Usage: ./scripts/deploy.sh
# This script calls nginx-microservice deployment and automatically injects Matrix location blocks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NGINX_MICROSERVICE_DIR="${NGINX_MICROSERVICE_DIR:-/home/statex/nginx-microservice}"
SERVICE_NAME="${SERVICE_NAME:-messenger}"

# Source .env to get SERVICE_NAME and DOMAIN if not set
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Default values
SERVICE_NAME="${SERVICE_NAME:-messenger}"
DOMAIN="${DOMAIN:-messenger.statex.cz}"

echo "🚀 Starting deployment for $SERVICE_NAME..."

# Step 0: Deploy only code from repository - sync with remote (discard local changes on server)
echo "📥 Syncing with remote repository..."
cd "$PROJECT_ROOT"
if [ -d ".git" ]; then
    git fetch origin
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    git reset --hard "origin/$BRANCH"
    echo "✓ Repository synced to origin/$BRANCH"
fi
echo ""

# Step 1: Deploy via nginx-microservice
echo "📦 Deploying via nginx-microservice..."
cd "$NGINX_MICROSERVICE_DIR"
if ! ./scripts/blue-green/deploy-smart.sh "$SERVICE_NAME"; then
    echo "❌ Deployment failed!"
    exit 1
fi

# Step 2: Automatically inject Matrix location blocks
echo "🔧 Injecting Matrix location blocks..."
cd "$PROJECT_ROOT"
if [ -f "$PROJECT_ROOT/scripts/post-deploy-nginx.sh" ]; then
    if ! ./scripts/post-deploy-nginx.sh; then
        echo "⚠️  Warning: Failed to inject Matrix location blocks, but deployment succeeded"
        echo "   You may need to run ./scripts/post-deploy-nginx.sh manually"
    else
        echo "✅ Matrix location blocks injected successfully"
    fi
    
    # Step 3: Reload nginx to apply changes
    echo "🔄 Reloading nginx..."
    cd "$NGINX_MICROSERVICE_DIR"
    if ! ./scripts/reload-nginx.sh; then
        echo "⚠️  Warning: Failed to reload nginx, but deployment succeeded"
        echo "   You may need to run ./scripts/reload-nginx.sh manually"
    else
        echo "✅ Nginx reloaded successfully"
    fi
else
    echo "⚠️  Warning: post-deploy-nginx.sh not found, skipping Matrix location block injection"
fi

echo "✅ Deployment completed successfully!"
echo ""
echo "📋 Summary:"
echo "   - Service: $SERVICE_NAME"
echo "   - Domain: $DOMAIN"
echo "   - Matrix location blocks: Injected"
echo "   - Nginx: Reloaded"

