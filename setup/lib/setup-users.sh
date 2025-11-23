#!/bin/bash
# setup-users.sh - User and group management functions
# Library directory
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${LIB_DIR}/setup-common.sh"

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo "ERROR: Do not run this script with sudo or as root!"
        echo "The script will request sudo permissions when needed."
        echo ""
        echo "Please run: ./setup.sh"
        exit 1
    fi
}

# Get Docker group GID
get_docker_gid() {
    local gid
    gid=$(getent group docker | cut -d: -f3)
    
    if [ -n "$gid" ]; then
        echo "$gid"
    else
        # Fallback if docker group doesn't exist or command failed
        echo "0"
    fi
}

# Export functions
export -f check_root
export -f get_docker_gid
