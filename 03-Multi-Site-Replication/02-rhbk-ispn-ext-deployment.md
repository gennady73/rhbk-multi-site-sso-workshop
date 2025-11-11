# **3.2 Lab: Re-configuring RHBK to Use an External Cache**

Now that our external Infinispan cluster is running, we must reconfigure our RHBK nodes to use it. This involves "gutting" the native caching configuration from keycloak.conf and replacing it with settings that point to our new external service.

### **Step 1: Launch the External Infinispan Cluster**

On your `sso-mon` VM, navigate to the new directory and start the cluster:

```bash
cd /opt/monitoring/infinispan/  
docker-compose -f docker-compose.yml up -d
```

You now have two Infinispan servers running.

* infinispan-site-a is reachable at \<sso-mon-ip\>:11222  
* infinispan-site-b is reachable at \<sso-mon-ip\>:11223

### **Step 2: Update the keycloak.conf File**

On **all four** RHBK nodes, you must now edit `/opt/keycloak/conf/keycloak.conf`.   
We will make the following changes (as outlined in your 341 document):

1. **Remove** the cache=ispn and cache-stack=jdbc-ping lines.  
2. **Remove** all of the multi-site-\* configuration lines.  
3. **Add** new lines to point to the external cache.

Your new configuration file should look like this. Note the changes in the "Caching" section.

**File: /opt/keycloak/conf/keycloak.conf**

```bash
# --- /opt/keycloak/conf/keycloak.conf ---
# Database
db=postgres
db-username=<db_user>
db-password=<db_pass>
db-url=jdbc:postgresql://<db_host>:5432/keycloak

# Proxy & Hostname (Dynamic Mode)
hostname-strict=false
hostname-backchannel-dynamic=false
proxy-headers=forwarded
http-relative-path=/auth
http-management-relative-path=/
https-port=443
hostname-debug=true

# Keystore
https-key-store-file=/opt/keycloak/conf/server.keystore
https-key-store-password=<keystore_pass>

# --- UPDATED CACHING CONFIGURATION ---
# 1. Set the cache stack to 'tcp' (as the old 'ispn' stack is removed)
cache-stack=tcp

# 2. Define the connection details for the external cluster.
#    Keycloak will connect to the Infinispan node in its own site.

# --- For Site A nodes (sso-1-a, sso-2-a): ---
# Point to the 'infinispan-a' container port
cache-remote-host=<sso-mon-ip>
cache-remote-port=11222
cache-remote-username=<admin_user>
cache-remote-password=<admin_user_password>
cache-remote-tls-enabled=false # Disabling TLS for simplicity in this lab

# --- For Site B nodes (sso-1-b, sso-2-b): ---
# Point to the 'infinispan-b' container port
# cache-remote-host=<sso-mon-ip>
# cache-remote-port=11223
# cache-remote-username=<admin_user>
# cache-remote-password=<admin_user_password>
# cache-remote-tls-enabled=false

# --- Observability ---
# (All metrics and logging settings remain the same)
metrics-enabled=true
health-enabled=true
events-listeners=['metrics-listener']
# ... etc ...
```

### **Step 3: Re-build and Restart All RHBK Nodes**

Because we have fundamentally changed the caching stack (from ispn to tcp and remote-host), a **re-build is required**.

On **all four** RHBK nodes:

1. Stop the service: sudo systemctl stop keycloak  
2. Run your build script: sudo /opt/keycloak/bin/rebuild\_keycloak.sh  
3. Start the service: sudo systemctl start keycloak

### **Verification**

Your RHBK cluster is now running in a completely different architecture. The multi-site replication is no longer handled by Keycloak itself, but is fully offloaded to the external Infinispan cluster.

You can verify this using the same method as before:

1. Log into `https://sso-global-lb.mydomain.com/auth` (which should resolve to Site A).  
2. Go to the Admin Console and find your session.  
3. Shut down your sso-lb-a load balancer.  
4. Your GSLB script will detect the failure and update DNS to point to Site B.  
5. Refresh your browser. You should be seamlessly logged in to Site B, proving the session was replicated by the external cluster.

You have now successfully built and compared both the "Native" and "External" multi-site architectures.