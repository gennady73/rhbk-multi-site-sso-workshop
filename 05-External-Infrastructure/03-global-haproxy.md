# **5.3 Lab: Configuring the Global HAProxy**
##### (v26.2/v26.6 Front Door Guide)

We have now deployed our intelligent dynamic DNS system (the "Brain" and "Heart"). The final piece of our Global Server Load Balancing (GSLB) simulation is to build the **Front Door**—the single, unified public HAProxy gateway that all external clients and applications will connect to. 

This HAProxy instance is unique. Unlike our site-local load balancers which route traffic to static lists of IP addresses, this Global HAProxy leverages our BIND DNS server as an active **runtime resolver** to dynamically discover the IP address of the currently active, healthy datacenter.

---

### **The "Why": The `resolvers` Block**

This design is the core of our dynamic failover loop. When an external client connects to our Global HAProxy, the load balancer inspects its backend configuration which points to a *hostname* (**`sso.mydomain.com`**), rather than a hardcoded IP address. 

HAProxy then queries its defined resolver (our local BIND server) to fetch the IP for that hostname. Because our background `gslb_check.sh` script updates the BIND record in-memory via RFC 2136 `nsupdate` upon detecting a site failure, HAProxy dynamically receives the IP address of the active healthy site and redirects traffic seamlessly.

---

### **Step 1: Install HAProxy**

Log in to your `sso-gslb` VM and install HAProxy:

```sh
sudo dnf install haproxy -y
```

---

### **Step 2: Configure the Firewall**

Since this is the primary public entry point for your SSO service, open the VM's standard HTTPS port to allow external client connections:

```sh
# Allow public HTTPS traffic
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

---

### **Step 3: Deploy the TLS Certificates**

Our Global HAProxy serves two critical security roles:
1.  **Frontend TLS Termination:** It presents our public-facing certificate (`sso.mydomain.com`) to the user's web browser.
2.  **Backend TLS Verification:** It acts as a client to verify the backend certificates presented by our site-local load balancers (`sso-lb-a` and `sso-lb-b`) using our Root CA bundle.

#### **Certificate Bundling Steps:**
1.  Create the secure configuration directory:
    ```sh
    sudo mkdir -p /etc/haproxy/ssl
    ```
2.  Copy your GSLB private key (`global.key`), GSLB public certificate (`global.crt`), and Root CA certificate (`lab-root-ca.crt`) to the VM.
3.  Concatenate them into a single frontend `.pem` bundle:
    ```sh
    sudo cat global.key global.crt lab-root-ca.crt > /etc/haproxy/ssl/global.pem
    ```
4.  Copy the public Root CA certificate separately to serve as the backend validation root:
    ```sh
    sudo cp lab-root-ca.crt /etc/haproxy/ssl/internal-ca.pem
    ```
5.  Enforce strict read-only permissions:
    ```sh
    sudo chmod 600 /etc/haproxy/ssl/*
    sudo chown -R root:haproxy /etc/haproxy/ssl
    ```

---

### **Step 4: Create the Global HAProxy Configuration**

We will now deploy our specialized configuration file which includes the dynamic resolver parameters.

1.  Copy the template file to the active configuration path:
    ```sh
    sudo cp ../assets/haproxy-global.cfg.template /etc/haproxy/haproxy.cfg
    ```
2.  Open `/etc/haproxy/haproxy.cfg` and verify that the `resolvers` section at the top refers to your local BIND loopback interface, and the backend server line targets your dynamic FQDN `sso.mydomain.com`:

```haproxy
resolvers mydns
    nameserver dns1 127.0.0.1:53
    accepted_payload_size 8192
    hold valid 5s # Force HAProxy to refresh DNS resolution every 5 seconds

backend keycloak_sites
    balance roundrobin
    cookie KC_SESSION prefix nocache
    
    # We target sso.mydomain.com using our 'mydns' resolver
    server sso-global-lb sso.mydomain.com:443 check ssl verify required ca-file /etc/haproxy/ssl/internal-ca.pem resolvers mydns init-addr none inter 2000ms
```

---

### **Step 5: Start and Verify**

Enable and start your Global HAProxy instance:

```sh
sudo systemctl enable --now haproxy
sudo systemctl status haproxy
```

---

### **Step 6: End-to-End Failover Testing**

With all components configured, you are ready to execute your first automated failover simulation:

1.  **Configure Client DNS Resolution:** On your local client workstation (the machine hosting your browser), edit your local hosts file (e.g., `/etc/hosts` on Linux/macOS or `C:\Windows\System32\drivers\etc\hosts` on Windows) to map the public dynamic gateway to your GSLB VM's IP address:
    ```text
    <GSLB_VM_IP_ADDRESS> sso.mydomain.com
    ```
2.  **Access the Gateway:** Clear your browser cache and navigate to:
    ```text
    https://sso.mydomain.com/auth
    ```
    Your browser should establish a secure HTTPS connection with the Global HAProxy, which resolves the dynamic hostname using the local BIND server, and routes you to the active Keycloak nodes in Site A.
3.  **Simulate a Datacenter Outage:** Stop the local load balancer on Site A:
    ```sh
    sudo systemctl stop haproxy # Run on sso-lb-a
    ```
4.  **Monitor the Failover:** Tail the GSLB check log on your `sso-gslb` VM:
    ```sh
    tail -f /var/log/gslb_check.log
    ```
    You will observe the script detect three consecutive failures against Site A, trigger the RFC 2136 `nsupdate` dynamic DNS modification, serial-increment the zone records, and switch the record to Site B.
5.  **Seamless Session Recovery:** Refresh your browser window. You should remain logged in and active, with traffic dynamically routed to Site B without prompting you for credentials again.