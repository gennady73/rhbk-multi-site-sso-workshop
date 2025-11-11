# **5.1 Lab: Deploying the Core Observability Stack**

First, we will deploy the main applications (Prometheus, Grafana, Alertmanager, and Splunk) as containers on our sso-mon VM. Using docker-compose (or podman-compose) makes this complex setup a single, repeatable command.

### **The "Why": Why Containers?**

Deploying these tools as containers gives us a clean, isolated, and repeatable environment. We don't have to worry about conflicting libraries on the host RHEL 9 VM, and we can manage the entire stack's lifecycle with simple up and down commands.

### **Step 1: Create the Directory Structure**

On your sso-mon VM, create the directory structure that will hold all the configuration files for our stack.

mkdir \-p /opt/monitoring/{prometheus,alertmanager}

This will result in the following structure, which we will populate with configuration files in the next steps:

/opt/monitoring/  
```bash
├── alertmanager/  
│   └── alertmanager.yml  
├── docker-compose.yml  
└── prometheus/  
    ├── alert.rules.yml  
    └── prometheus.yml
```

### **Step 2: Set Directory Permissions**

As a best practice, we'll set the ownership of this directory to our local user so we can easily edit the configuration files.

\# Replace 'lab-admin' with your actual username, or use $USER  
sudo chown \-R $USER:$USER /opt/monitoring  
chmod \-R 755 /opt/monitoring

### **Step 3: Create the [docker-compose.yml](/assets/docker-compose.yml) File**

This file is the "blueprint" for our stack. It defines the four services we want to run, what ports they use, and which configuration files they should load.

1. Copy the docker-compose.yml file from the assets directory to /opt/monitoring/docker-compose.yml.  
2. **You must edit this file** to match your environment.  
   vi /opt/monitoring/docker-compose.yml

3. Inside the prometheus service, update the extra\_hosts section with the **private IP addresses** of your four RHBK servers. This is critical as it allows the Prometheus container to find your servers using their hostnames.  
   \# ... inside docker-compose.yml  
     extra\_hosts:  
       \- "sso-1-a.mydomain.com:\<sso-1-a\_IP\>"  
       \- "sso-2-a.mydomain.com:\<sso-2-a\_IP\>"  
       \- "sso-1-b.mydomain.com:\<sso-1-b\_IP\>"  
       \- "sso-2-b.mydomain.com:\<sso-2-b\_IP\>"

### **Step 4: Configure the Firewall**

We need to open the ports on our sso-mon VM so we can access the web UIs for our new services.

\# 9090: Prometheus UI  
\# 9093: Alertmanager UI  
\# 3000: Grafana UI  
\# 8000: Splunk Web UI  
\# 9997: Splunk data input port  
sudo firewall-cmd \--permanent \--add-port={9090/tcp,9093/tcp,3000/tcp,8000/tcp,9997/tcp}  
sudo firewall-cmd \--reload

### **Step 5: Launch the Stack**

You are now ready to launch the entire stack with a single command.

\# Navigate to the directory  
cd /opt/monitoring/

\# Launch the containers in detached mode  
\# (Use podman-compose if that is your tool)  
docker-compose up \-d

The first time you run this, it will take a few minutes to download the container images.

### **Step 6: Verify the Stack**

Once the command finishes, check that all four containers are running:

docker-compose ps

You should see prometheus, grafana, alertmanager, and splunk all in an "Up" or "Running" state.

You can now access the UIs in your browser (replace with your sso-mon VM's IP):

* **Grafana:** `http://<sso-mon-ip>:3000` (default login: admin/admin)  
* **Prometheus:** `http://<sso-mon-ip>:9090`  
* **Splunk:** `http://<sso-mon-ip>:8000` (default login: admin/admin \- as set in the compose file)  
* **Alertmanager:** `http://<sso-mon-ip>:9093`

**Status:** Our core observability stack is deployed. It is not yet configured to do anything useful. In the next steps, we will configure Prometheus to scrape our Keycloak servers and Splunk to receive logs.
