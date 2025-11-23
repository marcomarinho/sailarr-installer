#!/bin/bash
# optimize-plex-db.sh - Optimize Plex SQLite Database
# This script stops Plex, backs up the database, and runs optimization commands.

# Set error handling
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
DOCKER_DIR="${ROOT_DIR}/docker"
PLEX_DB_PATH="/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo)"
    exit 1
fi

log_info "Starting Plex Database Optimization..."

# 1. Stop Plex
log_info "Stopping Plex container..."
cd "$DOCKER_DIR"
docker compose stop plex

# 2. Backup Database
log_info "Backing up database..."
# We use a temporary container to access the volume if needed, but since we have root access
# and know the path, we can try to find the volume path. However, using docker cp is safer/easier.
# But docker cp requires the container to exist (stopped is fine).

# Create backup using a temporary container mounting the volume
# This ensures we don't mess with permissions on the host
docker run --rm \
    --volumes-from plex \
    -v "${ROOT_DIR}/backup:/backup" \
    alpine sh -c "
        mkdir -p /backup/plex-db-$(date +%Y%m%d-%H%M%S) && \
        cp \"$PLEX_DB_PATH\" \"/backup/plex-db-$(date +%Y%m%d-%H%M%S)/com.plexapp.plugins.library.db\" && \
        echo 'Backup created successfully'
    "

# 3. Optimize Database
log_info "Running optimization (Vacuum & Analyze)..."
# We use the Plex image itself to run the optimization tools
# This ensures we have the correct version of sqlite/Plex Media Server binary
docker run --rm \
    --volumes-from plex \
    --entrypoint "/usr/lib/plexmediaserver/Plex Media Server" \
    lscr.io/linuxserver/plex:latest \
    --sqlite "$PLEX_DB_PATH" "pragma page_size=32768; vacuum; pragma default_cache_size = 20000000;"

log_info "Optimization completed."

# 4. Start Plex
log_info "Starting Plex container..."
docker compose start plex

log_info "Plex Database Optimization finished successfully!"
