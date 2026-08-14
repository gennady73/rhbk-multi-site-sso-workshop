# **5.1 Lab: Configuring the BIND DNS Server**
##### (v26.2/v26.6 Brain Setup Guide)

In this section, we will configure the **Brain** of our Global Server Load Balancing (GSLB) simulation: the BIND DNS server. This server's sole responsibility is to act as the authoritative DNS master for the **`mydomain.com`** zone and dynamically respond to queries for our active SSO gateway FQDN **`sso.mydomain.com`**.

We will deploy and configure this service on the **`sso-gslb`** virtual machine in Site Zero.

---

### **The "Why": Secure Dynamic DNS Updates (allow-update)**

In standard static DNS configurations, zone records are read-only text files. However, for our health-checking script to dynamically failover clients during an outage, the BIND server must permit runtime modifications.

To do this securely, we will bind BIND's **`allow-update`** directive to our Remote Name Daemon Control (**RNDC**) TSIG key. This ensures that only local processes presenting the authenticated **`rndc-key`** signature (like our local `gslb_check.sh` script) can alter DNS records in memory. This eliminates security holes while allowing BIND to preserve zone integrity and dynamically propagate record updates to secondary servers.

---

### **Step 1: Install BIND**

Log in to your `sso-gslb` VM and install the BIND package and utility tools:

```sh
sudo dnf install bind bind-utils -y
```

---

### **Step 2: Configure the Main `named.conf`**

The main configuration file, `/etc/named.conf`, defines the global server parameters and contains our zone declarations. 

1.  Copy the [named.conf.template](../assets/named.conf.template) file to `/etc/named.conf`:
    ```sh
    sudo cp ../assets/named.conf.template /etc/named.conf
    ```
2.  **Verify Zone Declarations:** Open `/etc/named.conf` and ensure that your zone definition explicitly allows dynamic updates using your local `rndc-key` key block:
    ```text
    zone "mydomain.com" IN {
        type master;
        file "mydomain.com.zone";
        allow-update { key "rndc-key"; }; // Enforce secure key-authorized dynamic updates
    };
    ```
3.  **Generate a Secure RNDC Key:**
    ```sh
    # Generate the RNDC key and save it securely
    sudo rndc-confgen -a -k rndc-key -c /etc/rndc.key
    
    # Extract the key secret
    RNDC_SECRET=$(sudo grep -m 1 'secret' /etc/rndc.key | awk '{print $2}' | tr -d '"')
    
    # Inject this secret into your named.conf configuration file
    sudo sed -i "s|secret \".*\";|secret \"$RNDC_SECRET\";|" /etc/named.conf
    ```
4.  **Configure RNDC Client Authentication:**
    Create `/etc/rndc.conf` to configure local command authentication:
    ```sh
    sudo sh -c 'echo "key \"rndc-key\" {" > /etc/rndc.conf'
    sudo sh -c 'sudo grep -A 2 "key \"rndc-key\"" /etc/named.conf | grep -v "key" >> /etc/rndc.conf'
    sudo sh -c 'echo "};" >> /etc/rndc.conf'
    sudo sh -c 'echo "options { default-key \"rndc-key\"; default-server 127.0.0.1; };" >> /etc/rndc.conf'
    sudo chmod 600 /etc/rndc.conf
    ```

---

### **Step 3: Create the Authoritative Zone File**

We will now deploy the baseline zone record file which BIND will serve on boot.

1.  Copy the zone file template **([mydomain.com.zone.template](../assets/mydomain.com.zone.template))** to `/var/named/mydomain.com.zone`:
    ```sh
    sudo cp ../assets/mydomain.com.zone.template /var/named/mydomain.com.zone
    ```
2.  Edit the file to set the default start coordinates:
    ```sh
    sudo vi /var/named/mydomain.com.zone
    ```
    *   Set the **SOA** records and standard DNS servers.
    *   Initialize the A record for `sso` to target your primary Site A HAProxy gateway IP (e.g. `sso IN A 10.20.1.10`).
3.  Set the correct ownership and write permissions so BIND can modify the zone dynamically during failovers:
    ```sh
    sudo chown root:named /var/named/mydomain.com.zone
    sudo chmod 660 /var/named/mydomain.com.zone
    ```

---

### **Step 4: Validate, Start, and Enable BIND**

1.  **Run Syntax Sanity Checks:** Ensure there are no typos or configuration mismatches in your files:
    ```sh
    # Validate main server config
    sudo named-checkconf /etc/named.conf
    
    # Validate the zone syntax
    sudo named-checkzone mydomain.com /var/named/mydomain.com.zone
    ```
    If these commands return without printing errors, your configuration is valid.
2.  **Configure Firewall:** Allow local and public DNS queries to reach the BIND daemon:
    ```sh
    sudo firewall-cmd --permanent --add-service=dns
    sudo firewall-cmd --reload
    ```
3.  **Launch the Service:**
    ```sh
    sudo systemctl enable --now named
    sudo systemctl status named
    ```

---

### **Step 5: Perform a Local Name Resolution Test**

Query the local BIND server to verify that it successfully resolves our starting coordinate for the primary site:

```bash
dig A sso.mydomain.com @localhost
```

You should see a successful response in the `ANSWER SECTION` showing the IP address of your primary load balancer (`sso-lb-a`). The "Brain" is now fully active, secured, and ready for dynamic orchestration!