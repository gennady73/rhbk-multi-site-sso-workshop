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
