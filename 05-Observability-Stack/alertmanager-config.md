# **5.4 Lab: Configuring Alertmanager**

Our Prometheus server is now successfully scraping metrics and checking them against our alerting rules. When a rule is breached (like KeycloakInstanceDown), Prometheus fires an alert.

The next step is to configure **Alertmanager**, which is the service that receives these alerts, groups them, and routes them to a human.

### **The "Why": The Role of Alertmanager**

Think of Prometheus as the "sensor" that detects a problem. Alertmanager is the "notification system" that decides who to notify and how. It handles tasks like:

* **Grouping:** Bundling 100 alerts from the same cluster into a single notification.  
* **Routing:** Sending critical database alerts to the on-call engineer via PagerDuty, but sending low-priority warnings to a Slack channel.  
* **Silencing:** Muting alerts during a planned maintenance window.

In this lab, we will configure a simple receiver to send alerts to a Slack channel.

### **Step 1: Create the Alertmanager Configuration File**

1. On your sso-mon VM, create the main configuration file:  
   vi /opt/monitoring/alertmanager/alertmanager.yml

2. Copy the contents of the [alertmanager.yml.template](/assets/alertmanager/alertmanager.yml.template) from the assets directory for this chapter into this new file.

### **Step 2: Edit the Configuration**

You must edit this file to add your own Slack Webhook URL.

1. Follow a guide to [create an incoming webhook for your Slack workspace](https://api.slack.com/messaging/webhooks). This will give you a unique URL that looks like https://hooks.slack.com/services/T000.../B000.../....  
2. Paste this URL into the api\_url field in your alertmanager.yml file, replacing the placeholder.  
3. Change the channel field to the name of the Slack channel you want alerts to go to (e.g., \#keycloak-alerts).

### **Step 3: Restart Alertmanager**

We need to restart the container for the new configuration to be loaded.

cd /opt/monitoring/  
\# This command will gracefully restart only the alertmanager container  
docker-compose restart alertmanager

### **Step 4: Verify the Setup**

You can test the entire alert pipeline from Prometheus to Slack:

1. **Stop a Keycloak Node:** Log into one of your RHBK servers (e.g., sso-1-a) and stop the service:  
   sudo systemctl stop keycloak

2. **Watch Prometheus:** Open your Prometheus UI (http://\<sso-mon-ip\>:9090).  
   * Go to the **Targets** page. After a minute or two, the sso-1-a:9000 target will turn **DOWN**.  
   * Go to the **Alerts** page. After another minute (due to the for: 1m in our rule), the KeycloakInstanceDown alert will turn red and show a **FIRING** state.  
3. **Check Slack:** Within a minute of the alert firing, you should receive a notification in your configured Slack channel.  
4. **Restore the Service:**  
   sudo systemctl start keycloak

   After a few minutes, Prometheus will mark the target as **UP**, the alert will stop firing, and you will receive a "RESOLVED" notification in Slack.

You now have a fully functional metrics and alerting pipeline.
