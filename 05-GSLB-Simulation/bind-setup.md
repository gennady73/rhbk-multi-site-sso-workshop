# **4.1 Lab: Configuring the BIND DNS Server**

First, we will set up the "Brain" of our GSLB: the BIND DNS server.     
This server's *only* job is to be the authoritative source for our mydomain.com zone and answer one question: "What is the IP address for sso.mydomain.com?"

We will configure it on our `sso-gslb` VM in Site Zero.

### **Step 1: Install BIND**

Log in to your `sso-gslb` VM and install the BIND packages.
```sh
sudo dnf install bind bind-utils -y
```
### **Step 2: Configure the Main named.conf**

The main configuration file, `/etc/named.conf`, tells BIND what zones it is responsible for and sets its global options.

1. Copy the [named.conf.template](/assets/named.conf.template) file from the assets directory to /etc/named.conf. You will need `sudo` as this is a protected file.  
   ```sh
   # From your asset deployment directory  
   sudo cp ./assets/named.conf.template /etc/named.conf
   ```

2. **Crucial Sanity Check:** The template assumes you have a key for the *rndc* (Remote Name Daemon Control) utility.   
Let's generate a new one on the server to ensure our configuration is valid.  
   ```sh
   # This command generates a key and saves it to /etc/rndc.key  
   sudo rndc-confgen -a -k rndc-key -c /etc/rndc.key

   # Now, extract the 'secret' from that file  
   RNDC_SECRET=$(sudo grep -m 1 'secret' /etc/rndc.key | awk '{print $2}' | tr -d '"')

   # Use sed to safely insert this new secret into your named.conf  
   sudo sed -i "s|secret \".*\";|secret $RNDC_SECRET;|" /etc/named.conf
   ```
3. You must also edit `/etc/rndc.conf` (or create it) to tell the rndc command itself how to authenticate.  
   ```sh
   sudo sh -c 'echo "key \"rndc-key\" {" >> /etc/rndc.conf'  
   sudo sh -c 'sudo grep -A 2 "key \"rndc-key\"" /etc/named.conf | grep -v "key" >> /etc/rndc.conf'  
   sudo sh -c 'echo "};" >> /etc/rndc.conf'  
   sudo sh -c 'echo "options { default-key \"rndc-key\"; default-server 127.0.0.1; };" >> /etc/rndc.conf'
   ```

### **Step 3: Create the Zone File**

Now we create the "file" that `named.conf` points to. This file contains the actual DNS records for mydomain.com.

1. Copy the [mydomain.com.zone.template](/assets/mydomain.com.zone.template) file from the assets directory to `/var/named/mydomain.com`.zone.  
   ```sh
   # From your asset deployment directory  
   sudo cp ./assets/mydomain.com.zone.template /var/named/mydomain.com.zone
   ```
2. **Edit the file** to replace the placeholders.  
   ```sh
   sudo vi /var/named/mydomain.com.zone
   ```
   * Replace `<Public_IP_of_Site_Zero_VM>` with the actual public IP of your `sso-gslb` VM.  
   * Replace `<Public_IP_sso-lb-a>` with the public IP of your `sso-lb-a` HAProxy.  
3. Set the correct permissions so the `named` service can read and write to the file (our script will be editing this file as root, but named needs to read it).
   ```sh  
   sudo chown root:named /var/named/mydomain.com.zone  
   sudo chmod 664 /var/named/mydomain.com.zone
   ```
### **Step 4: Validate, Start, and Enable BIND**

1. **Check for Errors:** Before starting, let's ask BIND to check our files for any typos.  
   ```sh
   # Check the main config file  
   sudo named-checkconf /etc/named.conf

   # Check the zone file  
   sudo named-checkzone mydomain.com /var/named/mydomain.com.zone
   ```
   If these commands produce no output, your files are syntactically correct.  
2. **Configure Firewall:** Allow public DNS traffic to the server.  
   ```sh
   sudo firewall-cmd \--permanent \--add-service=dns  
   sudo firewall-cmd \--reload
   ```
3. **Start and Enable:**  
   ```sh
   sudo systemctl enable \--now named  
   sudo systemctl status named
   ```
### **Step 5: Perform a Local Test**

The final check. Let's ask our newly running BIND server (at localhost) for the IP of `sso.mydomain.com`.
```sh
dig A sso.mydomain.com @localhost
```
You should see a successful response in the ANSWER SECTION showing the IP of your primary site, `sso-lb-a`.

**Status:** The "Brain" is now built and serving our primary DNS record.