# **5.2 Lab: Configuring Prometheus to Scrape Keycloak**

Our Prometheus container is running, but it isn't monitoring our RHBK cluster yet. In this section, we will provide Prometheus with a configuration file that tells it where to find your Keycloak servers and what rules to use for firing alerts.

### **The "Why": Telling Prometheus What to Scrape**

Prometheus operates on a "pull" model. It needs a "scrape list" of targets to go and fetch metrics from. We will provide a [prometheus.yml](/assets/prometheus/prometheus.yml) file that defines a new "job" called keycloak, which lists the management endpoints of all four of our RHBK servers.

### **Step 1: Create the Prometheus Configuration File**

This file defines all of Prometheus's settings, scrape jobs, and a link to its alerting rules.

1. On your sso-mon VM, create the main configuration file:  

```bash
   vi /opt/monitoring/prometheus/prometheus.yml
```

2. Copy the contents of the prometheus.yml.template from the assets directory for this chapter into this new file.

This configuration is critical. Let's look at the keycloak job we added:

```yml
# ... (inside prometheus.yml)
  - job_name: 'keycloak'
    # Scrape metrics from all four Keycloak management endpoints
    static_configs:
      - targets:
        - 'sso-1-a.mydomain.com:9000'
        - 'sso-2-a.mydomain.com:9000'
        - 'sso-1-b.mydomain.com:9000'
        - 'sso-2-b.mydomain.com:9000'

    # --- THIS PART IS CRITICAL ---
    # It tells Prometheus to use HTTPS and to skip verifying the
    # self-signed/internal certificates on your Keycloak management ports.
    scheme: https
    tls_config:
      insecure_skip_verify: true
```

This tells Prometheus to connect to all four servers using `https://` and to ignore the fact that their certificates are signed by our private CA (which the Prometheus container doesn't trust by default).

### **Step 2: Create the Alerting Rules File**

Next, we'll create the file that defines our alert conditions. Prometheus will read this file and continuously check our metrics against these rules.

1. On your sso-mon VM, create the rules file:  
```bash
   vi /opt/monitoring/prometheus/alert.rules.yml
```

2. Copy the contents of the [alert.rules.yml.template](/assets/prometheus/alert.rules.yml) from the assets directory into this new file.

The file contains two initial rules:

* **KeycloakInstanceDown**: This alert will fire if Prometheus can't successfully scrape a Keycloak instance for more than 1 minute.  
* **HighLoginFailureRate**: This alert will fire if the cluster-wide rate of failed logins (LOGIN\_ERROR) goes above 5 per minute for 2 minutes.

### **Step 3: Restart Prometheus to Apply Changes**

Since we just provided new configuration files, we need to restart the Prometheus container.

```bash
cd /opt/monitoring/  
# This command will gracefully restart only the prometheus container  
docker-compose restart prometheus
```

### **Step 4: Verify the Configuration**

Now for the "moment of truth." We need to see if Prometheus is successfully scraping our Keycloak servers.

1. Open your Prometheus UI in a browser: `http://<sso-mon-ip>:9090`  
2. Navigate to the **Status** \> **Targets** page.  
3. Look at the **keycloak** job. You should see all four of your Keycloak servers listed. After a few seconds, their **State** should turn **UP** with a green background.

If the state is **UP**, you have successfully connected your monitoring stack to your RHBK cluster\!

If the state is **DOWN** with a red background, check the Error column for clues. The most common cause is an incorrect IP address in the `extra_hosts` section of your `docker-compose.yml` file, or a firewall on the Keycloak servers blocking requests from your `sso-mon` VM.
