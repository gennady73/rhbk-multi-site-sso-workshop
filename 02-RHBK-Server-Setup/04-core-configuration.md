# **2.4 Core Server Configuration (keycloak.conf)**

Now that we have a secure systemd service and valid TLS/SSL certificates, it's time to create the core configuration file that brings our server to life.   
This file, `keycloak.conf`, controls everything from the database connection to the proxy settings and our multi-site replication.  
This is arguably the most important file in our setup.

### **The "Why": Our Configuration Strategy**

Our configuration is built on two key architectural decisions you've made:

1. **Dynamic Hostname Mode:** We will **not** hardcode a hostname (e.g., hostname=sso-1-a.mydomain.com). Instead, we will set `proxy-headers=forwarded` and `hostname-strict=false`. This tells RHBK to trust the `Forwarded` or `X-Forwarded-Host` header from our HAProxy. This makes our RHBK nodes portable and independent of the network, which is a modern best practice.  
2. **Native Multi-Site Replication:** We will use RHBK's simple, built-in multi-site feature (`multi-site-enabled=true`). This is far less complex than managing a separate, external Infinispan cluster and is the recommended path for most deployments.

### **Lab Task: Create and Deploy keycloak.conf**

You will create a single `keycloak.conf` file and deploy it to all four of your RHBK nodes. The **only** lines that will change between sites are the ones for multi-site configuration.

#### **1\. Create the keycloak.conf File**

On your local machine, create the file `/opt/keycloak/conf/keycloak.conf` using the template below. 
File **[keycloak.conf](/assets/keycloak.conf.template)**

**Important:** This configuration includes all the metrics and event listeners required to populate the Grafana dashboards we will build in [Chapter 6](/06-Observability-Stack/)\.


#### **2\. Deploy the Configuration File**
- Edit the template: Fill in your database IP/hostname and credentials, your keystore password, and the IPs for your RHBK nodes in the multi-site-static-routes lines.

- Create Site A Config: Save a version of this file as keycloak.conf.site-a.

- Create Site B Config: Save a second version as keycloak.conf.site-b, making sure to swap the multi-site-site-name and multi-site-static-routes to point to Site A.

- Copy the files:

    Copy keycloak.conf.site-a to /opt/keycloak/conf/keycloak.conf on sso-1-a and sso-2-a.

    Copy keycloak.conf.site-b to /opt/keycloak/conf/keycloak.conf on sso-1-b and sso-2-b.

- Set Permissions: On all four nodes, set the ownership so the keycloak user can read it.

```sh
sudo chown keycloak:keycloak /opt/keycloak/conf/keycloak.conf
sudo chmod 640 /opt/keycloak/conf/keycloak.conf
```

With the configuration in place, you are now ready to run the build script and start the servers for the first time.