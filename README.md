# Messenger Service - Matrix Self-Hosted Deployment

Complete self-hosted Matrix messaging service with Synapse homeserver, PostgreSQL database, Element X clients, and LiveKit SFU with built-in TURN server for A/V calls.

## Overview

This service can be deployed in two modes:

### 1. Microservice Mode (Recommended for Infrastructure Integration)

- Integrated with nginx-microservice infrastructure
- Blue/green deployment for zero-downtime updates
- Automatic Matrix location block injection
- All configuration managed in codebase
- **Use when**: You have the microservices infrastructure

### 2. Standalone Mode (Recommended for Simple Deployments)

- Self-contained deployment with built-in nginx
- Automatic Let's Encrypt SSL certificate management
- No external dependencies
- Direct docker-compose deployment
- **Use when**: You want a simple, standalone installation

**Key Features:**

- Synapse Matrix homeserver
- PostgreSQL database
- Redis cache
- LiveKit SFU for A/V calls
- Element X web client
- Automatic SSL certificate management
- Non-root container execution

## Architecture

- **Synapse** - Matrix homeserver handling messaging, federation, and room management
- **PostgreSQL** - Database for Synapse (optimized for production)
- **Redis** - Caching and worker coordination
- **LiveKit** - Modern SFU (Selective Forwarding Unit) with built-in TURN server for A/V calls
- **Element X Web** - Modern web-based client
- **nginx-microservice** - External reverse proxy with SSL termination and blue/green deployment (handled by nginx-microservice infrastructure)

## Prerequisites

**Common requirements:**

- Docker and Docker Compose installed
- Domain name configured in DNS pointing to your server IP
- Server with at least 2-4GB RAM (low-resource optimized)
- Ports open: `80`, `443` (TCP), `7882` (UDP), `50000-60000` (UDP)

**For Microservice Mode:**

- nginx-microservice running and accessible at `/home/statex/nginx-microservice`
- Service placed in `/home/statex/messenger` (or path specified in service registry)
- Access to production server via SSH (`ssh statex`)

**For Standalone Mode:**

- Root or sudo access (for initial setup)
- No external dependencies required

## Deployment Modes

### Microservice Mode

This mode integrates with the microservices infrastructure:

- **Deployment**: Uses nginx-microservice blue/green deployment system via `scripts/deploy.sh`
- **Configuration**: All nginx configuration is managed in this codebase (`nginx/gateway-proxy.conf`)
- **Matrix Location Blocks**: Automatically injected into nginx configs during deployment
- **Service Registry**: Auto-created by nginx-microservice deployment script
- **Network**: Uses `nginx-network` external network managed by nginx-microservice
- **SSL**: Handled automatically by nginx-microservice with Let's Encrypt

**See**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed microservice deployment guide.

### Standalone Mode

This mode provides a self-contained deployment:

- **Deployment**: Direct docker-compose deployment via `scripts/deploy-standalone.sh`
- **Nginx**: Built-in nginx reverse proxy with SSL termination
- **SSL**: Automatic Let's Encrypt certificate management via certbot container
- **Network**: Internal Docker network (`messenger-network`)
- **Configuration**: All services in `docker-compose.standalone.yml`

**See**: [docs/STANDALONE_DEPLOYMENT.md](docs/STANDALONE_DEPLOYMENT.md) for detailed standalone deployment guide.

## Quick Start

### 1. Clone and Setup

```bash
git clone <repository-url>
cd matrix-deployment
```

### 2. Generate Secrets

```bash
./scripts/generate-secrets.sh > .env.tmp
# Review and add to .env file
```

### 3. Configure Environment

Copy `.env.example` to `.env` and fill in all required values:

```bash
cp .env.example .env
nano .env
```

**Generate secrets:**

```bash
./scripts/generate-secrets.sh > .env.tmp
# Review and add secrets to .env
```

**Required variables:**

- `DOMAIN` - Your Matrix domain (e.g., `messenger.example.com`)
- `ELEMENT_BASE_URL` - Element web URL (usually same as `DOMAIN`)
- `LIVEKIT_URL` - LiveKit server URL (usually same as `DOMAIN`)
- `POSTGRES_PASSWORD` - Strong database password (generate with `openssl rand -base64 32`)
- `SYNAPSE_SECRET_KEY` - Generated secret key (generate with `openssl rand -base64 32`)
- `SYNAPSE_REGISTRATION_SECRET` - Registration secret (generate with `openssl rand -base64 32`)
- `LIVEKIT_API_KEY` - LiveKit API key (generate with `openssl rand -hex 16`)
- `LIVEKIT_API_SECRET` - LiveKit API secret (generate with `openssl rand -base64 32`)
- `REDIS_PASSWORD` - Redis password (generate with `openssl rand -base64 32`)
- `CONTAINER_USER_UID` - User ID for all containers (MUST NOT be 0/root, detect with `./scripts/detect-user.sh`)
- `CONTAINER_USER_GID` - Group ID for all containers (MUST NOT be 0/root, detect with `./scripts/detect-user.sh`)
- `LETSENCRYPT_EMAIL` - Email for Let's Encrypt notifications (required for standalone deployment)

**See**: [docs/ENVIRONMENT_VARIABLES.md](docs/ENVIRONMENT_VARIABLES.md) for complete environment variables reference.

**IMPORTANT - Container User Configuration:**
All containers run as a non-root user for security. You must configure `CONTAINER_USER_UID` and `CONTAINER_USER_GID` in your `.env` file to match your host user's UID/GID.

To detect your user's UID/GID automatically:

```bash
./scripts/detect-user.sh
```

This will output the values to add to your `.env` file. Alternatively, run `id` to see your UID/GID manually.

**Security Requirement:** Containers are strictly forbidden from running as root (UID/GID 0). The setup script will validate this and fail if root is detected.

### 4. Configure DNS

Set up DNS A record pointing to your server IP:

- `messenger.statex.cz` → Your server IP

**Note**: SSL certificates and reverse proxy are handled by nginx-microservice. No need to configure nginx or certbot in this service.

### 5. Update Configuration Files

Run the setup script to automatically update configuration files with values from `.env`:

```bash
./scripts/setup-config.sh
```

This will update:

- `synapse/config/homeserver.yaml` - Database passwords, Redis password, registration secret, domain names
- `element/config.json` - Domain names
- `livekit/config.yaml` - Domain name
- `nginx/conf.d/*.conf` - Domain names

**IMPORTANT**: After running the script, manually update `livekit/config.yaml` with your LiveKit API keys:

- Replace `API_KEY` with your `LIVEKIT_API_KEY` from `.env`
- Replace `API_SECRET` with your `LIVEKIT_API_SECRET` from `.env`

### 6. Deploy

Choose your deployment mode:

#### Option A: Microservice Deployment (with nginx-microservice infrastructure)

This microservice is deployed using the nginx-microservice blue/green deployment system. The deployment process is automated via the wrapper script `scripts/deploy.sh`.

**Deployment Process:**

1. **Pull latest changes** from repository
2. **Deploy via nginx-microservice** using blue/green deployment
3. **Inject Matrix location blocks** automatically from `nginx/gateway-proxy.conf`
4. **Reload nginx** to apply changes

**Recommended: Use the wrapper script** (automatically handles all steps):

```bash
cd /home/statex/messenger
./scripts/deploy.sh
```

The wrapper script (`scripts/deploy.sh`) will:

- Pull latest changes from git repository
- Deploy via nginx-microservice (`./scripts/blue-green/deploy-smart.sh messenger`)
- Automatically inject Matrix location blocks from `nginx/gateway-proxy.conf`
- Reload nginx to apply changes

**Alternative: Manual deployment** (if you need more control):

```bash
cd /home/statex/nginx-microservice
./scripts/blue-green/deploy-smart.sh messenger
cd /home/statex/messenger
./scripts/post-deploy-nginx.sh
cd /home/statex/nginx-microservice
./scripts/reload-nginx.sh
```

**What the deployment does:**

- Auto-creates service registry in `nginx-microservice/service-registry/messenger.json`
- Detects services from `docker-compose.blue.yml` and `docker-compose.green.yml`
- Builds and starts containers (blue/green strategy)
- Configures nginx routing automatically
- Injects Matrix-specific location blocks (`/_matrix`, `/_synapse`, `/.well-known/matrix/client`)
- Handles SSL certificates automatically via Let's Encrypt
- Performs health checks
- Switches traffic with zero downtime

**Matrix Location Blocks:**
The file `nginx/gateway-proxy.conf` contains Matrix-specific nginx location blocks that are automatically injected into the nginx gateway configs during deployment. This ensures Matrix API requests are properly routed to Synapse. The `${ACTIVE_COLOR}` variable is automatically substituted with the active deployment color (blue or green).

#### Option B: Standalone Deployment (without microservices infrastructure)

For standalone deployment without nginx-microservice:

```bash
cd /path/to/messenger
./scripts/deploy-standalone.sh
```

This will:

- Start all services including built-in nginx
- Obtain SSL certificate from Let's Encrypt
- Configure automatic certificate renewal
- Set up all Matrix location blocks

**See**: [docs/STANDALONE_DEPLOYMENT.md](docs/STANDALONE_DEPLOYMENT.md) for complete standalone deployment guide.

### 7. Generate Synapse Configuration

Use the initialization script:

```bash
./scripts/init-synapse.sh
```

Or manually:

```bash
docker exec -it ${SERVICE_NAME:-messenger}-synapse python -m synapse.app.homeserver \
    --config-path /data/homeserver.yaml \
    --generate-config \
    --report-stats=no \
    --server-name="${DOMAIN}"

docker exec -it ${SERVICE_NAME:-messenger}-synapse python -m synapse.app.homeserver \
    --config-path /data/homeserver.yaml \
    --generate-keys
```

**Note**: SSL certificates are automatically managed by nginx-microservice. No manual certificate setup needed.

### 8. Install LiveKit Integration

```bash
./scripts/install-livekit-integration.sh
```

Configure the integration in Synapse config and restart:

```bash
docker-compose restart synapse
```

### 9. Create First User

```bash
docker exec -it ${SERVICE_NAME:-messenger}-synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -a -u admin -p <password> http://localhost:${SYNAPSE_PORT:-3708}
```

### 11. Test A/V Calls

1. Access Element X web client at `https://messenger.statex.cz`
2. Log in with your admin account
3. Start a call with another user
4. Test group calls with 3+ participants

## Client Setup

### Mobile (iOS/Android)

1. Download Element X from App Store/Play Store
2. Open app settings
3. Configure custom server URL: `https://messenger.statex.cz`
4. A/V calls will automatically use LiveKit via Matrix integration

### Desktop (Windows/macOS/Linux)

1. Download Element X desktop app
2. Configure custom server URL: `https://messenger.statex.cz`
3. A/V calls will automatically use LiveKit via Matrix integration

### Web

1. Access `https://messenger.statex.cz`
2. Log in with your account
3. WebRTC calls work in modern browsers via LiveKit

## Maintenance

### Backup

```bash
cd /home/statex/messenger

# Backup PostgreSQL
docker exec ${SERVICE_NAME:-messenger}-postgres pg_dump -U synapse synapse > backup.sql

# Backup Synapse data
tar -czf synapse-backup.tar.gz synapse/data/
```

### Update

To update the microservice:

```bash
cd /home/statex/messenger
# Update code
git pull

# Update .env if needed
nano .env

# Run setup script if configs changed
./scripts/setup-config.sh

# Redeploy (automatically handles Matrix location blocks)
./scripts/deploy.sh
```

The blue/green deployment system ensures zero-downtime updates.

### View Logs

For blue/green deployments, use the appropriate compose file:

```bash
# Active deployment (check which color is active)
docker compose -f docker-compose.green.yml -p messenger_green logs -f synapse
docker compose -f docker-compose.green.yml -p messenger_green logs -f livekit
docker compose -f docker-compose.green.yml -p messenger_green logs -f frontend

# Or view by container name
docker logs messenger-synapse-green -f
docker logs messenger-livekit-green -f
docker logs messenger-element-green -f
```

See [docs/LOGGING.md](docs/LOGGING.md) for detailed logging information.

## Troubleshooting

### A/V Calls Not Working

1. Check LiveKit server accessibility:

   ```bash
   ./scripts/test-livekit-server.sh
   ```

2. Verify firewall rules for UDP ports (configured in nginx-microservice):
   - 7882 (TURN/STUN)
   - 50000-60000 (RTC)

3. Check LiveKit logs:

   ```bash
   docker logs ${SERVICE_NAME:-messenger}-livekit
   ```

4. Verify LiveKit integration in Synapse:

   ```bash
   docker logs ${SERVICE_NAME:-messenger}-synapse | grep -i livekit
   ```

### SSL Certificate Issues

SSL certificates are managed by nginx-microservice. Check nginx-microservice logs:

```bash
cd /path/to/nginx-microservice
docker compose logs nginx
docker compose logs certbot
```

### Database Connection Issues

1. Check PostgreSQL health:

   ```bash
   docker exec ${SERVICE_NAME:-messenger}-postgres pg_isready -U synapse
   ```

2. View PostgreSQL logs:

   ```bash
   docker logs ${SERVICE_NAME:-messenger}-postgres
   ```

### Volume Permission Issues

If containers fail to start due to permission errors on bind-mounted volumes:

1. Check your `.env` file has correct `CONTAINER_USER_UID` and `CONTAINER_USER_GID`:

   ```bash
   grep CONTAINER_USER .env
   ```

2. Set correct ownership on bind-mounted directories:

   ```bash
   # Replace 1000:1000 with your CONTAINER_USER_UID:GID from .env
   sudo chown -R 1000:1000 ./synapse/data
   ```

3. Verify container user matches host user:

   ```bash
   ./scripts/detect-user.sh
   # Compare output with values in .env
   ```

4. Check container is not running as root:

   ```bash
   docker exec ${SERVICE_NAME:-messenger}-synapse id
   # Should show non-zero UID/GID
   ```

## Security

- **All containers run as non-root user** - Configured via `CONTAINER_USER_UID` and `CONTAINER_USER_GID` in `.env`
- Change all default passwords
- Restrict registration after initial setup
- Use strong secrets (32+ characters)
- Keep Docker images updated
- Configure firewall rules
- Enable rate limiting
- Use HTTPS only

### Container User Security

All containers are configured to run as a non-root user for security. This is enforced at multiple levels:

1. **docker-compose.yml** - All services have `user: "${CONTAINER_USER_UID:-1000}:${CONTAINER_USER_GID:-1000}"` directive
2. **setup-config.sh** - Validates that UID/GID are not 0 (root) and fails if root is detected
3. **Default fallback** - If not configured, defaults to UID/GID 1000 (non-root)

**Volume Permissions:**
When using bind mounts (e.g., `./synapse/data`), ensure the directories have correct permissions for the container user:

```bash
# Set ownership to match container user (replace 1000:1000 with your CONTAINER_USER_UID:GID)
sudo chown -R 1000:1000 ./synapse/data
```

For named volumes (postgres_data, redis_data), Docker handles permissions automatically.

## Deployment Script

The main deployment script is `scripts/deploy.sh`. This wrapper script automates the entire deployment process:

1. **Pulls latest changes** from git repository
2. **Deploys via nginx-microservice** using blue/green deployment
3. **Injects Matrix location blocks** from `nginx/gateway-proxy.conf`
4. **Reloads nginx** to apply changes

**Usage:**

```bash
cd /home/statex/messenger
./scripts/deploy.sh
```

**Environment Variables:**

The script reads from `.env` file:

- `SERVICE_NAME` - Service name (default: `messenger`)
- `DOMAIN` - Domain name (default: `messenger.statex.cz`)
- `NGINX_MICROSERVICE_DIR` - Path to nginx-microservice (default: `/home/statex/nginx-microservice`)

**What it does:**

- Calls `nginx-microservice/scripts/blue-green/deploy-smart.sh` to deploy
- Calls `scripts/post-deploy-nginx.sh` to inject Matrix location blocks
- Calls `nginx-microservice/scripts/reload-nginx.sh` to reload nginx

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment information.

## Documentation

- **[README.md](README.md)** - This file, overview and quick start
- **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Microservice deployment guide (with nginx-microservice)
- **[docs/STANDALONE_DEPLOYMENT.md](docs/STANDALONE_DEPLOYMENT.md)** - Standalone deployment guide (without infrastructure)
- **[docs/ENVIRONMENT_VARIABLES.md](docs/ENVIRONMENT_VARIABLES.md)** - Complete environment variables reference
- **[docs/INFRASTRUCTURE_REQUIREMENTS.md](docs/INFRASTRUCTURE_REQUIREMENTS.md)** - Infrastructure requirements
- **[docs/LOGGING.md](docs/LOGGING.md)** - Logging guide
- **[docs/MOBILE_SETUP.md](docs/MOBILE_SETUP.md)** - Mobile client setup guide

## Resources

- [Matrix Documentation](https://matrix.org/docs/)
- [Synapse Documentation](https://matrix-org.github.io/synapse/)
- [LiveKit Documentation](https://docs.livekit.io/)
- [Element X Documentation](https://element.io/help)

## License

[Your License Here]
