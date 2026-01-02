# Matrix Self-Hosted Deployment

Complete self-hosted Matrix messaging environment using Docker containers with Synapse homeserver, PostgreSQL database, Element X clients, LiveKit SFU with built-in TURN server for A/V calls, and nginx reverse proxy with Let's Encrypt SSL certificates.

## Architecture

- **Synapse** - Matrix homeserver handling messaging, federation, and room management
- **PostgreSQL** - Database for Synapse (optimized for production)
- **Redis** - Caching and worker coordination
- **LiveKit** - Modern SFU (Selective Forwarding Unit) with built-in TURN server for A/V calls
- **Element X Web** - Modern web-based client
- **nginx-microservice** - External reverse proxy with SSL termination (handled by nginx-microservice)

## Prerequisites

- Docker and Docker Compose installed
- nginx-microservice running and accessible
- Domain name: messenger.statex.cz (configured in DNS)
- Server with at least 2-4GB RAM (low-resource optimized)
- Ports for LiveKit: 7880, 7881, 7882 (UDP/TCP), and 50000-60000 (UDP) - these will be handled by nginx-microservice
- Service will be deployed via nginx-microservice blue/green deployment system

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

Required variables:
- `DOMAIN` - Your Matrix domain (e.g., matrix.example.com)
- `ELEMENT_BASE_URL` - Element web URL (e.g., https://element.example.com)
- `LIVEKIT_URL` - LiveKit server URL (e.g., https://livekit.example.com)
- `POSTGRES_PASSWORD` - Strong database password
- `SYNAPSE_SECRET_KEY` - Generated secret key
- `SYNAPSE_REGISTRATION_SECRET` - Registration secret
- `LIVEKIT_API_KEY` - LiveKit API key
- `LIVEKIT_API_SECRET` - LiveKit API secret
- `REDIS_PASSWORD` - Redis password
- `LETSENCRYPT_EMAIL` - Email for Let's Encrypt notifications
- `CONTAINER_USER_UID` - User ID for all containers (MUST NOT be 0/root)
- `CONTAINER_USER_GID` - Group ID for all containers (MUST NOT be 0/root)

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

### 6. Deploy via nginx-microservice

This service is deployed using the nginx-microservice blue/green deployment system:

**Recommended: Use the wrapper script** (automatically handles Matrix location blocks):

```bash
cd /home/statex/messenger
./scripts/deploy.sh
```

**Alternative: Manual deployment**:

```bash
cd /path/to/nginx-microservice
./scripts/blue-green/deploy-smart.sh messenger
cd /home/statex/messenger
./scripts/post-deploy-nginx.sh
cd /path/to/nginx-microservice
./scripts/reload-nginx.sh
```

The deployment script will:
- Auto-create service registry
- Build and start containers
- Configure nginx routing
- Automatically inject Matrix location blocks from `nginx/gateway-proxy.conf`
- Handle SSL certificates
- Perform health checks
- Switch traffic with zero downtime

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
# Backup PostgreSQL
docker exec matrix-postgres pg_dump -U synapse synapse > backup.sql

# Backup Synapse data
tar -czf synapse-backup.tar.gz synapse/data/
```

### Update

```bash
docker-compose pull
docker-compose up -d
```

### View Logs

```bash
docker-compose logs -f synapse
docker-compose logs -f livekit
docker-compose logs -f nginx
```

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

## Resources

- [Matrix Documentation](https://matrix.org/docs/)
- [Synapse Documentation](https://matrix-org.github.io/synapse/)
- [LiveKit Documentation](https://docs.livekit.io/)
- [Element X Documentation](https://element.io/help)

## License

[Your License Here]
