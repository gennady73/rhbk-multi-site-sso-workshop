# **6.1 Lab: Deploying an External Infinispan Cluster**

Our first step is to deploy the new, external cache servers. For this workshop, we will run both Infinispan nodes as containers on our sso-mon VM. In a real-world scenario, these would be on their own dedicated VMs within their respective sites.

### **Step 1: Create the Configuration Directory**

On your sso-mon VM, let's create a new directory in our monitoring folder to hold the Infinispan configuration.

```bash
mkdir -p /opt/monitoring/infinispan
```

### **Step 2: Create the Infinispan [docker-compose.yml](/assets/infinispan/docker-compose.yml)**

This file will deploy two Infinispan services, infinispan-a and infinispan-b, simulating the two sites.

File: /opt/monitoring/infinispan/docker-compose.yml  
(**Note**: this is a new compose file, separate from the main monitoring stack)  

```yml
version: '3.8'

services:
  infinispan-a:
    image: infinispan/server:15.0
    container_name: infinispan-site-a
    hostname: infinispan-a
    environment:
      - USER=admin
      - PASS=password
      - SITE_NAME=site-a
      - BACKUP_SITE_NAME=site-b
      # Points to the other container by its service name
      - JGROUPS_TCPPING_INITIAL_HOSTS=infinispan-b[7800]
    ports:
      - "11222:11222" # Site A's port
    volumes:
      - ./infinispan-xsite.xml:/opt/infinispan/server/conf/infinispan-xsite.xml
    command: >
      -c /opt/infinispan/server/conf/infinispan-xsite.xml
      -s /opt/infinispan/server
      -Dinfinispan.site.name=site-a
      -Dinfinispan.backup.site.name=site-b
      -Dinfinispan.cluster.name=rhbk-ispn-cluster
      -Dinfinispan.cluster.stack=tcp-xsite
      -Dinfinispan.node.name=ispn-1-a
      -Djgroups.tcpping.initial_hosts=infinispan-b[7800]

  infinispan-b:
    image: infinispan/server:15.0
    container_name: infinispan-site-b
    hostname: infinispan-b
    environment:
      - USER=admin
      - PASS=password
      - SITE_NAME=site-b
      - BACKUP_SITE_NAME=site-a
      - JGROUPS_TCPPING_INITIAL_HOSTS=infinispan-a[7800]
    ports:
      - "11223:11222" # Site B's port (mapped to 11223 to avoid conflict)
    volumes:
      - ./infinispan-xsite.xml:/opt/infinispan/server/conf/infinispan-xsite.xml
    command: >
      -c /opt/infinispan/server/conf/infinispan-xsite.xml
      -s /opt/infinispan/server
      -Dinfinispan.site.name=site-b
      -Dinfinispan.backup.site.name=site-a
      -Dinfinispan.cluster.name=rhbk-ispn-cluster
      -Dinfinispan.cluster.stack=tcp-xsite
      -Dinfinispan.node.name=ispn-1-b
      -Djgroups.tcpping.initial_hosts=infinispan-a[7800]
```


### **Step 3: Create the [infinispan-xsite.xml](/assets/infinispan/infinispan-xsite.xml) File**

This is the XML configuration file which defines the `JGroups` stacks and the backup strategies for all of Keycloak's caches. The deployment file location is as following.
File: /opt/monitoring/infinispan/infinispan-xsite.xml  
