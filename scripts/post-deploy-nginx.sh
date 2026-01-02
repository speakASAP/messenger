#!/bin/bash
# Post-deployment script to inject Matrix location blocks into nginx configs
# This script should be run after nginx-microservice generates the configs
# It reads the custom location blocks from nginx/gateway-proxy.conf and injects them

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NGINX_MICROSERVICE_DIR="${NGINX_MICROSERVICE_DIR:-/home/statex/nginx-microservice}"
SERVICE_NAME="${SERVICE_NAME:-messenger}"
DOMAIN="${DOMAIN:-messenger.statex.cz}"

# Colors for output
CUSTOM_LOCATIONS_FILE="$PROJECT_ROOT/nginx/gateway-proxy.conf"
BLUE_CONFIG="$NGINX_MICROSERVICE_DIR/nginx/conf.d/blue-green/${DOMAIN}.blue.conf"
GREEN_CONFIG="$NGINX_MICROSERVICE_DIR/nginx/conf.d/blue-green/${DOMAIN}.green.conf"
REGISTRY_FILE="$NGINX_MICROSERVICE_DIR/service-registry/${SERVICE_NAME}.json"

if [ ! -f "$CUSTOM_LOCATIONS_FILE" ]; then
    echo "Custom locations file not found: $CUSTOM_LOCATIONS_FILE"
    exit 0
fi

# Determine active color by checking which containers are running
ACTIVE_COLOR="blue"  # Default fallback

# Try to get active color from registry first
if [ -f "$REGISTRY_FILE" ]; then
    REGISTRY_ACTIVE_COLOR=$(jq -r ".domains.\"${DOMAIN}\".active_color // empty" "$REGISTRY_FILE" 2>/dev/null)
    if [ -n "$REGISTRY_ACTIVE_COLOR" ] && [ "$REGISTRY_ACTIVE_COLOR" != "null" ]; then
        ACTIVE_COLOR="$REGISTRY_ACTIVE_COLOR"
    fi
fi

# If not found in registry, detect by checking which synapse container is running
if [ "$ACTIVE_COLOR" = "blue" ]; then
    RUNNING_SYNAPSE=$(docker ps --filter "name=${SERVICE_NAME}-synapse" --format "{{.Names}}" 2>/dev/null | head -1)
    if [ -n "$RUNNING_SYNAPSE" ]; then
        if echo "$RUNNING_SYNAPSE" | grep -q "green"; then
            ACTIVE_COLOR="green"
        elif echo "$RUNNING_SYNAPSE" | grep -q "blue"; then
            ACTIVE_COLOR="blue"
        fi
    fi
fi

echo "Using active color: $ACTIVE_COLOR"

# Function to inject Matrix locations into a config file
inject_matrix_locations() {
    local config_file="$1"
    local color_to_use="$2"
    
    if [ ! -f "$config_file" ]; then
        echo "Config file not found: $config_file"
        return 1
    fi
    
    # Remove existing Matrix location blocks if they exist (to avoid duplicates)
    python3 <<PYEOF
import re
import sys

config_file = "$config_file"

try:
    with open(config_file, 'r') as f:
        content = f.read()
    
    # Remove existing Matrix location blocks (between Matrix comment and Frontend comment)
    # Pattern matches from "# Matrix" or "# Nginx Reverse Proxy" to "# Frontend service"
    pattern = r'(# Matrix.*?)(?=\s+# Frontend service)'
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    with open(config_file, 'w') as f:
        f.write(content)
except Exception as e:
    print(f"Error cleaning existing locations: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
    
    # Read custom locations and replace ${ACTIVE_COLOR} with active color
    local matrix_locations=$(sed "s/\${ACTIVE_COLOR}/$color_to_use/g" "$CUSTOM_LOCATIONS_FILE")
    
    # Use Python to inject locations before frontend location block
    python3 <<PYEOF
import re
import sys

config_file = "$config_file"
matrix_locations = """$matrix_locations"""

try:
    with open(config_file, 'r') as f:
        content = f.read()
    
    # Find the frontend location block and insert matrix locations before it
    pattern = r'(    # Frontend service - root path)'
    replacement = matrix_locations + r'\n    \1'
    
    new_content = re.sub(pattern, replacement, content)
    
    with open(config_file, 'w') as f:
        f.write(new_content)
    
    print(f"Matrix locations injected into {config_file} (using color: $color_to_use)")
except Exception as e:
    print(f"Error injecting locations: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# Inject into both blue and green configs using the ACTIVE color
# Both configs should point to the active color containers
echo "Injecting Matrix location blocks using active color: $ACTIVE_COLOR"

if [ -f "$BLUE_CONFIG" ]; then
    inject_matrix_locations "$BLUE_CONFIG" "$ACTIVE_COLOR"
fi

if [ -f "$GREEN_CONFIG" ]; then
    inject_matrix_locations "$GREEN_CONFIG" "$ACTIVE_COLOR"
fi

echo "Post-deployment nginx config update completed"

