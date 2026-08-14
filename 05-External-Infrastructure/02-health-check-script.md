# **5.2 Lab: Deploying the Health Check Script**
##### (v26.2/v26.6 Production-Hardened Guide)

Now that we have our authoritative BIND DNS server (the "Brain") running, we need to add the "Heart." This is a lightweight routing script designed to run continuously on the GSLB VM to check the liveness of our load-balanced sites and orchestrate automated, dynamic DNS failover actions.

---

### **The "Why": Modern Dynamic DNS Orchestration (RFC 2136)**

In legacy proof-of-concept deployments (such as your v1.0.0-beta.1), DNS updates were handled by running direct string-replacement commands (`sed`) against the live BIND zone files (`mydomain.com.zone`) on the local filesystem and calling a full server configuration reload (`rndc reload`). 

While simple, this file-rewrite pattern introduces severe operational risks in production environments:
*   **Race Conditions:** Multiple concurrent file-write operations can easily corrupt the zone file structure.
*   **Bypassed Zone Transfers:** Direct file writes bypass standard BIND master-slave serialization synchronization, preventing secondary DNS servers from receiving immediate updates.
*   **Performance Overhead:** Reloading the entire DNS server daemon forces BIND to rebuild all lookup tables, causing performance dips during high-traffic authentication windows.

To address these vulnerabilities, we have completely modernized the health check integration. The updated `gslb_check.sh` script executes **atomic DNS updates via RFC 2136 Dynamic DNS (DDNS)** using the standard system tool **`nsupdate`** over the localhost loopback. This model uses our secure TSIG key (`/etc/rndc.key`) to authorize BIND to insert or replace the `sso.mydomain.com` A record dynamically in-memory, ensuring continuous, zero-downtime operations and safe master-slave zone updates.

---

### **Step 1: Deploy the Dynamic Script**

1.  Copy the modernized script **([gslb_check.sh](../assets/gslb_check.sh))** from your assets directory to the standard administrative bin path on your `sso-gslb` VM:
    ```sh
    sudo cp ../assets/gslb_check.sh /usr/local/sbin/gslb_check.sh
    ```
2.  Set the correct executable permissions and restrict access to the file (since it references internal IP coordinates):
    ```sh
    sudo chmod 750 /usr/local/sbin/gslb_check.sh
    sudo chown root:root /usr/local/sbin/gslb_check.sh
    ```
3.  Edit the script to set your primary and backup site IP coordinates:
    ```sh
    sudo vi /usr/local/sbin/gslb_check.sh
    ```
    *   Set **`PRIMARY_IP`** to your Site A HAProxy gateway IP.
    *   Set **`SECONDARY_IP`** to your Site B HAProxy gateway IP.
    *   Verify the path of your **`RNDC_KEY`** (default is `/etc/rndc.key`).

---

### **Step 2: Schedule the Script**

To achieve continuous failover protection, schedule the script to run every minute using the system `cron` daemon:

1.  Open the root user's cron configuration table:
    ```sh
    sudo crontab -e
    ```
2.  Add the following scheduling line to the file. This tells cron to run our health check executable at the start of every minute of every hour:
    ```cron
    # Run the GSLB dynamic health check every minute
    * * * * * /usr/local/sbin/gslb_check.sh
    ```
3.  Save and exit the editor. The cron service will load the new schedule instantly.

---

### **Step 3: Verification**

You can inspect the execution log in real-time to watch the health check loop run:

```sh
tail -f /var/log/gslb_check.log
```

Within a minute, you should see the first output, indicating a healthy primary site:

```log
--- Starting Health Check ---
Current active IP is 10.20.1.10. Failure count is 0.
Checking PRIMARY site at 10.20.1.10...
PRIMARY site check PASSED.
--- Health Check Finished ---
```

---

### **Failover Integration Breakdown (How `nsupdate` works)**

When a site failure occurs (such as three consecutive failed HTTP curl checks against the active primary IP), the script will automatically bypass file writes and execute the following dynamic transaction:

```bash
# This is the transaction block executed inside gslb_check.sh
nsupdate -k /etc/rndc.key <<EOF
server 127.0.0.1
zone mydomain.com
update delete sso.mydomain.com. A
update add sso.mydomain.com. 5 A 10.20.2.10
send
EOF
```

This transaction:
1.  Connects to the local DNS server on loopback (`127.0.0.1`).
2.  Binds to the `mydomain.com` zone context.
3.  Atomically removes the existing `sso.mydomain.com` A record.
4.  Inserts a new A record pointing to the backup IP `10.20.2.10` with a low, single-digit Time-To-Live (**TTL of 5 seconds**). This low TTL forces public resolvers and load balancers to immediately drop cached values and query the BIND server for the new IP, guaranteeing rapid failover propagation.
5.  Executes the changes dynamically without restarting or reloading the server daemon.