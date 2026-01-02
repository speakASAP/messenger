# Standalone Deployment Guide

This guide explains how to deploy the messenger service as a standalone installation **without** the microservices infrastructure (no nginx-microservice, no blue/green deployment).

## Overview

Standalone deployment includes:

- All services in a single docker-compose file
- Built-in nginx reverse proxy with SSL termination
- Automatic Let's Encrypt SSL certificate management
- Self-contained network (no external dependencies)
- Direct port exposure on host

**Use standalone deployment when:**

- You don't have the microservices infrastructure
- You want a simple, self-contained deployment
- You're deploying on a single server
- You don't need blue/green deployment

**Use microservice deployment when:**

- You have the nginx-microservice infrastructure
- You need blue/green deployment for zero-downtime updates
- You're integrating with other microservices

## Prerequisites

1. **Docker and Docker Compose** installed
2. **Domain name** configured in DNS pointing to your server IP
3. **Ports open** on firewall:
   - `80` (HTTP - for Let's Encrypt and redirects)
   - `443` (HTTPS - for all services)
   - `7882` (UDP - LiveKit TURN/STUN)
   - `50000-60000` (UDP - LiveKit RTC media)
4. **Server** with at least 2-4GB RAM
5. **Root or sudo access** (for initial setup)

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd messenger
```

### 2. Generate Secrets

```bash
./scripts/generate-secrets.sh > .env.tmp
# Review and add to .env file
```

### 3. Configure Environment

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
nano .env
```

**Required variables for standalone deployment:**

- `DOMAIN` - Your domain (e.g., `messenger.example.com`)
- `SERVICE_NAME` - Service name (default: `messenger`)
- `LETSENCRYPT_EMAIL` - Email for Let's Encrypt notifications (required for standalone)
- `POSTGRES_PASSWORD` - Strong database password (generate with `openssl rand -base64 32`)
- `SYNAPSE_SECRET_KEY` - Generated secret key (generate with `openssl rand -base64 32`)
- `SYNAPSE_REGISTRATION_SECRET` - Registration secret (generate with `openssl rand -base64 32`)
- `LIVEKIT_API_KEY` - LiveKit API key (generate with `openssl rand -hex 16`)
- `LIVEKIT_API_SECRET` - LiveKit API secret (generate with `openssl rand -base64 32`)
- `REDIS_PASSWORD` - Redis password (generate with `openssl rand -base64 32`)
- `CONTAINER_USER_UID` - User ID for containers (MUST NOT be 0/root, detect with `./scripts/detect-user.sh`)
- `CONTAINER_USER_GID` - Group ID for containers (MUST NOT be 0/root, detect with `./scripts/detect-user.sh`)
- Domain configuration (`ELEMENT_BASE_URL`, `LIVEKIT_URL`)

**See**: [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md) for complete list of all environment variables.

**Detect your user UID/GID:**

```bash
./scripts/detect-user.sh
```

### 4. Configure DNS

Set up DNS A record:

- `your-domain.com` → Your server IP address

Verify DNS resolution:

```bash
dig your-domain.com
```

### 5. Update Configuration Files

Run the setup script to update configuration files:

```bash
./scripts/setup-config.sh
```

**Important**: After running setup-config.sh, manually update `livekit/config.yaml` with your LiveKit API keys:

- Replace `API_KEY` with your `LIVEKIT_API_KEY` from .env
- Replace `API_SECRET` with your `LIVEKIT_API_SECRET` from .env

### 6. Deploy

Run the standalone deployment script:

```bash
./scripts/deploy-standalone.sh
```

This script will:

1. Check prerequisites
2. Prepare nginx configuration
3. Start services
4. Obtain SSL certificate from Let's Encrypt
5. Start all services with SSL

### 7. Initialize Synapse

After first deployment:

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

### 8. Create First User

```bash
docker exec -it ${SERVICE_NAME:-messenger}-synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -a -u admin -p <password> http://localhost:${SYNAPSE_PORT:-3708}
```

### 9. Install LiveKit Integration

```bash
./scripts/install-livekit-integration.sh
```

Restart Synapse:

```bash
docker compose -f docker-compose.standalone.yml restart synapse
```

## Manual Deployment (Alternative)

If you prefer manual deployment:

```bash
# 1. Prepare nginx config
sed "s/\${DOMAIN}/your-domain.com/g; s/\${SERVICE_NAME}/messenger/g" \
    nginx/standalone.conf > nginx/standalone.conf.tmp
mv nginx/standalone.conf.tmp nginx/standalone.conf

# 2. Start services (without nginx first)
docker compose -f docker-compose.standalone.yml up -d postgres redis synapse element-web livekit

# 3. Start nginx for Let's Encrypt challenge
docker compose -f docker-compose.standalone.yml up -d nginx

# 4. Get SSL certificate
docker run --rm \
    -v messenger_certbot-www:/var/www/certbot:rw \
    -v messenger_certbot-conf:/etc/letsencrypt:rw \
    --network messenger_messenger-network \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email your-email@example.com \
    --agree-tos \
    --no-eff-email \
    -d your-domain.com

# 5. Start all services
docker compose -f docker-compose.standalone.yml up -d
```

## Architecture

Standalone deployment includes:

- **postgres** - PostgreSQL database
- **redis** - Redis cache
- **synapse** - Matrix homeserver
- **livekit** - LiveKit SFU for A/V calls
- **element-web** - Element web client
- **nginx** - Reverse proxy with SSL termination
- **certbot** - Automatic SSL certificate renewal

All services run in a single Docker network (`messenger-network`).

## Port Configuration

**Exposed ports on host:**

- `80` - HTTP (redirects to HTTPS, Let's Encrypt challenges)
- `443` - HTTPS (all services)
- `7882/udp` - LiveKit TURN/STUN
- `50000-60000/udp` - LiveKit RTC media

**Internal ports (not exposed):**

- `5432` - PostgreSQL
- `6379` - Redis
- `3708` - Synapse
- `7880` - LiveKit HTTP
- `80` - Element web

## SSL Certificate Management

SSL certificates are automatically managed by certbot:

- **Initial certificate**: Obtained during first deployment
- **Auto-renewal**: Certbot container renews certificates every 12 hours
- **Nginx reload**: Nginx automatically reloads when certificates are renewed

**Manual renewal:**

```bash
docker exec ${SERVICE_NAME:-messenger}-certbot certbot renew
docker compose -f docker-compose.standalone.yml restart nginx
```

**Certificate location:**

- Volume: `messenger_certbot-conf` (Docker volume)
- Path in container: `/etc/letsencrypt/live/${DOMAIN}/`

## Maintenance

### Update Services

```bash
cd /path/to/messenger
git pull
docker compose -f docker-compose.standalone.yml pull
docker compose -f docker-compose.standalone.yml up -d
```

### View Logs

```bash
# All services
docker compose -f docker-compose.standalone.yml logs -f

# Specific service
docker compose -f docker-compose.standalone.yml logs -f synapse
docker compose -f docker-compose.standalone.yml logs -f nginx
docker compose -f docker-compose.standalone.yml logs -f certbot
```

### Backup

```bash
# Backup PostgreSQL
docker exec ${SERVICE_NAME:-messenger}-postgres pg_dump -U synapse synapse > backup.sql

# Backup Synapse data
tar -czf synapse-backup.tar.gz synapse/data/

# Backup SSL certificates (optional)
docker run --rm -v messenger_certbot-conf:/data -v $(pwd):/backup alpine tar czf /backup/certbot-backup.tar.gz /data
```

### Restore

```bash
# Restore PostgreSQL
cat backup.sql | docker exec -i ${SERVICE_NAME:-messenger}-postgres psql -U synapse synapse

# Restore Synapse data
tar -xzf synapse-backup.tar.gz

# Restore SSL certificates (optional)
docker run --rm -v messenger_certbot-conf:/data -v $(pwd):/backup alpine tar xzf /backup/certbot-backup.tar.gz -C /
```

## Troubleshooting

### SSL Certificate Issues

**Certificate not obtained:**

1. Check DNS resolution:

   ```bash
   dig your-domain.com
   ```

2. Check firewall allows port 80:

   ```bash
   curl http://your-domain.com/.well-known/acme-challenge/test
   ```

3. Check nginx logs:

   ```bash
   docker logs ${SERVICE_NAME:-messenger}-nginx
   ```

4. Manually request certificate:

   ```bash
   docker run --rm \
       -v messenger_certbot-www:/var/www/certbot:rw \
       -v messenger_certbot-conf:/etc/letsencrypt:rw \
       --network messenger_messenger-network \
       certbot/certbot certonly \
       --webroot \
       --webroot-path=/var/www/certbot \
       --email your-email@example.com \
       --agree-tos \
       --no-eff-email \
       -d your-domain.com
   ```

### Services Not Starting

1. Check container status:

   ```bash
   docker compose -f docker-compose.standalone.yml ps
   ```

2. Check logs:

   ```bash
   docker compose -f docker-compose.standalone.yml logs
   ```

3. Check disk space:

   ```bash
   df -h
   ```

4. Check port conflicts:

   ```bash
   sudo netstat -tulpn | grep -E ':(80|443) '
   ```

### Matrix API Not Working

1. Check nginx configuration:

   ```bash
   docker exec ${SERVICE_NAME:-messenger}-nginx nginx -t
   ```

2. Check Matrix location blocks in nginx config:

   ```bash
   docker exec ${SERVICE_NAME:-messenger}-nginx cat /etc/nginx/conf.d/default.conf | grep -A 10 "_matrix"
   ```

3. Check Synapse is running:

   ```bash
   docker exec ${SERVICE_NAME:-messenger}-synapse curl -f http://localhost:3708/health
   ```

### LiveKit Not Working

1. Check UDP ports are open:

   ```bash
   sudo netstat -ulpn | grep -E ':(7882|50000)'
   ```

2. Check LiveKit logs:

   ```bash
   docker logs ${SERVICE_NAME:-messenger}-livekit
   ```

3. Verify firewall allows UDP:

   ```bash
   sudo ufw status
   # or
   sudo iptables -L -n | grep -E '7882|50000'
   ```

## Security Considerations

1. **Firewall**: Only expose necessary ports (80, 443, 7882/udp, 50000-60000/udp)
2. **Container user**: All containers run as non-root user
3. **SSL/TLS**: Use Let's Encrypt certificates (auto-renewal enabled)
4. **Secrets**: Store all secrets in `.env` file (never commit to git)
5. **Updates**: Keep Docker images updated
6. **Backups**: Regularly backup PostgreSQL and Synapse data

## Differences from Microservice Deployment

| Feature | Standalone | Microservice |
|---------|-----------|--------------|
| Nginx | Included in compose | External (nginx-microservice) |
| SSL | Certbot container | Handled by nginx-microservice |
| Deployment | Direct docker compose | Blue/green via nginx-microservice |
| Network | Internal Docker network | External network (nginx-network) |
| Updates | Manual restart | Zero-downtime blue/green |
| Configuration | All in codebase | Split between codebase and nginx-microservice |

## Next Steps

After deployment:

1. ✅ Initialize Synapse
2. ✅ Create first user
3. ✅ Install LiveKit integration
4. ✅ Test A/V calls
5. ✅ Configure mobile clients (see [MOBILE_SETUP.md](MOBILE_SETUP.md))
6. ✅ Set up backups
7. ✅ Monitor logs

## Additional Resources

- [README.md](../README.md) - Main documentation
- [DEPLOYMENT.md](DEPLOYMENT.md) - Microservice deployment guide
- [INFRASTRUCTURE_REQUIREMENTS.md](INFRASTRUCTURE_REQUIREMENTS.md) - Infrastructure requirements
- [LOGGING.md](LOGGING.md) - Logging guide
- [MOBILE_SETUP.md](MOBILE_SETUP.md) - Mobile client setup
