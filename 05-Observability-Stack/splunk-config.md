# **5.3 Lab: Configuring Log Forwarding with Splunk**

We have metrics flowing into Prometheus, but for deep troubleshooting, we need to see the actual application logs. In this section, we will install the Splunk Universal Forwarder on all four of our RHBK servers to capture the keycloak.log file and send it to our central Splunk container for analysis.

### **The "Why": Metrics vs. Logs**

* **Metrics** (Prometheus) are numeric measurements over time. They are great for dashboards, trends, and alerting on *quantitative* problems (e.g., "How many? How fast?").  
* **Logs** (Splunk) are detailed, timestamped *events*. They are essential for debugging and answering *qualitative* questions (e.g., "What was the exact error? Who did what?").

We need both for a complete observability picture.

### **Step 1: Configure Splunk to Receive Data**

First, we must tell our Splunk server to listen for incoming logs from the forwarders.

1. Open your Splunk UI in a browser: `http://<sso-mon-ip>:8000`  
2. Log in with the credentials admin / admin (or as set in your [docker-compose.yml](/assets/docker-compose.yml)).  
3. In the top-right corner, click on **Settings** \> **Forwarding and receiving**.  
4. Under "Receive data," click **Add new** next to "Configure receiving."  
5. Enter 9997 in the "Listen on this port" field. This is the port we exposed in our [docker-compose.yml](/assets/docker-compose.yml) file.  
6. Click **Save**. Splunk is now listening for data.

### **Step 2: Download the Splunk Universal Forwarder**

On **each** of your four RHBK VMs (sso-1-a, sso-2-a, sso-1-b, sso-2-b), you need to download the forwarder.

1. Go to the [Splunk Universal Forwarder download page](https://www.splunk.com/en_us/download/universal-forwarder.html).  
2. Select the **Linux** tab and download the **.rpm** package (e.g., splunkforwarder-9.x.x-x-Linux-x86\_64.rpm).  
3. Upload this .rpm file to all four RHBK servers.

### **Step 3: Install and Configure the Forwarder**

Run these commands on **all four** RHBK servers:

1. **Install the package:**  
   \# (Update the filename to match the version you downloaded)  
   sudo yum install ./splunkforwarder-9.x.x-x-Linux-x86\_64.rpm

2. **Start and enable the forwarder:**  
   sudo /opt/splunkforwarder/bin/splunk start \--accept-license \--answer-yes \--no-prompt  
   sudo /opt/splunkforwarder/bin/splunk enable boot-start \-user splunk

   *Note: The installer creates a splunk user to run the service.*  
3. Tell the forwarder where the Splunk server is:  
   (Replace \<sso-mon-ip\> with the IP of your monitoring VM)  
   sudo /opt/splunkforwarder/bin/splunk add forward-server \<sso-mon-ip\>:9997

4. Create the `inputs.conf` file:  
   This file tells the forwarder what to monitor. Copy the [inputs.conf.template](/assets/splunk/inputs.conf.template) from this chapter's assets directory to the following location.  
   **Location:** /opt/splunkforwarder/etc/system/local/inputs.conf  
   \# Ensure the directory exists  
   sudo mkdir \-p /opt/splunkforwarder/etc/system/local/

   \# Create the file  
   sudo vi /opt/splunkforwarder/etc/system/local/inputs.conf

   Paste the contents of the template into this file. This configuration tells the forwarder to monitor your keycloak.log file, tag it with sourcetype=log4j, and send it to an index named keycloak.  
5. **Set correct permissions:** The keycloak.log file is owned by the keycloak user. The splunk user needs permission to read it. The simplest way is to add the splunk user to the keycloak group.  
   sudo usermod \-a \-G keycloak splunk  
   \# Verify the log file is readable by its group  
   sudo chmod 640 /opt/keycloak/log/keycloak.log

6. **Restart the forwarder** to load the new configuration:  
   sudo /opt/splunkforwarder/bin/splunk restart

### **Step 4: Verify in Splunk**

1. Go back to your Splunk UI (`http://<sso-mon-ip>:8000`).  
2. Click on **Search & Reporting** (the main app).  
3. In the search bar, type `index=keycloak` and press Enter.

After a few moments, you should see log events appearing from all four of your RHBK hosts. You have now successfully centralized all your application logs for analysis and debugging.
