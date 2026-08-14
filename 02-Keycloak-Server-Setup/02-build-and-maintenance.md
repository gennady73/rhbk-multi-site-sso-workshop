# **2.2 Build and Maintenance (rebuild_keycloak.sh) (v26.2/v26.6 Production-Hardened Guide)**

In the previous step, we configured a systemd service to run Keycloak. You will notice that the `ExecStart` line contains the `kc.sh start --optimized` command. It is intentionally missing the `kc.sh build` command. This separation represents a core professional practice in enterprise identity systems.

---

### **The "Why": Separating Build from Run**

Think of your Keycloak server like a high-performance compiled application. 
*   **`kc.sh build`** represents the "compilation" or "optimization" step. It analyzes your configuration properties, compiles your active themes, optimizes database drivers, and builds a lean, optimized server runtime. This process is slow, resource-heavy, and should only be done once when the build-time configuration changes (such as adding custom SPIs or changing feature flags).
*   **`kc.sh start`** is the execution step. It runs the fast, pre-optimized server runtime. 

By separating these two actions, our systemd service can restart in seconds (since it performs a pure start task), rather than taking up to a minute (which occurs if it has to run a build task on every boot). 

To manage this lifecycle securely and repeatably, we utilize a dedicated script for administrative build tasks. This script provides an auditable, logged, and repeatable way to apply build-time configurations across our RHEL 9 virtual machines.

---

### **Lab Task: Create the rebuild_keycloak.sh Script**

You will perform these steps on **all four** RHBK nodes: `sso-1-a`, `sso-2-a`, `sso-1-b`, and `sso-2-b`.

#### **1. Create the Script File ([rebuild_keycloak.sh](../assets/rebuild_keycloak.sh))**

We will create the [rebuild_keycloak.sh](../assets/rebuild_keycloak.sh) script inside the `/opt/keycloak/bin/` directory. This script is engineered to:
*   Be owned by the `keycloak` user to maintain strict file permissions.
*   Be run with root privileges via `sudo` by an administrator.
*   Include standard help prompts for usability.
*   Handle the `--first-init` flag to set the initial admin user (when working with an empty database).
*   Run the actual build process safely as the `keycloak` user.
*   Log every execution to `/opt/keycloak/log/rebuild_keycloak.log` for audit trails.

Create the file at `/opt/keycloak/bin/rebuild_keycloak.sh` with the following optimized contents (ensuring that the deprecated `hostname:v2` feature is removed for Keycloak 26 compatibility):

```bash
#!/bin/bash
# =================================================================================
# Keycloak Re-Build and Configuration Script (v26.x Production-Hardened)
# =================================================================================
set -e

# --- Configuration ---
KC_HOME="/opt/keycloak"
KC_USER="keycloak"
LOG_DIR="$KC_HOME/log"
LOG_FILE="$LOG_DIR/rebuild_keycloak.log"

# Define the features to be enabled here (removed deprecated hostname:v2)
FEATURES="token-exchange,impersonation"

# Define default admin credentials for lab bootstrapping
DEFAULT_ADMIN_USER="admin"
DEFAULT_ADMIN_PASSWORD="admin"

# --- Default Values ---
FIRST_INIT=false

show_help() {
    echo "Usage: sudo ./rebuild_keycloak.sh [OPTION]"
    echo ""
    echo "This script rebuilds the Keycloak server with pre-defined features."
    echo ""
    echo "Options:"
    echo "  --first-init   Enables one-time initial admin user creation using"
    echo "                 the default credentials defined inside this script."
    echo "  -h, --help     Display this help message and exit."
    echo ""
    echo "Example (first time setup):"
    echo "  sudo ./rebuild_keycloak.sh --first-init"
    echo ""
    echo "Example (subsequent rebuild):"
    echo "  sudo ./rebuild_keycloak.sh"
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --first-init)
            FIRST_INIT=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root or with sudo."
    exit 1
fi

log_history() {
    local command_to_log=$1
    local log_message
    mkdir -p "$LOG_DIR"
    chown "$KC_USER":"$KC_USER" "$LOG_DIR"
    
    log_message="$(date) - by user '$(whoami)' - Command: $command_to_log"
    echo "$log_message" >> "$LOG_FILE"
    chown "$KC_USER":"$KC_USER" "$LOG_FILE"
}

echo "--- Preparing Keycloak Build ---"
BUILD_COMMAND_FOR_LOG="kc.sh build --features=\"$FEATURES\""
BUILD_COMMAND_FOR_EXEC="$KC_HOME/bin/kc.sh build --features=$FEATURES"

log_history "$BUILD_COMMAND_FOR_LOG"

ENV_VARS=""
if [ "$FIRST_INIT" = true ]; then
    echo "INFO: --first-init flag detected. Injecting initial admin credentials."
    ENV_VARS+="export KEYCLOAK_ADMIN=${DEFAULT_ADMIN_USER}; export KEYCLOAK_ADMIN_PASSWORD=${DEFAULT_ADMIN_PASSWORD};"
fi

# Append JVM virtual threads lockup mitigation setting for JDK 21 stability
ENV_VARS+=" export JAVA_OPTS_APPEND='-Dorg.infinispan.threads.virtual=false';"

FULL_COMMAND_TO_RUN="$ENV_VARS $BUILD_COMMAND_FOR_EXEC"

echo "Executing build as user '$KC_USER'..."
sudo -u "$KC_USER" bash -c "$FULL_COMMAND_TO_RUN"

echo "--- Keycloak build process completed successfully. ---"
echo "Build history was recorded to the log file at: $LOG_FILE"
echo "You may now restart the service with: 'sudo systemctl restart keycloak'"
```

#### **2. Set Permissions for the Script**

After creating the file, enforce secure, unprivileged file ownership and execution bounds:

```sh
# Set ownership to the keycloak user
sudo chown keycloak:keycloak /opt/keycloak/bin/rebuild_keycloak.sh

# Make it executable only by the owner (keycloak) and root (via sudo)
sudo chmod 750 /opt/keycloak/bin/rebuild_keycloak.sh
```

#### **3. Run the Initial Build**

Run the build script for the first time. Because this is the initial database bootstrapping phase, you must append the `--first-init` flag to register the credentials:

```sh
sudo /opt/keycloak/bin/rebuild_keycloak.sh --first-init
```

The script will configure your features, apply JVM optimizations, and compile the optimized runtime. This takes approximately 20-30 seconds.

#### **4. Verification**

After the script completes successfully, verify that the audit log was recorded correctly:

```sh
cat /opt/keycloak/log/rebuild_keycloak.log
```

You should see a clean log entry tracking the timestamp, execution user, and build commands.

**Repeat these steps on all four RHBK nodes.**