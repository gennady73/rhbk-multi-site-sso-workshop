#!/bin/bash

# =================================================================================
# Keycloak Re-Build and Configuration Script (v3.2 - Refactored)
#
# This script handles the 'kc.sh build' process for Keycloak.
# It is designed to be run manually by an administrator when build-time
# configuration changes are needed.
# =================================================================================

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
KC_HOME="/opt/keycloak"
KC_USER="keycloak"
LOG_DIR="$KC_HOME/log"
LOG_FILE="$LOG_DIR/rebuild_keycloak.log"

# Define the features to be enabled here for easy maintenance
FEATURES="hostname:v2,token-exchange,impersonation"

# Define default admin credentials here for clarity
DEFAULT_ADMIN_USER="admin"
DEFAULT_ADMIN_PASSWORD="admin"
# --- End of Configuration ---

# --- Default Values ---
FIRST_INIT=false

# --- Help Message Function ---
show_help() {
    echo "Usage: sudo ./rebuild_keycloak.sh [OPTION]"
    echo ""
    echo "This script rebuilds the Keycloak server with pre-defined features."
    echo ""
    echo "Options:"
    echo "  --first-init    Enables the one-time setting of the initial admin user using the"
    echo "                  default credentials defined inside the script."
    echo "  -h, --help      Display this help message and exit."
    echo ""
    echo "Example (first time setup):"
    echo "  sudo ./rebuild_keycloak.sh --first-init"
    echo ""
    echo "Example (a subsequent rebuild):"
    echo "  sudo ./rebuild_keycloak.sh"
}

# --- Argument Parser ---
# This loop handles the script's command-line flags
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --first-init)
        FIRST_INIT=true
        shift # past argument
        ;;
        -h|--help)
        show_help
        exit 0
        ;;
        *)    # unknown option
        echo "ERROR: Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
done

# --- Pre-flight Checks ---
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root or with sudo." 
   exit 1
fi

# --- History Logging Function ---
log_history() {
    local command_to_log=$1
    local log_message

    # Ensure log directory exists
    mkdir -p "$LOG_DIR"
    chown "$KC_USER":"$KC_USER" "$LOG_DIR"

    if [ ! -f "$LOG_FILE" ] || [ "$FIRST_INIT" = true ]; then
        echo "INFO: Build history logging is enabled. Log file is at: $LOG_FILE"
        log_message="$(date) - by user '$(whoami)' - Command: $command_to_log"
    else
        echo "INFO: Recording build change to history."
        log_message="$(date) - by user '$(whoami)' - Command: $command_to_log"
    fi

    echo "$log_message" >> "$LOG_FILE"
    chown "$KC_USER":"$KC_USER" "$LOG_FILE"
}

# --- Main Execution ---

echo "--- Preparing Keycloak Build ---"

# Build the command strings
BUILD_COMMAND_FOR_LOG="kc.sh build --features=\"$FEATURES\""
BUILD_COMMAND_FOR_EXEC="$KC_HOME/bin/kc.sh build --features=$FEATURES"

# Log the action before executing it
log_history "$BUILD_COMMAND_FOR_LOG"

# Prepare environment variables for the build command
# This variable is now empty by default
ENV_VARS=""

# Conditionally add initial admin credentials
if [ "$FIRST_INIT" = true ]; then
    echo "INFO: --first-init flag detected. Setting initial admin credentials."
    ENV_VARS+=" export KEYCLOAK_ADMIN=${DEFAULT_ADMIN_USER};"
    ENV_VARS+=" export KEYCLOAK_ADMIN_PASSWORD=${DEFAULT_ADMIN_PASSWORD};"
    #ENV_VARS+=" export JAVA_OPTS_APPEND='-Djava.net.preferIPv4Stack=true';"
fi

# Construct the final command to be run by the keycloak user
# We add the JAVA_OPTS here as it's always needed for the build.
FULL_COMMAND_TO_RUN="$ENV_VARS $BUILD_COMMAND_FOR_EXEC"

echo "Executing build as user '$KC_USER'..."

# Execute the build command as the keycloak user to maintain correct file permissions
sudo -u "$KC_USER" bash -c "$FULL_COMMAND_TO_RUN"

echo "--- Keycloak build process completed successfully. ---"
echo "Build history was recorded to the log file at: $LOG_FILE"
echo "You may now start/restart the keycloak service with 'sudo systemctl restart keycloak'."
#!/bin/bash

# =================================================================================
# Keycloak Re-Build and Configuration Script (v3.2 - Refactored)
#
# This script handles the 'kc.sh build' process for Keycloak.
# It is designed to be run manually by an administrator when build-time
# configuration changes are needed.
# =================================================================================

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
KC_HOME="/opt/keycloak"
KC_USER="keycloak"
LOG_DIR="$KC_HOME/log"
LOG_FILE="$LOG_DIR/rebuild_keycloak.log"

# Define the features to be enabled here for easy maintenance
FEATURES="hostname:v2,token-exchange,impersonation"

# Define default admin credentials here for clarity
DEFAULT_ADMIN_USER="admin"
DEFAULT_ADMIN_PASSWORD="admin"
# --- End of Configuration ---

# --- Default Values ---
FIRST_INIT=false

# --- Help Message Function ---
show_help() {
    echo "Usage: sudo ./rebuild_keycloak.sh [OPTION]"
    echo ""
    echo "This script rebuilds the Keycloak server with pre-defined features."
    echo ""
    echo "Options:"
    echo "  --first-init    Enables the one-time setting of the initial admin user using the"
    echo "                  default credentials defined inside the script."
    echo "  -h, --help      Display this help message and exit."
    echo ""
    echo "Example (first time setup):"
    echo "  sudo ./rebuild_keycloak.sh --first-init"
    echo ""
    echo "Example (a subsequent rebuild):"
    echo "  sudo ./rebuild_keycloak.sh"
}

# --- Argument Parser ---
# This loop handles the script's command-line flags
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --first-init)
        FIRST_INIT=true
        shift # past argument
        ;;
        -h|--help)
        show_help
        exit 0
        ;;
        *)    # unknown option
        echo "ERROR: Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
done

# --- Pre-flight Checks ---
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root or with sudo." 
   exit 1
fi

# --- History Logging Function ---
log_history() {
    local command_to_log=$1
    local log_message

    # Ensure log directory exists
    mkdir -p "$LOG_DIR"
    chown "$KC_USER":"$KC_USER" "$LOG_DIR"

    if [ ! -f "$LOG_FILE" ] || [ "$FIRST_INIT" = true ]; then
        echo "INFO: Build history logging is enabled. Log file is at: $LOG_FILE"
        log_message="$(date) - by user '$(whoami)' - Command: $command_to_log"
    else
        echo "INFO: Recording build change to history."
        log_message="$(date) - by user '$(whoami)' - Command: $command_to_log"
    fi

    echo "$log_message" >> "$LOG_FILE"
    chown "$KC_USER":"$KC_USER" "$LOG_FILE"
}

# --- Main Execution ---

echo "--- Preparing Keycloak Build ---"

# Build the command strings
BUILD_COMMAND_FOR_LOG="kc.sh build --features=\"$FEATURES\""
BUILD_COMMAND_FOR_EXEC="$KC_HOME/bin/kc.sh build --features=$FEATURES"

# Log the action before executing it
log_history "$BUILD_COMMAND_FOR_LOG"

# Prepare environment variables for the build command
# This variable is now empty by default
ENV_VARS=""

# Conditionally add initial admin credentials
if [ "$FIRST_INIT" = true ]; then
    echo "INFO: --first-init flag detected. Setting initial admin credentials."
    ENV_VARS+=" export KEYCLOAK_ADMIN=${DEFAULT_ADMIN_USER};"
    ENV_VARS+=" export KEYCLOAK_ADMIN_PASSWORD=${DEFAULT_ADMIN_PASSWORD};"
    #ENV_VARS+=" export JAVA_OPTS_APPEND='-Djava.net.preferIPv4Stack=true';"
fi

# Construct the final command to be run by the keycloak user
# We add the JAVA_OPTS here as it's always needed for the build.
FULL_COMMAND_TO_RUN="$ENV_VARS $BUILD_COMMAND_FOR_EXEC"

echo "Executing build as user '$KC_USER'..."

# Execute the build command as the keycloak user to maintain correct file permissions
sudo -u "$KC_USER" bash -c "$FULL_COMMAND_TO_RUN"

echo "--- Keycloak build process completed successfully. ---"
echo "Build history was recorded to the log file at: $LOG_FILE"
echo "You may now start/restart the keycloak service with 'sudo systemctl restart keycloak'."
