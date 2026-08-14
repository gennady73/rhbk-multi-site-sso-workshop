# **3.2 Lab: Re-configuring RHBK to Use an External Cache**
##### (v26.2/v26.6 Production-Hardened Guide)

Now that our external Infinispan cluster is running, we must reconfigure our Keycloak (RHBK) nodes to connect to it. This process involves offloading the cross-site replication layer by removing the embedded native clustering configurations from `keycloak.conf` and replacing them with client-side settings that point directly to our standalone external Infinispan nodes (Path B).

---

### **The "Why": Decoupled Cache Client Mechanics**

By offloading the session caching tier, Keycloak nodes become stateless application servers. To enable this connection model in Keycloak 26, two key configurations are required:

1.  **The `multi-site` Build Feature:** Keycloak's remote cache client properties (`cache-remote-*`) are locked behind build-time feature gates. To expose these options, Keycloak must be compiled with the **`multi-site`** feature enabled via the `kc.sh build --features=multi-site` command.
2.  **Hot Rod Client-Server Communication:** Rather than using JGroups protocol layers to talk directly to other Keycloak JVMs, Keycloak leverages the high-performance, binary **Hot Rod** protocol to communicate with the standalone Infinispan cluster. Keycloak nodes will act as Hot Rod clients, connecting strictly to the Infinispan node located within their own local datacenter (avoiding WAN network latency for active operations). The external Infinispan cluster then handles all intra-site and cross-WAN JGroups replication.

---

### **Lab Task: Reconfigure and Rebuild Keycloak Nodes**

You will perform these tasks on **all four** Keycloak VM nodes (`sso-1-a`, `sso-2-a`, `sso-1-b`, and `sso-2-b`).

#### **Step 1: Launch the External Infinispan Cluster**

Ensure that your external Infinispan containers are active on your `sso-mon` VM in Site Zero:

```bash
cd /opt/monitoring/infinispan/
docker-compose -f docker-compose.yml up -d
```

Verify that the ports are reachable:
*   Site A's Infinispan node listens on port `11222`.
*   Site B's Infinispan node listens on port `11223` (mapped to avoid interface conflicts on the single monitor host).

#### **Step 2: Update the `keycloak.conf` Configuration**

On all four Keycloak nodes, edit `/opt/keycloak/conf/keycloak.conf` to replace the embedded clustering properties with the remote client configuration.

**Remove the legacy caching lines:**
```properties
# REMOVE these lines:
# cache=ispn
# cache-stack=jdbc-ping
# spi-cache-embedded-default-cluster-name=...
```

**Add the remote cache client configurations:**

For **Site A nodes (`sso-1-a`, `sso-2-a`):**
```properties
# --- UPDATED REMOTE CACHING CONFIGURATION (SITE A) ---
cache-stack=tcp
cache-remote-host=sso-mon.mydomain.com
cache-remote-port=11222
cache-remote-username=admin
cache-remote-password=password
cache-remote-tls-enabled=false # Disabled for lab environment simplicity
```

For **Site B nodes (`sso-1-b`, `sso-2-b`):**
```properties
# --- UPDATED REMOTE CACHING CONFIGURATION (SITE B) ---
cache-stack=tcp
cache-remote-host=sso-mon.mydomain.com
cache-remote-port=11223
cache-remote-username=admin
cache-remote-password=password
cache-remote-tls-enabled=false # Disabled for lab environment simplicity
```

*Note: In production environments, `cache-remote-tls-enabled` must always be set to `true` to encrypt Hot Rod session transmissions.*

#### **Step 3: Update and Run the Build Script**

To activate the remote cache client options, we must append the `multi-site` feature to our build flags. 

1.  Edit `/opt/keycloak/bin/rebuild_keycloak.sh` on all nodes and update the `FEATURES` variable:
    ```bash
    # Update FEATURES to include multi-site
    FEATURES="token-exchange,impersonation,multi-site"
    ```
2.  Stop the active systemd service:
    ```bash
    sudo systemctl stop keycloak
    ```
3.  Execute the build script to compile the optimized remote-cache runtime:
    ```bash
    sudo /opt/keycloak/bin/rebuild_keycloak.sh
    ```
4.  Restart the Keycloak service:
    ```bash
    sudo systemctl start keycloak
    ```

---

### **Verification**

Your Keycloak cluster is now operating in a completely decoupled, stateless configuration. All session tracking and token replication are handled off-host by the standalone Infinispan nodes.

To verify cross-site session replication over the GSLB:

1.  Navigate to your GSLB address: `https://sso.mydomain.com/auth` (which should route to Site A's load balancer).
2.  Log into the Admin Console and verify that your active user session is visible.
3.  Simulate a site failure by stopping HAProxy on Site A:
    ```bash
    sudo systemctl stop haproxy # Run on sso-lb-a
    ```
4.  The `gslb_check.sh` health check script in Site Zero will detect the outage, atomically update the BIND zone record via RFC 2136 `nsupdate`, and redirect the dynamic hostname to Site B.
5.  Refresh your browser. You should remain seamlessly logged in to the console on Site B, proving that the remote Infinispan containers successfully replicated your session over the WAN link.