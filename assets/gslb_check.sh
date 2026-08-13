#!/bin/bash

# ==============================================================================
# GSLB Health Check and DNS Failover Script for Keycloak Multi-Site
# Version 2.2 (Adapted for Workshop)
#
# This script runs on the GSLB/BIND VM in Site Zero. It checks the health
# of the active site's load balancer and updates the DNS A record for
# 'sso.mydomain.com' to point to the healthy site.
# ==============================================================================

# --- Configuration ---
# All user-configurable variables are in this section.

# DNS and Zone File Configuration
ZONE_FILE="/var/named/mydomain.com.zone"
DOMAIN="mydomain.com"
SUBDOMAIN="sso"
RNDC_KEY="/etc/rndc.key"

# Public FQDN and IPs of the Site Load Balancers
PUBLIC_HOSTNAME="sso.mydomain.com"
PRIMARY_IP="<Public_IP_of_sso-lb-a>"    # Site A IP
SECONDARY_IP="<Public_IP_of_sso-lb-b>"  # Site B IP

# Health Check Configuration
HEALTH_CHECK_PATH="/auth" # Path to check for a successful HTTP 2xx response
FAILURE_THRESHOLD=3       # Number of consecutive failures to trigger a failover

# System Files
LOG_FILE="/var/log/gslb_check.log"
STATE_FILE="/var/tmp/gslb_state.txt" # Stores failure counts between runs
LOCK_FILE="/var/tmp/gslb_check.lock"
# --- End of Configuration ---


# --- Script Logic ---

# Ensure only one instance of the script runs at a time
if [ -e "$LOCK_FILE" ]; then
    echo "$(date): Lock file exists, another instance is running. Exiting." >> "$LOG_FILE"
    exit 1
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT # Remove lock file when script exits

# Logging function
log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Robust function to get the current IP address
# It checks both 4th and 5th columns to handle zone files with
# or without an explicit TTL on the record line.
get_current_ip() {
    local line
    line=$(grep -E "^\s*$SUBDOMAIN\s+" "$ZONE_FILE")
    
    if [ -z "$line" ]; then
        echo "" # Return empty if no line found
        return
    fi
    
    # Check if the 4th column is a valid IP
    local ip_guess
    ip_guess=$(echo "$line" | awk '{print $4}')
    if [[ "$ip_guess" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip_guess"
        return
    fi
    
    # If not, check if the 5th column is a valid IP
    ip_guess=$(echo "$line" | awk '{print $5}')
    if [[ "$ip_guess" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip_guess"
        return
    fi

    echo "" # Return empty if no valid IP found
}

# Function to perform the actual zone update and reload
perform_dns_switch() {
    local OLD_IP=$1
    local NEW_IP=$2

    log "PERFORMING DNS SWITCH: Changing $OLD_IP to $NEW_IP"

    # 1. Get the current serial number from the zone file
    local CURRENT_SERIAL=$(grep -oP '\d{10}' "$ZONE_FILE")
    local TODAY_SERIAL=$(date +%Y%m%d00)

    # 2. Calculate the new serial number (YYYYMMDDNN format)
    if [[ "$CURRENT_SERIAL" -lt "$TODAY_SERIAL" ]]; then
        NEW_SERIAL=$TODAY_SERIAL
    else
        NEW_SERIAL=$((CURRENT_SERIAL + 1))
    fi
    log "Updating serial from $CURRENT_SERIAL to $NEW_SERIAL"

    # 3. Update the A record and the serial number in the zone file
    # This sed command is robust enough to handle tabs or spaces
    sudo sed -i -e "s/$SUBDOMAIN\s\+IN\s\+A\s\+$OLD_IP/$SUBDOMAIN\t\tIN\tA\t$NEW_IP/" \
               -e "s/$CURRENT_SERIAL/$NEW_SERIAL/" "$ZONE_FILE"

    # 4. Tell BIND to reload the zone configuration
    if sudo rndc -k "$RNDC_KEY" reload "$DOMAIN"; then
        log "SUCCESS: BIND successfully reloaded zone '$DOMAIN'."
    else
        log "ERROR: BIND reload failed for zone '$DOMAIN'."
    fi
}

# --- Main Execution ---

log "--- Starting Health Check ---"

# Create state file if it doesn't exist
[[ -f "$STATE_FILE" ]] || echo "0" > "$STATE_FILE"
FAILURE_COUNT=$(cat "$STATE_FILE")

# Call the function to determine the current IP
CURRENT_IP=$(get_current_ip)

if [ -z "$CURRENT_IP" ]; then
    log "CRITICAL ERROR: Could not parse a valid IP for '$SUBDOMAIN' from '$ZONE_FILE'. Please check the zone file format. Exiting."
    exit 1
fi
log "Current active IP is $CURRENT_IP. Failure count is $FAILURE_COUNT."

# Check if the PRIMARY site is the currently active one
if [ "$CURRENT_IP" == "$PRIMARY_IP" ]; then
    # Perform health check on the PRIMARY site
    log "Checking PRIMARY site at $PRIMARY_IP..."
    if ! curl -s --fail -o /dev/null -k --connect-timeout 5 --resolve "$PUBLIC_HOSTNAME:443:$PRIMARY_IP" "https://$PUBLIC_HOSTNAME$HEALTH_CHECK_PATH"; then
        log "PRIMARY site check FAILED."
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        echo "$FAILURE_COUNT" > "$STATE_FILE"
        if [ "$FAILURE_COUNT" -ge "$FAILURE_THRESHOLD" ]; then
            log "FAILURE THRESHOLD REACHED. Failing over to SECONDARY site."
            perform_dns_switch "$PRIMARY_IP" "$SECONDARY_IP"
            echo "0" > "$STATE_FILE" # Reset counter after switch
        fi
    else
        log "PRIMARY site check PASSED."
        echo "0" > "$STATE_FILE" # Reset counter on success
    fi
# Else, the SECONDARY site is the currently active one
else
    # Perform health check on the SECONDARY site to ensure it's still up
    log "Checking SECONDARY site at $SECONDARY_IP..."
    if ! curl -s --fail -o /dev/null -k --connect-timeout 5 --resolve "$PUBLIC_HOSTNAME:443:$SECONDARY_IP" "https://$PUBLIC_HOSTNAME$HEALTH_CHECK_PATH"; then
        log "SECONDARY site check FAILED. This is a double failure scenario. Taking no action."
        # In a real-world scenario, you would add alerting here.
    else
        log "SECONDARY site check PASSED. Now checking if PRIMARY is back online..."
        # The secondary is up, but let's check if we can fail back to the primary
        if curl -s --fail -o /dev/null -k --connect-timeout 5 --resolve "$PUBLIC_HOSTNAME:443:$PRIMARY_IP" "https://sso.mydomain.com$HEALTH_CHECK_PATH"; then
            log "PRIMARY site is back online. Failing back."
            perform_dns_switch "$SECONDARY_IP" "$PRIMARY_IP"
            echo "0" > "$STATE_FILE" # Reset counter after switch
        else
            log "PRIMARY site is still down. Remaining on SECONDARY."
        fi
    fi
fi

log "--- Health Check Finished ---"
