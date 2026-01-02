#!/bin/bash
# Standalone deployment script for messenger service
# This script deploys the service without nginx-microservice infrastructure
# Usage: ./scripts/deploy-standalone.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env if available
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

SERVICE_NAME="${SERVICE_NAME:-messenger}"
DOMAIN="${DOMAIN:-messenger.statex.cz}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@${DOMAIN}}"

echo "🚀 Starting standalone deployment for $SERVICE_NAME..."
echo "   Domain: $DOMAIN"
echo "   Email: $LETSENCRYPT_EMAIL"

cd "$PROJECT_ROOT"

# Step 1: Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker compose &> /dev/null && ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Step 2: Prepare nginx configuration
echo "🔧 Preparing nginx configuration..."

NGINX_CONF_TEMPLATE="$PROJECT_ROOT/nginx/standalone.conf.template"
NGINX_CONF="$PROJECT_ROOT/nginx/standalone.conf"

if [ ! -f "$NGINX_CONF_TEMPLATE" ]; then
    echo "❌ Nginx configuration template not found: $NGINX_CONF_TEMPLATE"
    exit 1
fi

# Replace variables in nginx config template to create final config
sed "s/\${DOMAIN}/$DOMAIN/g; s/\${SERVICE_NAME}/$SERVICE_NAME/g" "$NGINX_CONF_TEMPLATE" > "$NGINX_CONF"

# Check if sed worked
if [ ! -s "$NGINX_CONF" ]; then
    echo "❌ Failed to process nginx configuration"
    exit 1
fi

echo "✅ Nginx configuration prepared"

# Step 3: Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p "$PROJECT_ROOT/nginx/ssl"
mkdir -p "$PROJECT_ROOT/synapse/data"

# Step 4: Start services (without SSL first for Let's Encrypt)
echo "📦 Starting services (initial setup)..."
docker compose -f docker-compose.standalone.yml up -d postgres redis synapse element-web livekit

echo "⏳ Waiting for services to be ready..."
sleep 10

# Step 5: Get SSL certificate
echo "🔒 Obtaining SSL certificate..."

# Get project name for volume names
PROJECT_NAME=$(basename "$PROJECT_ROOT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="messenger"
fi

CERTBOT_VOLUME_CONF="${PROJECT_NAME}_certbot-conf"
CERTBOT_VOLUME_WWW="${PROJECT_NAME}_certbot-www"
NETWORK_NAME="${PROJECT_NAME}_messenger-network"

# Check if certificate already exists
if docker volume ls | grep -q "$CERTBOT_VOLUME_CONF"; then
    echo "ℹ️  SSL certificate volume exists, checking certificates..."
    if docker run --rm -v "$CERTBOT_VOLUME_CONF:/etc/letsencrypt:ro" certbot/certbot certificates 2>/dev/null | grep -q "$DOMAIN"; then
        echo "✅ SSL certificate found for $DOMAIN"
    else
        echo "📝 Requesting new SSL certificate..."
        # Start nginx temporarily for Let's Encrypt challenge
        docker compose -f docker-compose.standalone.yml up -d nginx
        sleep 5

        docker run --rm \
            -v "$CERTBOT_VOLUME_WWW:/var/www/certbot:rw" \
            -v "$CERTBOT_VOLUME_CONF:/etc/letsencrypt:rw" \
            --network "$NETWORK_NAME" \
            certbot/certbot certonly \
            --webroot \
            --webroot-path=/var/www/certbot \
            --email "$LETSENCRYPT_EMAIL" \
            --agree-tos \
            --no-eff-email \
            -d "$DOMAIN"
    fi
else
    echo "📝 Requesting new SSL certificate..."
    # Start nginx temporarily for Let's Encrypt challenge
    docker compose -f docker-compose.standalone.yml up -d nginx
    sleep 5

    docker run --rm \
        -v "$CERTBOT_VOLUME_WWW:/var/www/certbot:rw" \
        -v "$CERTBOT_VOLUME_CONF:/etc/letsencrypt:rw" \
        --network "$NETWORK_NAME" \
        certbot/certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$LETSENCRYPT_EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN"
fi

# Step 6: Start all services including nginx and certbot
echo "🚀 Starting all services..."
docker compose -f docker-compose.standalone.yml up -d

# Step 7: Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 15

# Step 8: Check service status
echo "📊 Service status:"
docker compose -f docker-compose.standalone.yml ps

echo ""
echo "✅ Standalone deployment completed successfully!"
echo ""
echo "📋 Summary:"
echo "   - Service: $SERVICE_NAME"
echo "   - Domain: $DOMAIN"
echo "   - SSL: Let's Encrypt (auto-renewal enabled)"
echo "   - Services: Running"
echo ""
echo "🌐 Access your service at: https://$DOMAIN"
echo ""
echo "📝 Next steps:"
echo "   1. Initialize Synapse: ./scripts/init-synapse.sh"
echo "   2. Create first user: docker exec -it ${SERVICE_NAME}-synapse register_new_matrix_user -c /data/homeserver.yaml -a -u admin -p <password> http://localhost:${SYNAPSE_PORT:-3708}"
echo "   3. Install LiveKit integration: ./scripts/install-livekit-integration.sh"

