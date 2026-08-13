# **2.1 Service Management (systemd)**

Our first step is to configure RHBK to run as a proper, unprivileged systemd service. This is a critical security and manageability practice. We will never run the server as root.

### **The "Why": Principles**

1. **Security (Principle of Least Privilege):** We will create a dedicated system user named keycloak. This user will own the application files and run the process. If the application is ever compromised, the attacker will be "jailed" as this user, which has no sudo rights and a nologin shell, preventing them from accessing the wider system.  
2. **Manageability:** Using systemd (via a .service file) is the standard for RHEL 9\. It gives us simple, reliable commands to start, stop, restart, and check the status of our service (e.g., systemctl start keycloak).  
3. **Reliability:** We will configure the service to Restart=on-failure, so if the Keycloak Java process ever crashes, systemd will automatically restart it.  
4. **Privileged Ports without Root:** We need Keycloak to listen on the standard HTTPS port 443\. We will use the AmbientCapabilities=CAP\_NET\_BIND\_SERVICE directive. This is a modern, secure feature that grants our non-root keycloak user the *specific* capability to bind to ports below 1024, without granting any other root-level permissions.

### **Lab Task: Configure the systemd Service**

You will perform these steps on all four RHBK nodes: sso-1-a, sso-2-a, sso-1-b, and sso-2-b.

#### **1\. Create the keycloak User and Group**

First, let's create the dedicated system user and group.
```sh
# Create the keycloak group  
sudo groupadd -r keycloak

# Create the keycloak system user with a nologin shell and set its home to /opt/keycloak  
sudo useradd -r -g keycloak -d /opt/keycloak -s /sbin/nologin keycloak

echo "User and group 'keycloak' created."
```
#### **2\. Create the Automation Script and Template**

We will use a simple shell script to automate the setup. This script will copy a template file into the correct systemd directory.

First, create the service file template.

**File: [keycloak.service.template](../assets/keycloak.service.template)**
```ini
[Unit]  
Description=Red Hat Build of Keycloak Server  
After=network.target

[Service]  
Type=idle  
User=keycloak  
Group=keycloak  
# We only use the 'start' command; the 'build' is a separate, manual process  
ExecStart=/opt/keycloak/bin/kc.sh start --optimized  
WorkingDirectory=/opt/keycloak  
TimeoutStartSec=600  
TimeoutStopSec=600  
Restart=on-failure  
# This is the magic for binding to port 443 without root  
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]  
WantedBy=multi-user.target
```
Next, create the setup script that will use this template.

**File: [setup_keycloak_service.sh](../assets/setup_keycloak_service.sh)**
```sh
#!/bin/bash

set -e

KC_USER="keycloak"
KC_GROUP="keycloak"
KC_HOME="/opt/keycloak"
SERVICE_FILE_PATH="/etc/systemd/system/keycloak.service"
TEMPLATE_FILE="./keycloak.service.template" # Assumes template is in the same directory

echo "--- Creating Keycloak user and group ---"
if ! getent group "$KC_GROUP" > /dev/null; then
    sudo groupadd -r "$KC_GROUP"
    echo "Group '$KC_GROUP' created."
else
    echo "Group '$KC_GROUP' already exists."
fi

if ! id "$KC_USER" > /dev/null 2>&1; then
    sudo useradd -r -g "$KC_GROUP" -d "$KC_HOME" -s /sbin/nologin "$KC_USER"
    echo "User '$KC_USER' created."
else
    echo "User '$KC_USER' already exists."
fi

echo "--- Setting ownership of $KC_HOME ---"
sudo chown -R "$KC_USER":"$KC_GROUP" "$KC_HOME"
echo "Ownership set to $KC_USER:$KC_GROUP."

echo "--- Creating systemd service file from template ---"
if [ -f "$TEMPLATE_FILE" ]; then
    sudo cp "$TEMPLATE_FILE" "$SERVICE_FILE_PATH"
    echo "Service file created at $SERVICE_FILE_PATH."
else
    echo "ERROR: Template file '$TEMPLATE_FILE' not found."
    exit 1
fi

echo "--- Reloading systemd daemon and enabling service ---"
sudo systemctl daemon-reload
sudo systemctl enable keycloak.service

echo "--- Setup Complete ---"
echo "You can now manage the service with the following commands:"
echo "sudo systemctl start keycloak"
echo "sudo systemctl stop keycloak"
echo "sudo systemctl restart keycloak"
echo "sudo systemctl status keycloak"
echo "journalctl -u keycloak.service -f"
```
#### **3\. Run the Automation Script**

1. Place both keycloak.service.template and setup\_keycloak\_service.sh in the same directory on your node (e.g., in your user's home directory).  
2. Make the script executable:  
   ```sh
   chmod +x setup_keycloak_service.sh
   ```
3. Run the script:   
   ```sh
   sudo ./setup_keycloak_service.sh
   ```

#### **4\. Verification**

After the script runs, verify that the service is enabled and ready.
```sh
    sudo systemctl status keycloak
```
You should see output indicating that the service is disabled (or inactive (dead)) but enabled. This is correct. It is now ready to be started, but we will not start it until we have created our build script, certificates, and configuration file in the next sections.

**Repeat these steps on all four RHBK nodes.**