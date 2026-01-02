# Deployment Guide for Messenger Microservice

This microservice is integrated into the microservices infrastructure and is deployed via the nginx-microservice blue/green deployment system.

## Overview

The messenger microservice provides a complete Matrix messaging environment with:

- Synapse Matrix homeserver
- PostgreSQL database
- Redis cache
- LiveKit SFU for A/V calls
- Element X web client

**Key Integration Points:**

- Uses nginx-microservice for deployment, routing, and SSL termination
- All nginx configuration is managed in this codebase (`nginx/gateway-proxy.conf`)
- Matrix-specific location blocks are automatically injected during deployment
- Blue/green deployment strategy for zero-downtime updates

## Prerequisites

1. **nginx-microservice** must be running and accessible at `/home/statex/nginx-microservice`
2. Service must be placed in `/home/statex/messenger` (or path specified in service registry)
3. All environment variables must be configured in `.env` file
4. Access to production server via SSH (`ssh statex`)
5. Docker and Docker Compose installed
6. Domain name configured in DNS: `messenger.statex.cz`

## Deployment Steps

### 1. Prepare Service Directory

```bash
# Clone or copy service to production path
cd /home/statex
git clone <repository-url> messenger
cd messenger
```

### 2. Configure Environment

```bash
# Copy and edit .env file
cp .env.example .env
nano .env
```

**Required .env variables:**

- `DOMAIN=messenger.statex.cz` - Your Matrix domain
- `SERVICE_NAME=messenger` - Service name for container naming
- `PRODUCTION_PATH=/home/statex/messenger` - Production deployment path
- `CONTAINER_USER_UID` - User ID for all containers (MUST NOT be 0/root)
- `CONTAINER_USER_GID` - Group ID for all containers (MUST NOT be 0/root)
- All passwords and secrets (generate with `./scripts/generate-secrets.sh`)
- All port configurations
- Domain configuration (`ELEMENT_BASE_URL`, `LIVEKIT_URL`)

**See**: [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md) for complete list of all environment variables.

**IMPORTANT - Container User Configuration:**
All containers must run as a non-root user. For production deployment on `/home/statex/messenger`, set:

```bash
CONTAINER_USER_UID=$(id -u statex)
CONTAINER_USER_GID=$(id -g statex)
```

Or use the helper script:

```bash
./scripts/detect-user.sh
```

**Security Requirement:** Containers are strictly forbidden from running as root (UID/GID 0). The setup script validates this and will fail if root is detected.

### 3. Run Setup Script

```bash
# Update configuration files with .env values
./scripts/setup-config.sh
```

**Important**: After running setup-config.sh, manually update `livekit/config.yaml` with your LiveKit API keys:

- Replace `API_KEY` with your `LIVEKIT_API_KEY` from .env
- Replace `API_SECRET` with your `LIVEKIT_API_SECRET` from .env

### 4. Deploy via nginx-microservice

This microservice uses the nginx-microservice blue/green deployment system. The deployment process is fully automated via the wrapper script `scripts/deploy.sh`.

**Recommended: Use the wrapper script** (automatically handles all deployment steps):

```bash
cd /home/statex/messenger
./scripts/deploy.sh
```

**What the wrapper script does:**

1. **Pulls latest changes** from git repository
2. **Deploys via nginx-microservice** using `./scripts/blue-green/deploy-smart.sh messenger`
3. **Injects Matrix location blocks** automatically from `nginx/gateway-proxy.conf`
4. **Reloads nginx** to apply changes

**Alternative: Manual deployment** (if you need more control or troubleshooting):

```bash
# Step 1: Deploy via nginx-microservice
cd /home/statex/nginx-microservice
./scripts/blue-green/deploy-smart.sh messenger

# Step 2: Inject Matrix location blocks
cd /home/statex/messenger
./scripts/post-deploy-nginx.sh

# Step 3: Reload nginx
cd /home/statex/nginx-microservice
./scripts/reload-nginx.sh
```

**Deployment Process Details:**

The nginx-microservice deployment script (`deploy-smart.sh`) will:

- **Auto-create service registry** in `nginx-microservice/service-registry/messenger.json`
- **Detect services** from `docker-compose.blue.yml` and `docker-compose.green.yml`
- **Build and start containers** using blue/green strategy
- **Configure nginx routing** automatically
- **Handle SSL certificates** automatically via Let's Encrypt
- **Perform health checks** on all services
- **Switch traffic** with zero downtime

**Matrix Location Blocks Injection:**

The `scripts/post-deploy-nginx.sh` script automatically injects Matrix-specific location blocks from `nginx/gateway-proxy.conf` into the nginx gateway configs. This ensures:

- `/_matrix` - Matrix client API endpoints are routed to Synapse
- `/_synapse` - Synapse-specific endpoints are routed correctly
- `/.well-known/matrix/client` - Client discovery endpoint is served correctly

The `${ACTIVE_COLOR}` variable in `nginx/gateway-proxy.conf` is automatically substituted with the active deployment color (blue or green) during injection.

**Important**: All nginx configuration must be done in this codebase (`nginx/gateway-proxy.conf`), not directly on the production nginx server. The nginx-microservice regenerates configs on every deployment.

### 5. Initialize Synapse

After first deployment:

```bash
cd /home/statex/messenger
docker exec -it messenger-synapse python -m synapse.app.homeserver \
    --config-path /data/homeserver.yaml \
    --generate-config \
    --report-stats=no \
    --server-name="messenger.statex.cz"

docker exec -it messenger-synapse python -m synapse.app.homeserver \
    --config-path /data/homeserver.yaml \
    --generate-keys
```

### 6. Create First User

```bash
docker exec -it messenger-synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -a -u admin -p <password> http://localhost:3708
```

### 7. Install LiveKit Integration

```bash
./scripts/install-livekit-integration.sh
```

## Service Registry Structure

The service registry is automatically created by `deploy-smart.sh` in `nginx-microservice/service-registry/messenger.json`. Expected structure:

```json
{
  "service_name": "messenger",
  "production_path": "/home/statex/messenger",
  "domain": "messenger.statex.cz",
  "docker_compose_file": "docker-compose.green.yml",
  "docker_project_base": "messenger",
  "services": {
    "synapse": {
      "container_name_base": "messenger-synapse",
      "container_port": 3708,
      "health_endpoint": "/health",
      "health_timeout": 10,
      "health_retries": 2,
      "startup_time": 30
    },
    "frontend": {
      "container_name_base": "messenger-element",
      "container_port": 80,
      "health_endpoint": "/",
      "health_timeout": 10,
      "health_retries": 2,
      "startup_time": 10
    },
    "livekit": {
      "container_name_base": "messenger-livekit",
      "container_port": 7880,
      "health_endpoint": "/",
      "health_timeout": 10,
      "health_retries": 2,
      "startup_time": 20
    }
  },
  "domains": {
    "messenger.statex.cz": {
      "active_color": "green",
      "services": ["synapse", "frontend", "livekit"]
    }
  },
  "shared_services": ["postgres", "redis"],
  "network": "nginx-network"
}
```

**Note**: The service registry is automatically created and managed by `deploy-smart.sh`. Do not create or modify it manually. The registry tracks the active deployment color (blue or green) and service configuration.

## Port Configuration

All ports are configured via `.env` file:

- `POSTGRES_PORT=5432` - PostgreSQL port (internal, not exposed to host)
- `REDIS_PORT=6379` - Redis port (internal, not exposed to host)
- `SYNAPSE_PORT=3708` - Synapse Matrix server port (internal, not exposed to host)
- `ELEMENT_PORT=80` - Element web client port (internal, not exposed to host)
- `LIVEKIT_HTTP_PORT=7880` - LiveKit HTTP API port (internal, not exposed to host)
- `LIVEKIT_HTTPS_PORT=7881` - LiveKit HTTPS API port (internal, not exposed to host)
- `LIVEKIT_TURN_PORT=7882` - LiveKit TURN/STUN port (UDP/TCP, configured in nginx-microservice)
- `LIVEKIT_RTC_PORT_START=50000` - LiveKit RTC port range start (UDP, configured in nginx-microservice)
- `LIVEKIT_RTC_PORT_END=60000` - LiveKit RTC port range end (UDP, configured in nginx-microservice)

**Note**: For blue/green deployments, containers use different host ports (e.g., `13708:3708` for blue, `23708:3708` for green) but these are only for development/debugging. Production routing is handled by nginx-microservice via the `nginx-network`.

## Network Configuration

- All services use `nginx-network` (external network managed by nginx-microservice)
- Services are accessible via container names from nginx-microservice (e.g., `messenger-synapse-green`)
- No host port mappings needed for production (nginx-microservice handles routing)
- Blue/green deployments use different container name suffixes (`-blue` or `-green`)

## Troubleshooting

### Service Not Accessible

1. Check if service is deployed:

   ```bash
   cd /home/statex/nginx-microservice
   ./scripts/status-all-services.sh | grep messenger
   ```

2. Check container status (use active color - blue or green):

   ```bash
   docker ps | grep messenger
   # Check which color is active
   docker ps | grep messenger-synapse
   ```

3. Check nginx configuration:

   ```bash
   cd /home/statex/nginx-microservice
   ls -la nginx/conf.d/blue-green/ | grep messenger
   cat nginx/conf.d/blue-green/messenger.statex.cz.green.conf
   ```

4. Verify Matrix location blocks were injected:

   ```bash
   cd /home/statex/nginx-microservice
   grep -A 5 "_matrix" nginx/conf.d/blue-green/messenger.statex.cz.green.conf
   ```

### Health Check Failures

1. Check service logs (use active color):

   ```bash
   docker logs messenger-synapse-green -f
   docker logs messenger-element-green -f
   docker logs messenger-livekit-green -f
   ```

2. Verify health endpoints:

   ```bash
   docker exec messenger-synapse-green curl -f http://localhost:3708/health
   docker exec messenger-element-green curl -f http://localhost:80/
   docker exec messenger-livekit-green curl -f http://localhost:7880/
   ```

3. Check shared services:

   ```bash
   docker logs messenger-postgres
   docker logs messenger-redis
   ```

### SSL Certificate Issues

SSL certificates are managed by nginx-microservice. Check:

```bash
cd /home/statex/nginx-microservice
docker compose logs certbot
ls -la certificates/ | grep messenger
```

### Matrix Location Blocks Not Injected

If Matrix API endpoints are not working:

1. Check if `post-deploy-nginx.sh` ran successfully:

   ```bash
   cd /home/statex/messenger
   ./scripts/post-deploy-nginx.sh
   ```

2. Verify `nginx/gateway-proxy.conf` exists:

   ```bash
   ls -la nginx/gateway-proxy.conf
   cat nginx/gateway-proxy.conf
   ```

3. Check nginx configs for Matrix locations:

   ```bash
   cd /home/statex/nginx-microservice
   grep "_matrix" nginx/conf.d/blue-green/messenger.statex.cz.*.conf
   ```

4. Manually inject if needed:

   ```bash
   cd /home/statex/messenger
   ./scripts/post-deploy-nginx.sh
   cd /home/statex/nginx-microservice
   ./scripts/reload-nginx.sh
   ```

## Updates and Redeployment

To update the microservice:

```bash
# Connect to production server
ssh statex

# Navigate to service directory
cd /home/statex/messenger

# Update code from repository
git pull

# Update .env if needed
nano .env

# Run setup script if configuration files changed
./scripts/setup-config.sh

# Redeploy (automatically handles Matrix location blocks)
./scripts/deploy.sh
```

**What happens during update:**

1. Latest code is pulled from repository
2. nginx-microservice deploys new version using blue/green strategy
3. Matrix location blocks are automatically injected
4. Traffic is switched to new version with zero downtime
5. Old version containers are kept running (can be manually cleaned up)

**Rollback:**

If you need to rollback to previous version:

```bash
cd /home/statex/nginx-microservice
# Switch to previous color (blue if green is active, or vice versa)
./scripts/blue-green/switch-color.sh messenger
```

The blue/green deployment system ensures zero-downtime updates and easy rollback.
