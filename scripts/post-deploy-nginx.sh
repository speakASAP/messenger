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

if [ ! -f "$CUSTOM_LOCATIONS_FILE" ]; then
    echo "Custom locations file not found: $CUSTOM_LOCATIONS_FILE"
    exit 0
fi

# Function to inject Matrix locations into a config file
inject_matrix_locations() {
    local config_file="$1"
    local active_color="$2"
    
    if [ ! -f "$config_file" ]; then
        echo "Config file not found: $config_file"
        return 1
    fi
    
    # Read custom locations and replace ${ACTIVE_COLOR} with actual color
    local matrix_locations=$(sed "s/\${ACTIVE_COLOR}/$active_color/g" "$CUSTOM_LOCATIONS_FILE")
    
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
    
    print(f"Matrix locations injected into {config_file}")
except Exception as e:
    print(f"Error injecting locations: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# Inject into both blue and green configs
if [ -f "$BLUE_CONFIG" ]; then
    inject_matrix_locations "$BLUE_CONFIG" "blue"
fi

if [ -f "$GREEN_CONFIG" ]; then
    inject_matrix_locations "$GREEN_CONFIG" "green"
fi

echo "Post-deployment nginx config update completed"

