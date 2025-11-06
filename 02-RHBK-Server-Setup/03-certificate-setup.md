# **2.3 Certificate Setup: Enabling HTTPS**

In our systemd service file, we are granting Keycloak the capability to bind to port 443\. This implies we are running on HTTPS, which is a non-negotiable for an identity server. We cannot send passwords and tokens over plaintext HTTP.

To enable HTTPS, the Keycloak server needs a Java Keystore containing its server certificate and private key.

### **The "Why": Internal Trust**

In this workshop, we are operating in a self-contained lab. All our components (sso-1-a, sso-lb-a, sso-gslb, etc.) need to communicate with each other securely. To achieve this, we use an **Internal Certificate Authority (CA)**.

In **Chapter 1 (Prerequisites)**, you should have run a script to generate all the necessary certificates for this workshop. This script created:

* A Root CA (ca.crt) that acts as our lab's "root of trust."  
* A server certificate/key pair for each VM, signed by our CA.

Now, we will take those generated files and install them on our RHBK nodes.

### **Lab Task: Create and Install the Java Keystore**

You will perform these steps on all four RHBK nodes. **The server.crt and server.key files will be different for each node**, containing the specific hostname (e.g., sso-1-a.mydomain.com).

#### **1\. Create the PKCS12 Keystore**

Keycloak (as a Java application) works best with a .p12 (PKCS12) or .jks keystore. We will use openssl to combine our server's private key and public certificate into a single .p12 file.

This command assumes your generated certificates (server.key, server.crt) and the Root CA certificate (ca.crt) are in a directory.
```sh
# Define a strong password for your new keystore.  
# For this lab, we will use 'password' for simplicity.  
export KEYSTORE\_PASS="password"

# This command bundles the key, the cert, and the CA cert into a single .p12 file.  
# Replace 'server.key' and 'server.crt' with the specific files for this node.  
openssl pkcs12 -export -out server.p12 \  
  -inkey server.key -in server.crt \  
  -certfile ca.crt -passout pass:$KEYSTORE_PASS

echo "Keystore 'server.p12' created."
```

#### **2\. Install the Keystore for Keycloak**

Now, we will copy this new keystore into the Keycloak configuration directory and set the correct permissions so the keycloak user can read it.

```sh
# Copy the keystore to the standard conf directory  
sudo cp server.p12 /opt/keycloak/conf/server.keystore

# Set ownership to the keycloak user  
sudo chown keycloak:keycloak /opt/keycloak/conf/server.keystore

# Set read-only permissions for the owner  
sudo chmod 400 /opt/keycloak/conf/server.keystore
```

#### **3\. Trust the Internal CA System-Wide**

This is a crucial final step. We've given Keycloak its *own* certificate, but we also need the host VM's operating system to trust our Internal CA. This allows system tools (like curl, which our health check script uses) to make secure connections to other internal services without certificate errors.

```sh
# 1\. Copy your Root CA certificate to the system's trust anchor directory  
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/workshop-internal-ca.crt

# 2\. Update the system-wide trust store  
sudo update-ca-trust extract

echo "Internal CA is now trusted by the host OS."
```

#### **4\. Verification**

From the VM's terminal, you should now be able to run a curl command against the server's *own* hostname without a security warning. (Note: The service isn't running yet, so we expect a "Connection refused" error, but *not* a "certificate verify failed" error).

```sh
# This test will fail for now, but it will fail with "Connection refused"  
# which is what we want.  
curl https://sso-1-a.mydomain.com:443
```
*(Expected output: curl: (7) Failed to connect to sso-1-a.mydomain.com port 443: Connection refused)*

**Repeat these steps on all four RHBK nodes.**