# **5.2 Lab: Deploying the Health Check Script**

Now that we have our BIND DNS server (the "Brain"), we need to add the "Heart." This script will run every minute to check the health of our sites and give new orders to the Brain if a site has failed.

### **The "Why": Active Health Checking**

Our BIND server is just a database; it's not "smart." It will happily give out the IP address for Site A even if Site A is on fire.

This script provides the intelligence. It runs on the same sso-gslb VM and does the following:

1. **Gets the current "active" IP** from the BIND zone file.  
2. **Performs a curl health check** against that IP (e.g., checks Site A).  
3. **If the check fails:** It increments a failure counter. Once a threshold (e.g., 3 failures) is reached, it triggers a failover.  
4. **Triggers Failover:**  
   * It updates the sso record in mydomain.com.zone with the IP of the backup site (Site B).  
   * It updates the file's serial number (so other servers know it has changed).  
   * It uses rndc reload to force BIND to load the new file into memory instantly.  
5. **If the check succeeds:** It resets the failure counter, confirming the site is healthy.  
6. **Handles Fail-Back:** If the system is already failed over to Site B, the script *also* checks if Site A has come back online. If it has, it automatically fails back, switching the IP back to the primary site.

### **Step 1: Deploy the Script**

1. Copy the gslb\_check.sh script from the assets directory to a standard location for system scripts on your sso-gslb VM.  
   \# (From your asset deployment directory)  
   sudo cp ./assets/gslb\_check.sh /usr/local/sbin/gslb\_check.sh

2. Make the script executable:  
   sudo chmod \+x /usr/local/sbin/gslb\_check.sh

3. **Edit the script** to match your environment.  
   sudo vi /usr/local/sbin/gslb\_check.sh

   You **must** update the following variables at the top of the script:  
   * PRIMARY\_IP="\<Public\_IP\_of\_sso-lb-a\>"  
   * SECONDARY\_IP="\<Public\_IP\_of\_sso-lb-b\>"  
   * RNDC\_KEY="/etc/rndc.key" (This path should be correct, as we configured it in the previous step).

### **Step 2: Schedule the Script with cron**

This script needs to run automatically. We will use cron to execute it every minute.

1. Open the root user's crontab for editing. (It must run as root to have permission to edit the zone file and reload BIND).  
   sudo crontab \-e

2. Add the following line to the file. This schedules the script to run at the start of every minute, of every hour, of every day.  
   \# Run the GSLB health check every minute  
   \* \* \* \* \* /usr/local/sbin/gslb\_check.sh

3. Save and exit the editor. The cron service will install the new schedule immediately.

### **Step 3: Verify the Script is Working**

You can "tail" the log file to watch the script run in real-time.

tail \-f /var/log/gslb\_check.log

Within a minute, you should see the first output, similar to this:

\--- Starting Health Check \---  
Current active IP is \<Public\_IP\_of\_sso-lb-a\>. Failure count is 0\.  
Checking PRIMARY site at \<Public\_IP\_of\_sso-lb-a\>...  
PRIMARY site check PASSED.  
\--- Health Check Finished \---

**Status:** The "Heart" and "Brain" are now connected and working. Our DNS server is now fully intelligent and will react to outages.
