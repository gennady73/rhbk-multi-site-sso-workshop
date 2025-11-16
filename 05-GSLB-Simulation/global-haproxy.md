# **5.3 Lab: Configuring the Global HAProxy (The "Front Door")**

We have now built our intelligent DNS. The final piece of the GSLB simulation is to build the "Front Door"—the single HAProxy instance that all our clients will connect to.

This HAProxy instance is special. Unlike our site-local proxies that just balanced traffic to a static list of IPs, this "Global HAProxy" will use our BIND server as its **resolver** to dynamically discover the correct IP for the healthy site.

### **The "Why": The resolvers Directive**

This setup is the key to our lab. When a client connects to this HAProxy, HAProxy will look at its backend configuration, which will point to a *hostname* (sso.mydomain.com), not an IP. It will then query its defined resolver (our local BIND server) to get the IP address for that hostname. Because our BIND server is being updated by our health-check script, HAProxy will always receive the IP of the *currently active site*.

### **Step 1: Install HAProxy**

Just as we did with the site-local LBs, log in to your sso-gslb VM and install HAProxy.

sudo dnf install haproxy \-y

### **Step 2: Configure the Firewall**

This is the main public entry point, so it must be open to the world (or at least your client machine) on the standard HTTPS port.

\# Allow public HTTPS traffic  
sudo firewall-cmd \--permanent \--add-service=https  
sudo firewall-cmd \--reload

### **Step 3: Deploy the TLS Certificate and Internal CA**

This HAProxy instance serves two TLS roles:

1. **Terminates Public TLS:** It presents its public certificate (sso-global-lb.mydomain.com) to the end-user's browser.  
2. **Verifies Backend TLS:** It acts as a *client* and verifies the certificate of the site-local LBs (sso-lb-a or sso-lb-b).

To do this, it needs its own certificate/key, and it also needs to trust our Internal CA.

1. Create the SSL directory:  
   sudo mkdir \-p /etc/haproxy/ssl

2. Create the main .pem file for the frontend, which includes its key, its certificate, and the CA chain.  
   sudo cat /path/to/sso-global-lb.mydomain.com.key \\  
            /path/to/sso-global-lb.mydomain.com.crt \\  
            /path/to/lab-root-ca.crt \\  
            \> /etc/haproxy/ssl/global.pem

3. Copy just the Internal CA's public certificate to a separate file for backend verification.  
   sudo cp /path/to/lab-root-ca.crt /etc/haproxy/ssl/internal-ca.pem

4. Set permissions:  
   sudo chmod 600 /etc/haproxy/ssl/\*

### **Step 4: Create the Global HAProxy Configuration**

This configuration is different from the site-local ones. It contains the crucial resolvers block.

1. Copy the haproxy.cfg.global template from the assets directory to /etc/haproxy/haproxy.cfg.  
   \# (From your asset deployment directory)  
   sudo cp ./assets/haproxy.cfg.global /etc/haproxy/haproxy.cfg

2. No IP edits are needed inside this file, as it's designed to discover them dynamically\!

### **Step 5: Start and Verify**

Now, let's start the final component of our architecture.

sudo systemctl enable \--now haproxy  
sudo systemctl status haproxy

### **Verification: The End-to-End Test**

You are now ready to test the entire workshop.

1. **Modify Your Local hosts File:** On your *local workstation* (the machine with your browser), you must manually simulate the DNS delegation for our non-registered domain. Edit your hosts file (e.g., /etc/hosts on Linux/macOS or C:\\Windows\\System32\\drivers\\etc\\hosts on Windows) and add the following line:  
   \<Public\_IP\_of\_Site\_Zero\_VM\>   sso-global-lb.mydomain.com

   This tells your computer to send all requests for sso-global-lb.mydomain.com to your GSLB HAProxy.  
2. Test: Open your browser (clear your cache\!) and navigate to:  
   https://sso-global-lb.mydomain.com/auth

It should load the Keycloak login page from Site A.

3. **Test Failover:**  
   * Shut down the sso-lb-a VM.  
   * Watch the log on your GSLB VM: tail \-f /var/log/gslb\_check.log  
   * You will see the health check fail 3 times, and then the "PERFORMING DNS SWITCH" message will appear.  
   * Refresh your browser at `https://sso-global-lb.mydomain.com/auth`.  
   * It should now seamlessly load the Keycloak login page from Site B.

You have successfully built a fully automated, multi-site failover solution.
