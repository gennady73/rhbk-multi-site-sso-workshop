#!/bin/bash
# ==============================================================================
# GSLB Health Check and Dynamic DNS Update Script for Keycloak Multi-Site
# Version 3.0 (Production Hardened Dynamic DNS with RFC 2136 nsupdate)
#
# This script runs on the GSLB/BIND VM in Site Zero. It checks the health
# of the active site's load balancer and dynamically updates the BIND DNS record
# using standard nsupdate (RFC 2136) instead of dangerous local file edits.
# ==============================================================================

# --- Configuration ---
DOMAIN="mydomain.com"
SUBDOMAIN="sso"
PUBLIC_HOSTNAME="sso.mydomain.com"

# The TSIG / RNDC Key file for authenticating nsupdate dynamic actions securely
RNDC_KEY="/etc/rndc.key"
DNS_SERVER="127.0.0.1"

# IPs of the Site-Local Load Balancers
PRIMARY_IP="10.10.1.10"   # Example Site A LB IP
SECONDARY_IP="10.20.1.10" # Example Site B LB IP

HEALTH_CHECK_PATH="/auth/health/ready"
FAILURE_THRESHOLD=3

LOG_FILE="/var/log/gslb_check.log"
STATE_FILE="/var/tmp/gslb_state.txt"
LOCK_FILE="/var/tmp/gslb_check.lock"

# --- End of Configuration ---

# Single Instance Lock Execution
if [ -e "$LOCK_FILE" ]; then
    echo "$(date): Lock file exists, another instance is running. Exiting." >> "$LOG_FILE"
    exit 1
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Resolve current IP using BIND directly to ensure no caching interference
get_current_ip() {
    dig @$DNS_SERVER +short "$PUBLIC_HOSTNAME" | tail -n1
}

# Dynamic, Atomic DNS Switch via RFC 2136 nsupdate
perform_dns_switch() {
    local OLD_IP=$1
    local NEW_IP=$2
    
    log "PERFORMING ATOMIC DNS SWITCH: Changing $PUBLIC_HOSTNAME from $OLD_IP to $NEW_IP"
    
    # Construct nsupdate instructions to cleanly purge the old A record and insert the new one
    # We enforce a low TTL of 5 seconds to bypass resolver caching.
    nsupdate_cmds=$(cat <<EOF
server $DNS_SERVER
zone $DOMAIN
update delete $PUBLIC_HOSTNAME A
update add $PUBLIC_HOSTNAME 5 A $NEW_IP
send
EOF
)

    if echo "$nsupdate_cmds" | nsupdate -k "$RNDC_KEY" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS: Atomic Dynamic DNS update applied successfully via nsupdate."
    else
        log "ERROR: Dynamic DNS update failed. BIND zone changes aborted."
    fi
}

# Initialize State File
[[ -f "$STATE_FILE" ]] || echo "0" > "$STATE_FILE"
FAILURE_COUNT=$(cat "$STATE_FILE")

CURRENT_IP=$(get_current_ip)
if [ -z "$CURRENT_IP" ]; then
    log "CRITICAL ERROR: No IP resolved for $PUBLIC_HOSTNAME. Defaulting to PRIMARY_IP: $PRIMARY_IP"
    CURRENT_IP=$PRIMARY_IP
fi

log "Current active resolution is $CURRENT_IP. Failure count: $FAILURE_COUNT."

# Health Check Routing Engine
if [ "$CURRENT_IP" == "$PRIMARY_IP" ]; then
    log "Checking PRIMARY site-local load balancer at $PRIMARY_IP..."
    if ! curl -s --fail -o /dev/null -k --connect-timeout 5 --resolve "$PUBLIC_HOSTNAME:443:$PRIMARY_IP" "https://$PUBLIC_HOSTNAME$HEALTH_CHECK_PATH"; then
        log "PRIMARY site check FAILED."
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        echo "$FAILURE_COUNT" > "$STATE_FILE"
        
        if [ "$FAILURE_COUNT" -ge "$FAILURE_THRESHOLD" ]; then
            log "FAILURE THRESHOLD REACHED. Failing over to SECONDARY site: $SECONDARY_IP."
            perform_dns_switch "$PRIMARY_IP" "$SECONDARY_IP"
            echo "0" > "$STATE_FILE"
        fi
    else
        log "PRIMARY site check PASSED."
        echo "0" > "$STATE_FILE"
    fi
else
    log "Checking SECONDARY site-local load balancer at $SECONDARY_IP..."
    if ! curl -s --fail -o /dev/null -k --connect-timeout 5 --resolve "$PUBLIC_HOSTNAME:443:$SECONDARY_IP" "https://$PUBLIC_HOSTNAME$HEALTH_CHECK_PATH"; then
        log "SECONDARY site check FAILED. Both PRIMARY and SECONDARY are offline!"
    else
        log "SECONDARY site check PASSED. Probing if PRIMARY is ready to failback..."
        if curl -s --fail -o /dev/null -k --connect-timeout 5 --resolve "$PUBLIC_HOSTNAME:443:$PRIMARY_IP" "https://$PUBLIC_HOSTNAME$HEALTH_CHECK_PATH"; then
            log "PRIMARY site is healthy. Initiating automatic failback."
            perform_dns_switch "$SECONDARY_IP" "$PRIMARY_IP"
            echo "0" > "$STATE_FILE"
        else
            log "PRIMARY is still down. Maintaining routing on SECONDARY."
        fi
    fi
fi

log "--- Health Check Run Completed ---"