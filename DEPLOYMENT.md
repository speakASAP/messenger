# Deployment Guide for nginx-microservice Integration

This service is designed to be deployed via the nginx-microservice blue/green deployment system.

## Prerequisites

1. nginx-microservice must be running and accessible
2. Service must be placed in `/home/statex/messenger` (or path specified in service registry)
3. All environment variables must be configured in `.env` file

## Deployment Steps

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
- `DOMAIN=messenger.statex.cz`
- `SERVICE_NAME=messenger`
- `PRODUCTION_PATH=/home/statex/messenger`
- All passwords and secrets
- All port configurations

### 3. Run Setup Script

```bash
# Update configuration files with .env values
./scripts/setup-config.sh
```

**Important**: After running setup-config.sh, manually update `livekit/config.yaml` with your LiveKit API keys:
- Replace `API_KEY` with your `LIVEKIT_API_KEY` from .env
- Replace `API_SECRET` with your `LIVEKIT_API_SECRET` from .env

### 4. Deploy via nginx-microservice

```bash
cd /path/to/nginx-microservice
./scripts/blue-green/deploy-smart.sh messenger
```

The deployment script will:
- Auto-create service registry in `nginx-microservice/service-registry/messenger.json`
- Detect services from docker-compose.yml
- Build and start containers (blue/green)
- Configure nginx routing
- Handle SSL certificates automatically
- Perform health checks
- Switch traffic with zero downtime

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
    -a -u admin -p <password> http://localhost:8008
```

### 7. Install LiveKit Integration

```bash
./scripts/install-livekit-integration.sh
```

## Service Registry Structure

The service registry will be auto-created by deploy-smart.sh. Expected structure:

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
      "container_port": 8008,
      "health_endpoint": "/health",
      "health_timeout": 10,
      "health_retries": 2,
      "startup_time": 30
    },
    "element": {
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
      "services": ["synapse", "element", "livekit"]
    }
  },
  "shared_services": ["postgres", "redis"],
  "network": "nginx-network"
}
```

**Note**: The service registry is automatically created and managed by deploy-smart.sh. Do not create it manually.

## Port Configuration

All ports are configured via `.env` file:

- `POSTGRES_PORT=5432` - PostgreSQL port
- `REDIS_PORT=6379` - Redis port
- `SYNAPSE_PORT=8008` - Synapse Matrix server port
- `ELEMENT_PORT=80` - Element web client port
- `LIVEKIT_HTTP_PORT=7880` - LiveKit HTTP API port
- `LIVEKIT_HTTPS_PORT=7881` - LiveKit HTTPS API port
- `LIVEKIT_TURN_PORT=7882` - LiveKit TURN/STUN port
- `LIVEKIT_RTC_PORT_START=50000` - LiveKit RTC port range start
- `LIVEKIT_RTC_PORT_END=60000` - LiveKit RTC port range end

## Network Configuration

- All services use `nginx-network` (external network managed by nginx-microservice)
- Services are accessible via container names from nginx-microservice
- No host port mappings needed (nginx-microservice handles routing)

## Troubleshooting

### Service Not Accessible

1. Check if service is deployed:
   ```bash
   cd /path/to/nginx-microservice
   ./scripts/status-all-services.sh | grep messenger
   ```

2. Check container status:
   ```bash
   docker ps | grep messenger
   ```

3. Check nginx configuration:
   ```bash
   cd /path/to/nginx-microservice
   ls -la nginx/conf.d/ | grep messenger
   ```

### Health Check Failures

1. Check service logs:
   ```bash
   docker logs messenger-synapse
   docker logs messenger-element
   docker logs messenger-livekit
   ```

2. Verify health endpoints:
   ```bash
   docker exec messenger-synapse curl -f http://localhost:8008/health
   docker exec messenger-element curl -f http://localhost:80/
   docker exec messenger-livekit curl -f http://localhost:7880/
   ```

### SSL Certificate Issues

SSL certificates are managed by nginx-microservice. Check:

```bash
cd /path/to/nginx-microservice
docker compose logs certbot
ls -la certificates/ | grep messenger
```

## Updates and Redeployment

To update the service:

```bash
cd /home/statex/messenger
# Update code
git pull

# Update .env if needed
nano .env

# Run setup script
./scripts/setup-config.sh

# Redeploy
cd /path/to/nginx-microservice
./scripts/blue-green/deploy-smart.sh messenger
```

The blue/green deployment system ensures zero-downtime updates.

