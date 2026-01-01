# Mobile Client Setup Guide

This guide explains how to connect Element X mobile apps to your self-hosted Matrix server at `messenger.statex.cz`.

## Prerequisites

- Matrix server running at `https://messenger.statex.cz`
- A user account created on the server (see [Creating First User](#creating-first-user))
- Mobile device (iOS or Android)

## Download Element X

### iOS (iPhone/iPad)

1. Open the **App Store** on your device
2. Search for **"Element X"**
3. Download and install **Element X** by Element (formerly New Vector)
4. The app icon is a blue "X" on a white background

**Direct link**: [Element X on App Store](https://apps.apple.com/app/element-x/id6443926742)

### Android

1. Open **Google Play Store** on your device
2. Search for **"Element X"**
3. Download and install **Element X** by Element
4. The app icon is a blue "X" on a white background

**Direct link**: [Element X on Google Play](https://play.google.com/store/apps/details?id=im.vector.app)

## Connecting to Your Server

### Step 1: Open Element X

Launch the Element X app on your mobile device.

### Step 2: Configure Custom Server

1. On the welcome/login screen, look for **"Change"** or **"Edit"** next to the server URL
2. Tap on it to open server configuration
3. Enter your server URL: `https://messenger.statex.cz`
4. Tap **"Continue"** or **"Next"**

**Note**: If you don't see a server configuration option:
- Look for **"Advanced"** or **"Settings"** button
- Or tap **"Sign in"** and then look for **"Change server"** option

### Step 3: Sign In

1. Enter your Matrix username (format: `@username:messenger.statex.cz`)
2. Enter your password
3. Tap **"Sign in"**

**Alternative**: If you haven't created an account yet, you can:
- Tap **"Create account"** (if registration is enabled)
- Or create an account via command line first (see below)

## Creating First User

If you haven't created a user account yet, create one via SSH:

```bash
ssh statex
cd /home/statex/messenger
docker exec -it messenger-synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -a -u admin -p <your-password> http://localhost:3708
```

Replace:
- `admin` with your desired username
- `<your-password>` with your desired password

**Note**: The `-a` flag creates an admin user. Remove it for a regular user.

## Verifying Connection

After signing in, you should see:
- ✅ Your profile/account information
- ✅ Ability to create rooms
- ✅ Ability to send messages
- ✅ A/V call functionality (via LiveKit integration)

## Troubleshooting

### Can't Connect to Server

1. **Check server accessibility**:
   ```bash
   curl https://messenger.statex.cz/_matrix/client/versions
   ```
   Should return JSON with Matrix API versions.

2. **Verify SSL certificate**:
   - Open `https://messenger.statex.cz` in mobile browser
   - Check that SSL certificate is valid (no warnings)

3. **Check firewall**:
   - Ensure ports 80 and 443 are open
   - UDP ports 7882 and 50000-60000 for A/V calls

### "Server not found" Error

- Verify the server URL is exactly: `https://messenger.statex.cz`
- Check that `.well-known` files are accessible:
  - `https://messenger.statex.cz/.well-known/matrix/server`
  - `https://messenger.statex.cz/.well-known/matrix/client`

### A/V Calls Not Working

1. **Check LiveKit service**:
   ```bash
   docker logs messenger-livekit
   ```

2. **Verify network connectivity**:
   - Ensure UDP ports are accessible
   - Check firewall rules for ports 7882 and 50000-60000

3. **Check Element X config**:
   - Verify `element_call` configuration in `element/config.json`
   - Should have: `"element_call": { "url": "https://messenger.statex.cz" }`

## Features Available on Mobile

Once connected, you'll have access to:

- ✅ **Peer-to-peer messaging** - Send messages to other users
- ✅ **Group messaging** - Create and join group chats
- ✅ **A/V calls** - Voice and video calls (1-on-1)
- ✅ **Group A/V calls** - Group voice and video calls
- ✅ **File sharing** - Share images, documents, etc.
- ✅ **End-to-end encryption** - Secure messaging

## Additional Resources

- **Element X Documentation**: https://element.io/help
- **Matrix Specification**: https://spec.matrix.org/
- **Server Status**: Check `https://messenger.statex.cz/_matrix/client/versions`

## Support

If you encounter issues:

1. Check server logs:
   ```bash
   docker logs messenger-synapse
   docker logs messenger-element
   docker logs messenger-livekit
   ```

2. Verify nginx configuration:
   ```bash
   cd ~/nginx-microservice
   ./scripts/blue-green/health-check.sh messenger
   ```

3. Check Matrix server status:
   ```bash
   curl https://messenger.statex.cz/_matrix/client/versions
   ```

