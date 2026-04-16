#!/bin/bash
# Wrapper deployment script that automatically handles Matrix location blocks
# Usage: ./scripts/deploy.sh
# This script calls nginx-microservice deployment and automatically injects Matrix location blocks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NGINX_MICROSERVICE_DIR="${NGINX_MICROSERVICE_DIR:-/home/statex/nginx-microservice}"
SERVICE_NAME="${SERVICE_NAME:-messenger}"

# Source .env to get SERVICE_NAME and DOMAIN if not set
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Default values
SERVICE_NAME="${SERVICE_NAME:-messenger}"
DISPLAY_NAME="$(echo "${SERVICE_NAME:0:1}" | tr 'a-z' 'A-Z')${SERVICE_NAME:1}"
DOMAIN="${DOMAIN:-messenger.alfares.cz}"

echo "🚀 Starting deployment for $SERVICE_NAME..."

# Colors for phase summary
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load NODE_ENV from .env file to determine environment
NODE_ENV="${NODE_ENV:-}"
if [ -z "$NODE_ENV" ] && [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/.env" 2>/dev/null || true
    set +a
    NODE_ENV="${NODE_ENV:-}"
fi

# Step 0: Pull from remote; preserve local changes (stash uncommitted if any, then reapply).
# Only sync if NODE_ENV is set to "production"
cd "$PROJECT_ROOT"
if [ -d ".git" ]; then
    if [ "$NODE_ENV" = "production" ]; then
        echo "📥 Production environment detected (NODE_ENV=production)"
        echo "📥 Pulling from remote (local changes preserved)..."
        git fetch origin
        BRANCH=$(git rev-parse --abbrev-ref HEAD)
        STASHED=0
        if [ -n "$(git status --porcelain)" ]; then
            git stash push -u -m "deploy.sh: stash before pull"
            STASHED=1
        fi
        git pull origin "$BRANCH"
        if [ "$STASHED" = "1" ]; then
            git stash pop
        fi
        echo "✓ Repository updated from origin/$BRANCH (local changes preserved)"
    else
        echo "⚠️  Development environment detected (NODE_ENV=${NODE_ENV:-not set})"
        echo "⚠️  Skipping git sync - local changes will be preserved"
    fi
fi
echo ""

# Step 1: Deploy via nginx-microservice (with phase timing summary)
get_timestamp_seconds() { date +%s.%N; }
PHASE_TIMING_FILE=$(mktemp /tmp/deploy-phases-XXXXXX)
trap "rm -f $PHASE_TIMING_FILE" EXIT
start_phase() { local n="$1" t=$(get_timestamp_seconds); echo "$n|START|$t" >> "$PHASE_TIMING_FILE"; echo "⏱️  PHASE START: $n" >&2; }
end_phase() { local n="$1" t=$(get_timestamp_seconds); echo "$n|END|$t" >> "$PHASE_TIMING_FILE"; local sl=$(grep "^${n}|START|" "$PHASE_TIMING_FILE" | tail -1); if [ -n "$sl" ]; then local st=$(echo "$sl" | cut -d'|' -f3); local d=$(awk "BEGIN {printf \"%.2f\", $t - $st}"); echo "⏱️  PHASE END: $n (duration: ${d}s)" >&2; fi; }
print_phase_summary() {
    if [ ! -f "$PHASE_TIMING_FILE" ] || [ ! -s "$PHASE_TIMING_FILE" ]; then echo ""; echo "⚠️  No phase timing data available"; echo ""; return; fi
    echo ""; echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"; echo -e "${BLUE}📊 DEPLOYMENT PHASE TIMING SUMMARY${NC}"; echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    local cur="" st="" tot=0; while IFS='|' read -r p e ts; do
        if [ "$e" = "START" ]; then cur="$p"; st="$ts"
        elif [ "$e" = "END" ] && [ -n "$st" ] && [ -n "$cur" ]; then local d=$(awk "BEGIN {printf \"%.2f\", $ts - $st}"); tot=$(awk "BEGIN {printf \"%.2f\", $tot + $d}"); printf "  ${GREEN}%-45s${NC} ${YELLOW}%10.2fs${NC}\n" "$cur:" "$d"; cur=""; st=""; fi
    done < "$PHASE_TIMING_FILE"
    if [ "$(echo "$tot > 0" | bc 2>/dev/null || echo "0")" = "1" ]; then echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"; printf "  ${GREEN}%-45s${NC} ${YELLOW}%10.2fs${NC}\n" "Total (all phases):" "$tot"; fi
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"; echo ""
}

echo "📦 Deploying via nginx-microservice..."
cd "$NGINX_MICROSERVICE_DIR"
START_TIME=$(get_timestamp_seconds)
./scripts/blue-green/deploy-smart.sh "$SERVICE_NAME" 2>&1 | {
    build_started=0; start_containers_started=0; health_check_started=0
    while IFS= read -r line; do echo "$line"
        if echo "$line" | grep -qE "Phase 0:.*Infrastructure"; then start_phase "Phase 0: Infrastructure Check"
        elif echo "$line" | grep -qE "Phase 0 completed|✅ Phase 0 completed"; then end_phase "Phase 0: Infrastructure Check"
        elif echo "$line" | grep -qE "Phase 1:.*Preparing|Phase 1:.*Prepare"; then start_phase "Phase 1: Prepare Green Deployment"
        elif echo "$line" | grep -qE "Phase 1 completed|✅ Phase 1 completed"; then end_phase "Phase 1: Prepare Green Deployment"
        elif echo "$line" | grep -qE "Phase 2:.*Switching|Phase 2:.*Switch"; then start_phase "Phase 2: Switch Traffic to Green"
        elif echo "$line" | grep -qE "Phase 2 completed|✅ Phase 2 completed"; then end_phase "Phase 2: Switch Traffic to Green"
        elif echo "$line" | grep -qE "Phase 3:.*Monitoring|Phase 3:.*Monitor"; then start_phase "Phase 3: Monitor Health"
        elif echo "$line" | grep -qE "Phase 3 completed|✅ Phase 3 completed"; then end_phase "Phase 3: Monitor Health"
        elif echo "$line" | grep -qE "Phase 4:.*Verifying|Phase 4:.*Verify"; then start_phase "Phase 4: Verify HTTPS"
        elif echo "$line" | grep -qE "Phase 4 completed|✅ Phase 4 completed"; then end_phase "Phase 4: Verify HTTPS"
        elif echo "$line" | grep -qE "Phase 5:.*Cleaning|Phase 5:.*Cleanup"; then start_phase "Phase 5: Cleanup"
        elif echo "$line" | grep -qE "Phase 5 completed|✅ Phase 5 completed"; then end_phase "Phase 5: Cleanup"
        elif echo "$line" | grep -qE "Building containers|Image.*Building" && [ "$build_started" -eq 0 ]; then start_phase "Build Containers"; build_started=1
        elif echo "$line" | grep -qE "All services built|✅ All services built" && [ "$build_started" -eq 1 ]; then end_phase "Build Containers"; build_started=2
        elif echo "$line" | grep -qE "Starting containers|Container.*Starting" && [ "$start_containers_started" -eq 0 ]; then start_phase "Start Containers"; start_containers_started=1
        elif echo "$line" | grep -qE "Container.*Started|Waiting.*services to start" && [ "$start_containers_started" -eq 1 ]; then end_phase "Start Containers"; start_containers_started=2
        elif echo "$line" | grep -qE "Checking.*health|Health check" && [ "$health_check_started" -eq 0 ]; then start_phase "Health Checks"; health_check_started=1
        elif echo "$line" | grep -qE "health check passed|✅.*health" && [ "$health_check_started" -eq 1 ]; then end_phase "Health Checks"; health_check_started=2
        fi
    done
}
DEPLOY_EXIT_CODE=${PIPESTATUS[0]}
END_TIME=$(get_timestamp_seconds)
TOTAL_DURATION=$(awk "BEGIN {printf \"%.2f\", $END_TIME - $START_TIME}")

if [ $DEPLOY_EXIT_CODE -ne 0 ]; then
    TOTAL_DURATION_FORMATTED=$(awk "BEGIN {printf \"%.2f\", $TOTAL_DURATION}")
    echo ""; echo "❌ ${DISPLAY_NAME} deployment failed! Failed after: ${TOTAL_DURATION_FORMATTED}s"
    print_phase_summary
    exit 1
fi

TOTAL_DURATION_FORMATTED=$(awk "BEGIN {printf \"%.2f\", $TOTAL_DURATION}")
print_phase_summary 2>&1
echo "Total deployment time: ${TOTAL_DURATION_FORMATTED}s"
echo ""

# Step 2: Automatically inject Matrix location blocks
echo "🔧 Injecting Matrix location blocks..."
cd "$PROJECT_ROOT"
if [ -f "$PROJECT_ROOT/scripts/post-deploy-nginx.sh" ]; then
    if ! ./scripts/post-deploy-nginx.sh; then
        echo "⚠️  Warning: Failed to inject Matrix location blocks, but deployment succeeded"
        echo "   You may need to run ./scripts/post-deploy-nginx.sh manually"
    else
        echo "✅ Matrix location blocks injected successfully"
    fi
    
    # Step 3: Reload nginx to apply changes
    echo "🔄 Reloading nginx..."
    cd "$NGINX_MICROSERVICE_DIR"
    if ! ./scripts/reload-nginx.sh; then
        echo "⚠️  Warning: Failed to reload nginx, but deployment succeeded"
        echo "   You may need to run ./scripts/reload-nginx.sh manually"
    else
        echo "✅ Nginx reloaded successfully"
    fi
else
    echo "⚠️  Warning: post-deploy-nginx.sh not found, skipping Matrix location block injection"
fi

echo "✅ ${DISPLAY_NAME} deployment completed successfully!"
echo ""
echo "📋 Summary:"
echo "   - Service: $SERVICE_NAME"
echo "   - Domain: $DOMAIN"
echo "   - Matrix location blocks: Injected"
echo "   - Nginx: Reloaded"

