#!/bin/bash
# setup-docker.sh - Docker utility functions
# Library directory
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${LIB_DIR}/setup-common.sh"

# Run docker compose up with validation (atomic, reusable)
# Usage: run_docker_compose_up "/path/to/docker/dir"
# Returns: 0 if success, 1 if failed
run_docker_compose_up() {
    local compose_dir="$1"

    cd "$compose_dir" || return 1
    # Export critical variables to ensure they are available to docker compose
    export MEDIACENTER_GID="${MEDIACENTER_GID:-0}"
    ./up.sh
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        log_error "Docker Compose failed to start services (exit code: $exit_code)" >&2
        return 1
    fi

    return 0
}

# Validate that ONE docker service is running (atomic, call N times)
# Usage: validate_docker_service "service_name"
# Returns: 0 if running, 1 if not running
validate_docker_service() {
    local service_name="$1"

    if docker ps --format "{{.Names}}" | grep -q "^${service_name}$"; then
        return 0
    else
        return 1
    fi
}

# Get docker container health status (atomic, call N times)
# Usage: get_docker_health_status "container_name" "output_var"
get_docker_health_status() {
    local container_name="$1"
    local output_var="$2"
    local status

    status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")

    eval "$output_var='$status'"
}

# Wait for docker container to be healthy (atomic, call N times)
# Usage: wait_for_docker_health "container_name" "max_attempts" "sleep_seconds"
# Returns: 0 if healthy, 1 if timeout
wait_for_docker_health() {
    local container_name="$1"
    local max_attempts="${2:-60}"
    local sleep_seconds="${3:-2}"
    local attempt=1
    local status

    echo -n "Waiting for $container_name to be ready"
    while [ $attempt -le $max_attempts ]; do
        status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
        if [ "$status" = "healthy" ]; then
            echo " ✓"
            return 0
        fi
        echo -n "."
        sleep $sleep_seconds
        attempt=$((attempt + 1))
    done
    echo " ✗ (timeout)"
    return 1
}

# Export functions
export -f run_docker_compose_up
export -f validate_docker_service
export -f get_docker_health_status
export -f wait_for_docker_health
