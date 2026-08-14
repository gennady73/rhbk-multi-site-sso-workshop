# **2.4 Core Server Configuration (keycloak.conf)**
##### (v26.2/v26.6 Production-Hardened Guide)

Now that we have a secure systemd service unit and valid TLS/SSL certificates, it's time to create the core server configuration file that brings our Keycloak deployment to life. This file, `keycloak.conf`, controls everything from the relational database connection pool to reverse proxy headers and our multi-site replication cluster settings. It is the central configuration hub for our setup.

---

### **The "Why": Our Hardened Configuration Strategy**

Our RHEL 9 VM configuration is built on two key architectural decisions:

1.  **Reverse Proxy Hostname Security:** In standard development environments, it is common to set `hostname-strict=false` to dynamically resolve URLs from incoming headers. However, in production, this exposes the cluster to Host Header injection attacks. To align with enterprise security standards, we will enforce **`hostname-strict=true`** and specify our unified GSLB public domain name: **`hostname=sso.mydomain.com`**. We then set **`proxy-headers=forwarded`** to tell Keycloak to securely read the HTTP `Forwarded` header injected by our HAProxy nodes.
2.  **Native Multi-Site Clustering:** For Path A deployments, we leverage Keycloak's native multi-site clustering capability. This built-in model uses JGroups transport protocol stacks (configured via `cache-stack`) and embedded Infinispan configurations to establish cross-site replication without the operational overhead of a standalone, remote caching tier.

---

### **Lab Task: Create and Deploy keycloak.conf**

You will create a single `keycloak.conf` file and deploy it to all four of your RHBK nodes. The only configurations that change between your datacenters are the site identifier properties (`multi-site-site-name`) and the target destination IP coordinates (`multi-site-static-routes`).

#### **1. Create the keycloak.conf File**

Create the file `/opt/keycloak/conf/keycloak.conf` using the template below. 

This template is fully optimized for **RHBK v26.2/v26.6** and includes all the telemetry metrics and event listeners required to populate the centralized Grafana dashboards we will deploy in Chapter 6.

**File: [keycloak.conf](../assets/keycloak.conf.template)**

```properties
# --- /opt/keycloak/conf/keycloak.conf ---

# ==============================================================================
# 1. DATABASE CONFIGURATION
# ==============================================================================
db=postgres
db-username=keycloak
db-password=your_secure_db_password
db-url=jdbc:postgresql://db-host.mydomain.com:5432/keycloak
db-pool-min-size=10
db-pool-max-size=100

# ==============================================================================
# 2. PROXY & HOSTNAME CONFIGURATION (PRODUCTION-HARDENED)
# ==============================================================================
# We strictly lock down the public hostname to prevent Host Header injection
hostname=sso.mydomain.com
hostname-strict=true
hostname-backchannel-dynamic=false

# We tell Keycloak to trust the standard RFC 7239 'Forwarded' header from HAProxy
proxy-headers=forwarded
http-relative-path=/auth
http-management-relative-path=/
https-port=443

# ==============================================================================
# 3. CRYPTOGRAPHY / TLS (HTTPS) CONFIGURATION
# ==============================================================================
https-key-store-file=/opt/keycloak/conf/server.keystore
https-key-store-password=your_keystore_password
https-key-store-type=PKCS12

# ==============================================================================
# 4. INTRA-SITE CLUSTERING & DISCOVERY
# ==============================================================================
cache=ispn
cache-stack=jdbc-ping

# Ensure the logical cluster name is isolated to prevent cross-talk on shared databases
spi-cache-embedded-default-cluster-name=site-a-kc-cluster

# ==============================================================================
# 5. OBSERVABILITY (METRICS & LOGGING)
# ==============================================================================
metrics-enabled=true
health-enabled=true
events-listeners=['metrics-listener']
event-metrics-user-enabled=true
event-metrics-user-events=login,logout,code_to_token,refresh_token,register
event-metrics-user-tags=realm,clientId,idp
http-metrics-histograms-enabled=true
cache-metrics-histograms-enabled=true

# Centralized Logging Properties
log=file
log-file=/opt/keycloak/log/keycloak.log
log-level=INFO
log-file-rotation-size=20M
log-file-rotation-max-files=5
```

#### **2. Deploy the Configuration File**

1.  **Configure and Adapt:** Edit the template on your local machine:
    *   Set your actual PostgreSQL database host IP/DNS and credentials.
    *   Set your exact PKCS12 keystore password.
2.  **Create Site A Configurations:**
    *   Set `spi-cache-embedded-default-cluster-name=site-a-kc-cluster` to establish local clustering bounds for Site A.
    *   Save this file as `keycloak.conf.site-a`.
3.  **Create Site B Configurations:**
    *   Modify the properties for Site B: set the cluster name to `site-b-kc-cluster` to ensure complete logical namespace separation.
    *   Save this file as `keycloak.conf.site-b`.
4.  **Distribute to Nodes:**
    *   Copy `keycloak.conf.site-a` to `/opt/keycloak/conf/keycloak.conf` on nodes `sso-1-a` and `sso-2-a`.
    *   Copy `keycloak.conf.site-b` to `/opt/keycloak/conf/keycloak.conf` on nodes `sso-1-b` and `sso-2-b`.
5.  **Enforce Safe Permissions:** On all four VM nodes, run the following commands to restrict access to the database credentials and TLS keys stored in the configuration file:

```sh
sudo chown keycloak:keycloak /opt/keycloak/conf/keycloak.conf
sudo chmod 640 /opt/keycloak/conf/keycloak.conf
```

With the configurations deployed, you are ready to execute the rebuild script and launch your clustered Keycloak server instances.