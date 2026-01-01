# Infrastructure Requirements for Matrix Deployment

## Overview

This document outlines the infrastructure requirements for deploying a self-hosted Matrix server with LiveKit for A/V calls.

## Server Requirements

### Minimum Specifications

- **CPU**: 2 cores
- **RAM**: 2-4GB (optimized for low-resource servers)
- **Storage**: 20GB+ (depends on media storage needs)
- **Network**: Public IP address (preferred)

### Recommended Specifications

- **CPU**: 4+ cores
- **RAM**: 8GB+
- **Storage**: 50GB+ SSD
- **Network**: Public IP with good bandwidth

## Network Requirements

### Ports to Open

**TCP Ports:**

- `80` - HTTP (for Let's Encrypt challenges and redirects)
- `443` - HTTPS (for all services)
- `7880` - LiveKit HTTP API
- `7881` - LiveKit HTTPS API
- `7882` - LiveKit TURN/STUN (TCP)

**UDP Ports:**

- `7882` - LiveKit TURN/STUN (UDP)
- `50000-60000` - LiveKit RTC media (UDP)

### Firewall Configuration

Ensure these ports are open in:

1. Server firewall (iptables, ufw, firewalld, etc.)
2. Cloud provider security groups
3. Router/firewall (if applicable)

### DNS Configuration

Required DNS A records:

- `matrix.example.com` → Server IP
- `element.example.com` → Server IP
- `livekit.example.com` → Server IP

## Infrastructure Assessment Checklist

Before deployment, verify:

- [ ] Server has public IP address (preferred, but LiveKit can work behind NAT)
- [ ] UDP port 7882 (LiveKit TURN/STUN) is accessible from internet
- [ ] UDP ports 50000-60000 (LiveKit RTC) are accessible from internet
- [ ] Firewall allows UDP traffic on required ports
- [ ] Cloud provider security groups allow UDP traffic
- [ ] Domain DNS A records point to server IP
- [ ] Domain resolves correctly: `dig livekit.example.com`
- [ ] HTTPS is configured for LiveKit (required for production)
- [ ] Sufficient bandwidth for media relay (SFU uses bandwidth)

## Testing Infrastructure

### Pre-Deployment Tests

1. **Test UDP port accessibility:**

   ```bash
   nc -u -v <server-ip> 7882
   # Should connect, not timeout
   ```

2. **Test DNS resolution:**

   ```bash
   dig matrix.example.com
   dig element.example.com
   dig livekit.example.com
   # Should return server IP
   ```

3. **Test HTTPS (after deployment):**

   ```bash
   curl https://livekit.example.com
   # Should return LiveKit API response
   ```

4. **Test from external network:**
   - Use mobile hotspot to test from different network
   - Verify all services are accessible

### Post-Deployment Tests

1. Test 1-on-1 call between two clients on different networks
2. Test group call with 3+ participants (LiveKit excels at group calls)
3. Test call from behind corporate firewall
4. Test call from mobile network (carrier-grade NAT)
5. Monitor LiveKit server logs for connection attempts
6. Check Synapse logs for LiveKit integration errors
7. Verify LiveKit room creation from Matrix rooms

## Common Infrastructure Issues

### Issue 1: UDP Ports Blocked

**Problem**: Firewall or cloud provider blocks UDP ports

**Symptoms**: A/V calls fail, WebRTC connections can't establish

**Solutions**:

- Open UDP ports 7882 (TURN/STUN) and 50000-60000 (RTC) in firewall
- Configure cloud provider security groups/firewall rules
- Test port accessibility: `nc -u -v <server-ip> 7882`

### Issue 2: HTTPS Not Configured

**Problem**: LiveKit requires HTTPS for WebRTC in production

**Symptoms**: A/V calls fail in production, work in development

**Solutions**:

- Configure Let's Encrypt certificates for LiveKit domain
- Set up nginx reverse proxy with SSL termination
- Ensure LiveKit URL uses HTTPS

### Issue 3: Domain Not Resolvable

**Problem**: LiveKit server configured with domain but DNS not set up

**Symptoms**: Clients can't connect to LiveKit server

**Solutions**:

- Ensure domain resolves to server's public IP
- Configure A record for LiveKit domain
- Test DNS: `dig livekit.example.com`

### Issue 4: API Key Configuration

**Problem**: Incorrect LiveKit API keys in Synapse integration

**Symptoms**: Matrix rooms can't create LiveKit sessions

**Solutions**:

- Verify API key and secret in LiveKit config
- Ensure same credentials in Synapse LiveKit integration
- Check LiveKit logs for authentication errors

## Advantages of LiveKit Over Separate TURN Server

1. **Simplified Configuration**: No need to configure separate TURN server
2. **Built-in TURN**: TURN server is integrated, reducing infrastructure complexity
3. **Better Group Calls**: SFU architecture is superior for group calls
4. **Automatic NAT Traversal**: Handles NAT traversal automatically
5. **Modern Architecture**: Designed for modern WebRTC applications
6. **Easier Troubleshooting**: Single service to monitor instead of multiple components

## Bandwidth Considerations

### Estimated Bandwidth Usage

- **1-on-1 call**: ~500 Kbps per participant (audio + video)
- **Group call (5 participants)**: ~2-3 Mbps per participant
- **SFU overhead**: Minimal compared to peer-to-peer

### Recommendations

- Minimum: 10 Mbps upload/download
- Recommended: 50+ Mbps for multiple concurrent calls
- Monitor bandwidth usage and scale as needed

## Security Considerations

1. **Firewall Rules**: Only open necessary ports
2. **SSL/TLS**: Use Let's Encrypt certificates for all services
3. **Rate Limiting**: Configure rate limiting in nginx
4. **Access Control**: Restrict registration after initial setup
5. **Regular Updates**: Keep Docker images and system updated
