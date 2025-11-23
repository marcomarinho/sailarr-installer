#!/bin/bash
# setup-common.sh - Common utility functions
# Provides basic utilities used across the setup process

# Colors for output
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_MAGENTA='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_RESET='\033[0m'

# Setup logging
# Only initialize if not already set (allows sharing log dir across scripts)
if [ -z "$SETUP_LOG_DIR" ]; then
    export SETUP_LOG_DIR="/tmp/sailarr-install-$(date +%Y%m%d-%H%M%S)"
fi
export SETUP_LOG_FILE="${SETUP_LOG_DIR}/install.log"
export SETUP_TRACE_FILE="${SETUP_LOG_DIR}/trace.log"

# Initialize logging
init_logging() {
    mkdir -p "${SETUP_LOG_DIR}"
    touch "${SETUP_LOG_FILE}"
    touch "${SETUP_TRACE_FILE}"

    echo "=== Sailarr Installer - Installation Log ===" | tee -a "${SETUP_LOG_FILE}"
    echo "Started at: $(date)" | tee -a "${SETUP_LOG_FILE}"
    echo "Log directory: ${SETUP_LOG_DIR}" | tee -a "${SETUP_LOG_FILE}"
    echo "" | tee -a "${SETUP_LOG_FILE}"

    log_info "Installation logs will be saved to: ${SETUP_LOG_DIR}"
}

# Log to file (without colors)
log_to_file() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "${SETUP_LOG_FILE}"
}

# Function trace logging
log_trace() {
    local func_name=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [TRACE] ${func_name}: ${message}" >> "${SETUP_TRACE_FILE}"
}

# Function entry/exit logging
log_function_enter() {
    local func_name=$1
    shift
    local params="$@"
    log_trace "${func_name}" "ENTER with params: ${params}"
}

log_function_exit() {
    local func_name=$1
    local exit_code=$2
    local output="${3:-}"
    log_trace "${func_name}" "EXIT with code ${exit_code}${output:+, output: ${output}}"
}

# Logging functions (console + file)
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1" >&2
    log_to_file "INFO" "$1"
}

log_success() {
    echo -e "${COLOR_GREEN}[✓]${COLOR_RESET} $1" >&2
    log_to_file "SUCCESS" "$1"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1" >&2
    log_to_file "WARNING" "$1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1" >&2
    log_to_file "ERROR" "$1"
}

log_debug() {
    echo -e "${COLOR_CYAN}[DEBUG]${COLOR_RESET} $1" >&2
    log_to_file "DEBUG" "$1"
}

log_section() {
    echo "" >&2
    echo "=========================================" >&2
    echo "$1" >&2
    echo "=========================================" >&2
    echo "" >&2
    log_to_file "SECTION" "$1"
}

log_operation() {
    local operation=$1
    shift
    local details="$@"
    echo -e "${COLOR_MAGENTA}[OP]${COLOR_RESET} ${operation}: ${details}" >&2
    log_to_file "OPERATION" "${operation}: ${details}"
}

# Wait for a service to be healthy
wait_for_service() {
    log_function_enter "wait_for_service" "$@"

    local service_name=$1
    local port=$2
    local timeout=${3:-300}  # Default 5 minutes
    local endpoint=${4:-""}

    log_info "Waiting for $service_name to be ready..."
    log_debug "Timeout: ${timeout}s, Port: ${port}, Endpoint: ${endpoint:-none}"

    local elapsed=0
    local interval=2

    while [ $elapsed -lt $timeout ]; do
        log_trace "wait_for_service" "Checking health of $service_name (elapsed: ${elapsed}s)"

        # Check if container is healthy using docker inspect (same as original setup.sh)
        if [ "$(docker inspect -f '{{.State.Health.Status}}' "$service_name" 2>/dev/null)" = "healthy" ]; then
            log_success "$service_name is healthy"
            log_function_exit "wait_for_service" 0 "healthy after ${elapsed}s"
            return 0
        fi

        sleep $interval
        elapsed=$((elapsed + interval))

        if [ $((elapsed % 30)) -eq 0 ]; then
            log_info "Still waiting for $service_name... (${elapsed}s elapsed)"
        fi
    done

    log_error "$service_name failed to become healthy after ${timeout}s"
    log_function_exit "wait_for_service" 1 "timeout"
    return 1
}

# Check if a port is listening
check_port() {
    local port=$1
    netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "
}

# Retry a command with exponential backoff
retry_command() {
    local max_attempts=$1
    shift
    local command="$@"
    local attempt=1
    local delay=2

    while [ $attempt -le $max_attempts ]; do
        if eval "$command"; then
            return 0
        fi

        if [ $attempt -lt $max_attempts ]; then
            log_warning "Command failed (attempt $attempt/$max_attempts). Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))  # Exponential backoff
        fi

        attempt=$((attempt + 1))
    done

    log_error "Command failed after $max_attempts attempts"
    return 1
}

# Validate that a variable is not empty
validate_required() {
    local var_name=$1
    local var_value=$2

    if [ -z "$var_value" ]; then
        log_error "$var_name is required but not set"
        return 1
    fi
    return 0
}

# Validate directory exists
validate_directory() {
    local dir=$1

    if [ ! -d "$dir" ]; then
        log_error "Directory does not exist: $dir"
        return 1
    fi
    return 0
}

# Create directory with proper permissions
create_directory() {
    local dir=$1
    local owner=$2
    local mode=${3:-755}

    if [ ! -d "$dir" ]; then
        sudo mkdir -p "$dir"
        if [ -n "$owner" ]; then
            sudo chown "$owner" "$dir"
        fi
        sudo chmod "$mode" "$dir"
        log_success "Created directory: $dir"
    fi
}

# Export functions
export -f init_logging
export -f log_to_file
export -f log_trace
export -f log_function_enter
export -f log_function_exit
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_debug
export -f log_section
export -f log_operation
export -f wait_for_service
export -f check_port
export -f retry_command
export -f validate_required
export -f validate_directory
export -f create_directory

# Ask user for input with standard format
# Usage: ask_user_input "title" "description" "prompt" "default_value" "required" "output_var"
ask_user_input() {
    local title="$1"
    local description="$2"
    local prompt="$3"
    local default_value="$4"
    local required="$5"
    local output_var="$6"

    if [ -n "$title" ]; then
        echo "$title"
        echo "$(printf '%*s' ${#title} '' | tr ' ' '-')"
    fi

    if [ -n "$description" ]; then
        echo "$description"
    fi

    if [ -n "$default_value" ]; then
        echo "Current default: $default_value"
    fi

    read -p "$prompt" user_input

    # Apply default if empty
    user_input="${user_input:-$default_value}"

    # Validate if required
    if [ "$required" = "true" ]; then
        while [ -z "$user_input" ]; do
            echo "ERROR: This field is required!"
            read -p "$prompt" user_input
            user_input="${user_input:-$default_value}"
        done
    fi

    echo ""

    # Store in output variable
    eval "$output_var='$user_input'"
}

# Ask user for password (hidden input)
# Usage: ask_password "prompt" "required" "output_var"
ask_password() {
    local prompt="$1"
    local required="$2"
    local output_var="$3"

    read -sp "$prompt" user_password
    echo ""

    # Validate if required
    if [ "$required" = "true" ]; then
        while [ -z "$user_password" ]; do
            echo "ERROR: This field is required!"
            read -sp "$prompt" user_password
            echo ""
        done
    fi

    # Store in output variable
    eval "$output_var='$user_password'"
}

# Create folder with permissions (atomic, reusable)
# Usage: create_folder "/path/to/folder" "owner:group" "permissions"
create_folder() {
    local folder_path="$1"
    # owner arg ignored
    local permissions="${3:-755}"

    mkdir -p "$folder_path"
    chmod "$permissions" "$folder_path"
}

# Set permissions on path (atomic, reusable)
# Usage: set_permissions "/path" "permissions" "owner:group"
set_permissions() {
    local path="$1"
    local permissions="$2"
    # owner arg ignored as we use current user

    if [ -n "$permissions" ]; then
        chmod -R "$permissions" "$path"
    fi
}

# Copy file with permissions (atomic, reusable)
# Usage: copy_file "source" "destination" "owner:group" "permissions"
copy_file() {
    local source="$1"
    local destination="$2"
    # owner arg ignored
    local permissions="${4:-}"

    cp "$source" "$destination"

    if [ -n "$permissions" ]; then
        chmod "$permissions" "$destination"
    fi
}

# Download file from URL with permissions (atomic, reusable)
# Usage: download_file "url" "destination" "owner:group" "permissions"
download_file() {
    local url="$1"
    local destination="$2"
    # owner arg ignored
    local permissions="${4:-}"

    local temp_file="/tmp/download-$$-$(basename "$destination")"

    curl -sL "$url" -o "$temp_file"
    cp "$temp_file" "$destination"
    rm -f "$temp_file"

    if [ -n "$permissions" ]; then
        chmod "$permissions" "$destination"
    fi
}

# Create file from content with permissions (atomic, reusable)
# Usage: create_file_from_content "destination" "content" "owner:group" "permissions"
create_file_from_content() {
    local destination="$1"
    local content="$2"
    # owner arg ignored
    local permissions="${4:-}"

    echo "$content" | tee "$destination" > /dev/null

    if [ -n "$permissions" ]; then
        chmod "$permissions" "$destination"
    fi
}

# Append content to file (atomic, reusable)
# Usage: append_to_file "file_path" "content"
append_to_file() {
    local file_path="$1"
    local content="$2"

    echo "$content" >> "$file_path"
}

export -f ask_user_input
export -f ask_password
export -f create_folder
export -f set_permissions
export -f copy_file
export -f download_file
export -f create_file_from_content
export -f append_to_file
