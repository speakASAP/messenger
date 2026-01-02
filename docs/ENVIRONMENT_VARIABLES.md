# Environment Variables Reference

This document describes all environment variables used by the messenger service. All variables are configured in the `.env` file.

## Quick Start

1. Copy `.env.example` to `.env`:

   ```bash
   cp .env.example .env
   ```

2. Generate secrets:

   ```bash
   ./scripts/generate-secrets.sh > .env.tmp
   # Review and add secrets to .env
   ```

3. Fill in all required values in `.env`

4. Run setup script:

   ```bash
   ./scripts/setup-config.sh
   ```

## Syncing Production and Development .env Files

**Important**: The `.env.example` file should match the structure of production `.env` file (without secrets).

To ensure consistency:

1. **Compare production .env with .env.example:**

   ```bash
   # On production server
   ssh statex "cat /home/statex/messenger/.env" > prod.env
   
   # Compare variable names (not values)
   diff <(grep -o '^[^=]*' prod.env | sort) <(grep -o '^[^=]*' .env.example | sort)
   ```

2. **Update .env.example** if production has additional variables (without secrets)

3. **Never commit production secrets** - Only variable names should be in `.env.example`

4. **Keep .env.example in sync** - When adding new variables to production, update `.env.example`

## Variable Categories

### Matrix Domain Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | ✅ Yes | - | Your Matrix domain (e.g., `messenger.statex.cz`). Must match DNS A record. |
| `ELEMENT_BASE_URL` | ✅ Yes | - | Element web client URL (usually same as `DOMAIN`). |
| `LIVEKIT_URL` | ✅ Yes | - | LiveKit server URL (usually same as `DOMAIN` for standalone, or separate subdomain). |
| `IDENTITY_SERVER_URL` | ⚠️ Optional | `https://vector.im` | Identity server URL for identity verification. |

### Service Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SERVICE_NAME` | ⚠️ Optional | `messenger` | Service name used for container naming. |
| `PRODUCTION_PATH` | ⚠️ Optional | `/home/statex/messenger` | Path where service is deployed (for microservice deployment). |

### PostgreSQL Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `POSTGRES_USER` | ⚠️ Optional | `synapse` | PostgreSQL database user. |
| `POSTGRES_DB` | ⚠️ Optional | `synapse` | PostgreSQL database name. |
| `POSTGRES_PASSWORD` | ✅ Yes | - | PostgreSQL password. **Generate with:** `openssl rand -base64 32` |
| `POSTGRES_PORT` | ⚠️ Optional | `5432` | PostgreSQL port (internal, not exposed to host in production). |

### Synapse Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SYNAPSE_PORT` | ⚠️ Optional | `3708` | Synapse Matrix server port (internal, not exposed to host in production). |
| `SYNAPSE_SECRET_KEY` | ✅ Yes | - | Synapse secret key. **Generate with:** `openssl rand -base64 32` |
| `SYNAPSE_REGISTRATION_SECRET` | ✅ Yes | - | Synapse registration secret (used for user registration). **Generate with:** `openssl rand -base64 32` |

### Redis Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `REDIS_PORT` | ⚠️ Optional | `6379` | Redis port (internal, not exposed to host in production). |
| `REDIS_PASSWORD` | ✅ Yes | - | Redis password. **Generate with:** `openssl rand -base64 32` |

### LiveKit Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `LIVEKIT_API_KEY` | ✅ Yes | - | LiveKit API key. **Generate with:** `openssl rand -hex 16` |
| `LIVEKIT_API_SECRET` | ✅ Yes | - | LiveKit API secret. **Generate with:** `openssl rand -base64 32` |
| `LIVEKIT_HTTP_PORT` | ⚠️ Optional | `7880` | LiveKit HTTP API port (internal). |
| `LIVEKIT_HTTPS_PORT` | ⚠️ Optional | `7881` | LiveKit HTTPS API port (internal). |
| `LIVEKIT_TURN_PORT` | ⚠️ Optional | `7882` | LiveKit TURN/STUN port (UDP/TCP - must be exposed to host for standalone). |
| `LIVEKIT_RTC_PORT_START` | ⚠️ Optional | `50000` | LiveKit RTC port range start (UDP - must be exposed to host for standalone). |
| `LIVEKIT_RTC_PORT_END` | ⚠️ Optional | `60000` | LiveKit RTC port range end (UDP - must be exposed to host for standalone). |
| `LIVEKIT_PORT` | ⚠️ Optional | `7880` | LiveKit port (legacy/alias, same as `LIVEKIT_HTTP_PORT`). |

### Element Web Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ELEMENT_PORT` | ⚠️ Optional | `80` | Element web client port (internal). |
| `ELEMENT_WEB_PORT` | ⚠️ Optional | `80` | Element web port (legacy/alias, same as `ELEMENT_PORT`). |

### Docker Network Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NETWORK_NAME` | ⚠️ Optional | `nginx-network` | Docker network name. For microservice: `nginx-network` (external). For standalone: `messenger-network` (internal, auto-created). |

### Timezone Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TZ` | ⚠️ Optional | `UTC` | Timezone for containers (use UTC for consistency). |

### Container User Configuration (Security)

**IMPORTANT**: All containers run as non-root users for security. These variables MUST be set and MUST NOT be 0 (root).

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CONTAINER_USER_UID` | ✅ Yes | - | User ID for running containers as non-root. **MUST NOT be 0/root.** Detect with: `./scripts/detect-user.sh` or `id -u` |
| `CONTAINER_USER_GID` | ✅ Yes | - | Group ID for running containers as non-root. **MUST NOT be 0/root.** Detect with: `./scripts/detect-user.sh` or `id -g` |
| `CURRENT_UID` | ⚠️ Optional | - | Current UID (alias for `CONTAINER_USER_UID`, used in some compose files). Auto-set by `setup-config.sh`. |
| `CURRENT_GID` | ⚠️ Optional | - | Current GID (alias for `CONTAINER_USER_GID`, used in some compose files). Auto-set by `setup-config.sh`. |

### Let's Encrypt Configuration (Standalone Deployment Only)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `LETSENCRYPT_EMAIL` | ✅ Yes (Standalone) | - | Email for Let's Encrypt certificate notifications. Required for standalone deployment with automatic SSL. |

## Generating Secrets

Use the provided script to generate all required secrets:

```bash
./scripts/generate-secrets.sh > .env.tmp
# Review the output and add secrets to .env
```

Or generate manually:

```bash
# PostgreSQL password
openssl rand -base64 32

# Synapse secret key
openssl rand -base64 32

# Synapse registration secret
openssl rand -base64 32

# Redis password
openssl rand -base64 32

# LiveKit API key
openssl rand -hex 16

# LiveKit API secret
openssl rand -base64 32
```

## Detecting User UID/GID

Use the helper script to detect your user's UID/GID:

```bash
./scripts/detect-user.sh
```

Or manually:

```bash
id -u  # User ID
id -g  # Group ID
```

## Security Best Practices

1. **Never commit `.env` to version control** - It contains secrets!

2. **Use strong passwords** - Minimum 32 characters for production

3. **Keep `.env` file secure** - Set permissions: `chmod 600 .env`

4. **Backup `.env` securely** - Store in secure password manager or encrypted backup

5. **Rotate secrets regularly** - Especially in production environments

6. **Use different secrets per environment** - Don't reuse secrets between dev/staging/prod

## Variable Usage in Codebase

### Docker Compose Files

- `docker-compose.yml` - Base compose file (uses `NETWORK_NAME`, `SERVICE_NAME`)

- `docker-compose.blue.yml` - Blue deployment (uses all variables)

- `docker-compose.green.yml` - Green deployment (uses all variables)

- `docker-compose.standalone.yml` - Standalone deployment (uses all variables)

### Configuration Scripts

- `scripts/setup-config.sh` - Processes templates using `.env` variables

- `scripts/deploy.sh` - Reads `SERVICE_NAME`, `DOMAIN`, `NGINX_MICROSERVICE_DIR`

- `scripts/deploy-standalone.sh` - Reads `SERVICE_NAME`, `DOMAIN`, `LETSENCRYPT_EMAIL`

### Configuration Templates

Variables are used in these templates (processed by `setup-config.sh`):

- `synapse/config/homeserver.yaml.template` - Synapse configuration

- `livekit/config.yaml.template` - LiveKit configuration

- `element/config.json.template` - Element web configuration

- `nginx/standalone.conf.template` - Nginx configuration (standalone)

## Production vs Development

### Production (Microservice Deployment)

Required variables:

- All domain configuration variables
- All secret variables (passwords, keys)
- `CONTAINER_USER_UID` / `CONTAINER_USER_GID` (matching production user)
- `SERVICE_NAME` and `PRODUCTION_PATH`
- `NETWORK_NAME=nginx-network`

### Standalone Deployment

Required variables:

- All domain configuration variables
- All secret variables
- `CONTAINER_USER_UID` / `CONTAINER_USER_GID`
- `LETSENCRYPT_EMAIL` (for SSL certificates)
- `NETWORK_NAME` (auto-created as `messenger-network`)

### Development

Can use:

- Shorter passwords for testing
- `localhost` or local IP for domains
- Test credentials (not in `.env.example`)

## Troubleshooting

### Missing Variables

If a variable is missing, check:

1. Is it in `.env.example`?
2. Is it required for your deployment mode?
3. Does it have a default value?

### Invalid Values

Common issues:

- `CONTAINER_USER_UID/GID` set to 0 (root) - **NOT ALLOWED**
- `DOMAIN` doesn't match DNS
- Secrets too short (use 32+ characters)
- Port conflicts (check if ports are already in use)

### Variable Not Applied

If changes to `.env` aren't applied:

1. Restart containers: `docker compose restart`
2. Re-run setup: `./scripts/setup-config.sh`
3. Check variable name spelling (case-sensitive)
4. Verify no trailing spaces in `.env` file

## Example .env File

See `.env.example` for a complete example with all variables documented.

## Additional Resources

- [README.md](../README.md) - Main documentation
- [DEPLOYMENT.md](DEPLOYMENT.md) - Microservice deployment guide
- [STANDALONE_DEPLOYMENT.md](STANDALONE_DEPLOYMENT.md) - Standalone deployment guide
- `scripts/generate-secrets.sh` - Secret generation script
- `scripts/detect-user.sh` - User UID/GID detection script
