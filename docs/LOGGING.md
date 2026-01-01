# Logging Guide for Messenger Service

This document describes where to find logs for the messenger service and how to access them.

## Docker Container Logs

### Basic Commands

```bash
# View logs for a specific container
docker logs messenger-synapse-blue

# Follow logs in real-time
docker logs -f messenger-synapse-blue

# Last N lines
docker logs --tail 100 messenger-synapse-blue

# Logs with timestamps
docker logs -t messenger-synapse-blue

# Logs since specific time
docker logs --since 1h messenger-synapse-blue
docker logs --since 2024-01-01T10:00:00 messenger-synapse-blue

# Logs between timestamps
docker logs --since 1h --until 30m messenger-synapse-blue
```

### Docker Compose Logs

```bash
# All services
cd ~/messenger
docker compose -f docker-compose.green.yml -p messenger_green logs

# Specific service
docker compose -f docker-compose.green.yml -p messenger_green logs synapse

# Follow all services
docker compose -f docker-compose.green.yml -p messenger_green logs -f

# Last 100 lines of all services
docker compose -f docker-compose.green.yml -p messenger_green logs --tail 100
```

## Container Log File Locations

Docker stores container logs in JSON format on the host:

```bash
# Location (requires root access)
/var/lib/docker/containers/<container-id>/<container-id>-json.log

# Find log file for a container
docker inspect messenger-synapse-blue | grep LogPath

# View log file directly (requires root)
sudo tail -f /var/lib/docker/containers/*/*-json.log
```

## System Journal Logs (systemd)

```bash
# Docker service logs
journalctl -u docker

# Follow Docker service logs
journalctl -u docker -f

# Docker logs since specific time
journalctl -u docker --since "1 hour ago"

# All system logs
journalctl -f

# Filter by service
journalctl -u docker --since today
```

## Application-Specific Log Locations

### Synapse Logs

```bash
# Inside container
docker exec messenger-synapse-blue ls -la /data/

# Synapse log files (if configured)
docker exec messenger-synapse-blue find /data -name "*.log"

# View Synapse logs via docker
docker logs messenger-synapse-blue
```

### Postgres Logs

```bash
# Postgres logs (if logging enabled)
docker exec messenger-postgres ls -la /var/lib/postgresql/data/pgdata/log/

# View via docker logs
docker logs messenger-postgres
```

### Redis Logs

```bash
# Redis logs
docker logs messenger-redis

# Redis doesn't typically write log files, all output goes to stdout/stderr
```

### LiveKit Logs

```bash
# LiveKit logs
docker logs messenger-livekit-blue

# Follow LiveKit logs
docker logs -f messenger-livekit-blue
```

### Element (Frontend) Logs

```bash
# Element web logs
docker logs messenger-element-blue

# Nginx logs inside container
docker exec messenger-element-blue cat /var/log/nginx/access.log
docker exec messenger-element-blue cat /var/log/nginx/error.log
```

## Nginx-Microservice Logs

```bash
# Nginx access logs
docker exec nginx-microservice tail -f /var/log/nginx/access.log

# Nginx error logs
docker exec nginx-microservice tail -f /var/log/nginx/error.log

# All nginx logs
docker logs nginx-microservice

# Specific domain logs (if configured)
docker exec nginx-microservice ls -la /var/log/nginx/
```

## System Logs

### Syslog

```bash
# System messages
tail -f /var/log/syslog

# Auth logs
tail -f /var/log/auth.log

# Kernel messages
dmesg | tail -50

# OOM (Out of Memory) kills
dmesg | grep -i "oom\|killed"
```

## Useful Log Commands

### View All Container Logs

```bash
# All running containers
docker ps -q | xargs docker logs --tail 50

# All messenger containers
docker ps --filter "name=messenger" --format "{{.Names}}" | xargs -I {} docker logs {} --tail 50
```

### Search Logs

```bash
# Search for errors in Synapse logs
docker logs messenger-synapse-blue 2>&1 | grep -i error

# Search for specific pattern
docker logs messenger-synapse-blue 2>&1 | grep -E "ERROR|WARNING|SIGKILL"

# Search across all containers
docker ps --format "{{.Names}}" | xargs -I {} sh -c 'echo "=== {} ===" && docker logs {} 2>&1 | grep -i "error\|warning" | tail -5'
```

### Export Logs

```bash
# Save logs to file
docker logs messenger-synapse-blue > synapse.log 2>&1

# Export all messenger logs
docker ps --filter "name=messenger" --format "{{.Names}}" | xargs -I {} sh -c 'docker logs {} > {}.log 2>&1'
```

## Log Rotation

Docker automatically rotates logs. Configuration:

```bash
# Check Docker log driver configuration
docker info | grep -i log

# Docker daemon log rotation settings (in /etc/docker/daemon.json)
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

## Monitoring Logs

### Real-time Monitoring

```bash
# Watch all messenger containers
watch -n 1 'docker ps --filter "name=messenger" --format "table {{.Names}}\t{{.Status}}"'

# Follow multiple containers
docker compose -f docker-compose.green.yml -p messenger_green logs -f --tail 50
```

### Log Aggregation Tools

For production, consider:
- **ELK Stack** (Elasticsearch, Logstash, Kibana)
- **Loki** (Grafana Loki)
- **Fluentd**
- **Prometheus + Grafana** (for metrics)

## Troubleshooting

### Container Not Logging

```bash
# Check if container is running
docker ps | grep messenger

# Check container status
docker inspect messenger-synapse-blue | grep -A 10 State

# Restart container to see startup logs
docker restart messenger-synapse-blue && docker logs -f messenger-synapse-blue
```

### Logs Not Appearing

```bash
# Check Docker daemon logs
journalctl -u docker --since "10 minutes ago"

# Verify log driver
docker inspect messenger-synapse-blue | grep -A 5 LogConfig

# Check disk space
df -h /var/lib/docker
```

## Best Practices

1. **Use structured logging** - Configure applications to output JSON logs
2. **Set log rotation** - Prevent disk space issues
3. **Monitor log sizes** - Use `docker system df` to check disk usage
4. **Centralize logs** - Use log aggregation tools for production
5. **Filter logs** - Use grep/awk to find relevant information
6. **Archive old logs** - Keep logs for troubleshooting but don't keep forever

