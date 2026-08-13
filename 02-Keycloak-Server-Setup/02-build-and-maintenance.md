# **2.2 Build and Maintenance (rebuild\_keycloak.sh)**

In the previous step, we created a systemd service to *run* Keycloak. You'll notice the ExecStart line only contains the kc.sh start \--optimized command. It's missing the kc.sh build command. This is intentional and is a core "professional practice."

### **The "Why": Separating Build from Run**

Think of your Keycloak server like a high-performance application.

* **kc.sh build** is the "compilation" or "optimization" step. It analyzes your configuration, enables features (like hostname:v2 or token-exchange), and builds a lean, optimized server runtime. This process is slow and should only be done *once* when the configuration changes.  
* **kc.sh start** is the "execution" step. It simply runs the fast, pre-optimized server.

By separating these two, our systemd service can restart in seconds (a "run" task), rather than minutes (a "build" task).

To manage this, we will create a dedicated script for our manual, administrative "build" tasks. This script will be our auditable, repeatable way to apply build-time configuration.

### **Lab Task: Create the rebuild\_keycloak.sh Script**

You will perform these steps on all four RHBK nodes: sso-1-a, sso-2-a, sso-1-b, and sso-2-b.

#### **1\. Create the Script File**

We will create the rebuild\_keycloak.sh script inside the /opt/keycloak/bin/ directory. This script will:

* Be owned by the keycloak user.  
* Be run with sudo by an administrator.  
* Include a \--help message for usability.  
* Handle the \--first-init flag to set the initial admin user (for an empty database).  
* Run the actual build process as the keycloak user to maintain correct file permissions.  
* Log every execution to /opt/keycloak/log/rebuild\_keycloak.log for auditing.

Create the following file:

File: **[rebuild_keycloak.sh](/assets/rebuild_keycloak.sh)**
The file must be placed at: `/opt/keycloak/bin/rebuild_keycloak.sh`  
(You can copy this file from the assets directory)  

#### **2\. Set Permissions for the Script**

After creating the file, set the correct ownership and permissions.
```sh
# Set ownership to the keycloak user  
sudo chown keycloak:keycloak /opt/keycloak/bin/rebuild_keycloak.sh

# Make it executable only by the owner (keycloak) and root (via sudo)  
sudo chmod 750 /opt/keycloak/bin/rebuild_keycloak.sh
```

#### **3\. Run the Initial Build**

Now, let's run the build for the first time. Since this is the first setup and our database is empty, we must use the `--first-init` flag to create our initial admin user.
```sh
sudo /opt/keycloak/bin/rebuild_keycloak.sh --first-init
```
You will see the script log its actions and then execute the Keycloak build process. This will take about 20-30 seconds.

#### **4\. Verification**

After the script completes, check the audit log it created:
```sh
cat /opt/keycloak/log/rebuild\_keycloak.log
```
You should see an entry with the timestamp, user, and the build command that was executed.

**Repeat these steps on all four RHBK nodes.**