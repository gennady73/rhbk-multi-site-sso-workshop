# **2.3 Workshop Certificates Setup**

## **2.3.1. Overview**

This workshop operates in a secure-by-default, production-like environment. We will not use http or disable security. Instead, all communication between services (RHBK, HAProxy, Prometheus, etc.) will be secured using TLS (HTTPS).

We will act as our own Certificate Authority (CA) by creating a "Root CA." We will then use this Root CA to sign all the individual certificates for our servers and load balancers.

**The most critical concept:** By default, no service trusts our new Root CA. Our main task is to create this chain of trust. This involves two parts:

1. **Issuing:** Creating all the certs.  
2. **Distributing & Trusting:** Copying the public root-ca.pem file to every service and configuring that service to *trust* it.

### **The "Why": Production vs. Development**

Setting up certificates is not just a security formality; it is the key differentiator between running RHBK in **development mode** versus **production mode**.

1. **Production Mode Requires TLS:** The standard start command (production mode) **requires** HTTPS/TLS. Without a certificate, the server will not start. The start-dev command is a workaround that runs the server over insecure HTTP.  
2. **Distributed Caching:** This is the most critical point for our workshop.  
   * **Development Mode (start-dev)** defaults to **local caches only**. It *disables* the distributed cache, making a multi-node cluster impossible.  
   * **Production Mode (start)** enables the **distributed Infinispan cache** by default, which is essential for our multi-site, high-availability goals.

## **2.3.2. Informational: The Mechanics of a Java Keystore**

Before we use the lab automation, it's helpful to understand the manual process. Assuming you have a ca.crt (our lab's "root of trust") and server-specific certificates (e.g., server.crt, server.key):

Here is the manual process for turning those files into a Java Keystore on a single RHBK node.

#### **1\. Create the PKCS12 Keystore**

Keycloak (as a Java application) works best with a .p12 (PKCS12) keystore. We use openssl to combine our server's private key and public certificate into a single .p12 file.
  ```bash
  # Define a strong password for your new keystore.  
  # For this lab, we will use 'password' for simplicity.  
  export KEYSTORE_PASS="password"

  # This command bundles the key, the cert, and the CA cert into a single .p12 file.  
  # Replace 'server.key' and 'server.crt' with the specific files for this node.  
  openssl pkcs12 -export -out server.p12 \\  
    -inkey server.key -in server.crt \\  
    -certfile ca.crt -passout pass:$KEYSTORE_PASS

  echo "Keystore 'server.p12' created."
  ``` 

#### **2\. Install the Keystore for Keycloak**

This new keystore must be copied into the Keycloak configuration directory with the correct permissions.
  ```bash
  # Copy the keystore to the standard conf directory  
  sudo cp server.p12 /opt/keycloak/conf/server.keystore

  # Set ownership to the keycloak user  
  sudo chown keycloak:keycloak /opt/keycloak/conf/server.keystore

  # Set read-only permissions for the owner  
  sudo chmod 400 /opt/keycloak/conf/server.keystore
  ``` 

#### **3\. Trust the Internal CA System-Wide**

Finally, the host VM's operating system must trust our Internal CA. This allows system tools (like curl) to make secure connections.
```bash
# 1. Copy your Root CA certificate to the system's trust anchor directory  
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/workshop-internal-ca.crt

# 2. Update the system-wide trust store  
sudo update-ca-trust extract

echo "Internal CA is now trusted by the host OS."
``` 

## **2.3.3. Lab Task: Automated Certificate Generation & Deployment**

The manual process above is complex and error-prone. This workshop provides a complete, automated PKI solution in the setup/lab-ca/ directory (or /assets/certs in the repo) to perform all these steps at once.

You will perform these tasks from your central control node (or the gslb VM).

### **Step 1: Configure and Run the "Factory" ([setup-certificates.sh](/assets/certs/setup-certificates.sh))**

This script is the "factory" that generates our Root CA and all server certificates.

1. **Configure:** Open setup/lab-ca/setup-certificates.sh and edit the configuration variables:  
   * ROOT\_CA\_DIR, DOMAIN, PASSWORD.  
   * **CERT\_HOSTS**: This is the most important part. Ensure every hostname and IP in this array matches your lab-topology.md file. This array is the core of the script's configuration:
    ```bash
    # --- Snippet from setup-certificates.sh ---  
    declare -A CERT_HOSTS=(  
      ["sso-1-a.${DOMAIN}"]="DNS:sso-1-a.${DOMAIN},IP:<sso-1-a_IP>"  
      ["sso-2-a.${DOMAIN}"]="DNS:sso-2-a.${DOMAIN},IP:<sso-2-a_IP>"  
      # ...  
      ["sso-lb-a.${DOMAIN}"]="DNS:sso-lb-a.${DOMAIN},DNS:*.${DOMAIN},IP:<sso-lb-a_IP>"  
      # ...  
    )
    ``` 

2. **Run:**  
    ```bash
   cd \~/setup/lab-ca/  
   ./setup-certificates.sh
    ``` 

3. **Result:**  
The script will populate the setup/lab-ca/output/ directory. It does this by first creating the Root CA, then looping through the CERT\_HOSTS array to generate and sign a certificate for each host.  
   These are the key commands from the script's loop that perform the signing and bundling:  

    ```bash
      # --- Snippet from setup-certificates.sh ---  
      # This command is inside the loop. It signs the CSR with our Root CA  
      openssl ca -batch -config "$ROOT_CA_DIR/openssl-root-ca.cnf" \\  
        -extensions v3_req -extfile "$HOST_DIR/req.cnf" \\  
        -in "$HOST_DIR/server.csr" -out "$HOST_DIR/server.crt"

      # And this command bundles it into the .p12 file for Keycloak  
      openssl pkcs12 -export -out "$HOST_DIR/server.p12" \\  
        -inkey "$HOST_DIR/server.key" -in "$HOST_DIR/server.crt" \\  
        -certfile "$ROOT_CA_DIR/ca.crt" -passout pass:$PASSWORD
    ```

    This will create a folder for each host \(e.g., gu-sso-1-a.rh-igc.com\) holding its unique server.crt, server.key, and server.p12 files.

<br>  


### **Step 2: Configure and Run the "Distributor" ([distribute-certificates.sh](/assets/certs/distribute-certificates.sh))**

This script is the automated deployment tool. It logs into every VM and installs the correct certificates and system trust.

1. **Configure:** Open setup/lab-ca/distribute-certificates.sh and edit the configuration:  
   * USERNAME and PASSWORD (for sshpass to log in).  
   * **SERVERS**: This is the control map. Uncomment the hosts for your lab and ensure their "role" (keycloak, haproxy) is correct. This SERVERS array tells the script what to do for each host: 

    ```bash
    # --- Snippet from distribute-certificates.sh ---  
    declare -A SERVERS=(  
      ["gu-sso-1-a${DOMAIN_NAME}"]="keycloak"  
      ["gu-sso-2-a"${DOMAIN_NAME}]="keycloak"  
      # ...  
      ["gu-sso-lb-a"${DOMAIN_NAME}]="haproxy"  
      # ...  
    )
    ``` 

2. **Run:**  

    ```bash
    cd \~/setup/lab-ca/  
    ./distribute-certificates.sh
    ``` 

3. **Result (What this script does):**  
  The script loops over the SERVERS array and uses sshpass to remotely execute commands based on the role.  
  * **For ALL hosts:**   
  It copies the ca.crt to /etc/pki/ca-trust/source/anchors/lab-root-ca.crt and runs sudo update-ca-trust extract.   
  This is the most important step for establishing universal trust.

    ```bash
    # --- Snippet from distribute-certificates.sh ---  
    # This command (or similar) is run on ALL servers:  
    echo '$PASSWORD' | sudo -S cp ... /etc/pki/ca-trust/source/anchors/lab-root-ca.crt &&  \\
    echo '$PASSWORD' | sudo -S update-ca-trust extract
    ``` 

  * **For keycloak roles:**    
  It copies the host's server.p12 from the output/ directory to /opt/rhbk/conf/server.keystore on the remote server.   
  This is the core "keystore" installation.  

    ```bash
    # --- Snippet from distribute-certificates.sh ---  
    # This command copies the .p12 file to the RHBK node  
    sshpass -p "$PASSWORD" scp "output/$HOST/server.p12" "$USERNAME@$HOST:$DEST_DIR/server.keystore"
    ``` 

  * **For haproxy roles:**   
  It bundles the server.crt, server.key, and ca.crt into a single haproxy.pem file and copies it to /etc/haproxy/ssl/haproxy.pem on the remote server.  
  A single .pem file is required by HAProxy. 

    ```bash
    # --- Snippet from distribute-certificates.sh ---  
    # 1. Bundles the certs locally  
    cat "output/$HOST/server.crt" "output/$HOST/server.key" "$CA_FILE" > "output/$HOST/haproxy.pem"

    # 2. Uploads the bundle to the HAProxy server  
    sshpass -p "$PASSWORD" scp "output/$HOST/haproxy.pem" "$USERNAME@$HOST:/tmp/haproxy.pem"

    # 3. Installs it and sets permissions  
    echo '$PASSWORD' | sudo -S mv /tmp/haproxy.pem /etc/haproxy/ssl/haproxy.pem &&  
    echo '$PASSWORD' | sudo -S chown root:haproxy /etc/haproxy/ssl/haproxy.pem &&  
    # ...  
    ``` 

<br>

## **2.3.4. Certificate Distribution Summary**

This is the "cheat sheet" for the rest of the lab. It shows which files must be copied where.

| Service / Host | Required Files | Target Path (Example) |
| :---- | :---- | :---- |
| **RHBK Node** (sso-1-a) | keycloak.keystore.p12 keycloak.truststore.p12 | /opt/rhbk/conf/ |
| **Site LB** (lb-a) | sso.site-a.mydomain.com-cert.pem sso.site-a.mydomain.com-key.pem root-ca.pem | /etc/haproxy/certs/ |
| **Global LB** (gslb) | sso.mydomain.com-cert.pem sso.mydomain.com-key.pem root-ca.pem | /etc/haproxy/certs/ |
| **Monitor Host** (monitor) | root-ca.pem | /etc/prometheus/certs/ |

