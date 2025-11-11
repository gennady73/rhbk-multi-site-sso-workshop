# **Chapter 1: Introduction \- Building a Resilient SSO Infrastructure**

Welcome to the workshop\!

## **1.1 The Challenge: Why Multi-Site?**

You are likely here because you need to provide a truly high-availability (HA) authentication service. A single Keycloak instance, or even a single cluster in one datacenter, represents a single point of failure. Modern enterprises require services that can survive network outages, datacenter maintenance, or even a full site disaster.

**Our Goal:** In this workshop, we will build a complete, end-to-end, multi-site Red Hat Build of Keycloak (RHBK) architecture. We will simulate two distinct geographical sites (Site A and Site B) and a third "management" site (Site Zero). We will configure our RHBK nodes for cross-site replication and build an automated global failover system on top of them.

This is a "story" in chapters. We will start with a single server, make it a robust systemd service, cluster it, build a second site, and then, piece by piece, add the load balancing, DNS failover, and observability that constitute a complete enterprise solution.

## **1.2 Why a VM-Based Workshop?**

While Kubernetes and OpenShift are powerful platforms for deploying Keycloak, this workshop intentionally focuses on a **VM-based deployment using RHEL 9**. This is a deliberate choice for several key reasons:

1. **Focus on Fundamentals:** We want to **understand the fundamentals of RHBK on VMs in order to remove the complexity of a Kubernetes/OpenShift cluster layer.** By deploying directly onto VMs, we remove orchestration abstractions and can see exactly how the components interact at the OS and network level.  
2. **Clearer Networking:** Multi-site networking, cross-site communication (like Infinispan replication), and GSLB simulation involve intricate network configurations. Managing these directly on VMs with distinct IP subnets makes the traffic flow and firewall rules explicit and easier to grasp.  
3. **Real-World Use Case (Service Independence):** Many organizations run their core identity services on dedicated VMs *outside* of their application-hosting platforms. This provides a critical benefit: **the SSO service remains available even if the Kubernetes/OpenShift cluster is unavailable** (e.g., during an upgrade, a CNI failure, or a full cluster outage). This independent, VM-based SSO can then serve *multiple* platforms (K8s, legacy apps, etc.) as a stable, external dependency.  
4. **Broader Applicability:** The principles you learn here are directly transferable. Mastering this setup provides a rock-solid foundation that makes a future transition to a containerized deployment much easier.

## **1.3 Workshop Architecture Overview**

We will build an architecture which simulates a three-site setup.

* **Site A & Site B:** Our primary application sites. Each will host two RHBK nodes behind a local HAProxy instance.  
* **Site Zero:** An independent site hosting our "Global" services:  
  * A BIND DNS server and HAProxy instance that work together to simulate a GSLB.  
  * A dedicated Database VM (PostgreSQL).  
  * A dedicated Monitoring VM (Prometheus, Grafana, etc.).

The following diagram illustrates the relationship between Site A, Site B, and Site Zero.   

   ![The relationship between Site A, Site B, and Site Zero](/assets/rhbk-ws-high-level-architecture.png "This diagram illustrates the relationship between Site A, Site B, and Site Zero.")

### **A Note on the internal CA:** 
All TLS communication will be secured using certificates from a private Certificate Authority we will create.

### **A Note on the Database**

For this workshop, we will provision a **dedicated, separate VM for our PostgreSQL database** (sso-db).

* **Why?** This mimics a real-world enterprise "shared services" model, where the database is a central resource, not co-located with a single application. This also allows this workshop environment to be extended, with other services potentially using the same DB server.  
* **Low-Resource Alternative:** If you are constrained by hardware, you could choose to install the PostgreSQL server on the same VM as the Monitoring Stack (sso-mon). The workshop will proceed with the dedicated VM, but the configuration is easily adaptable.  
* **Production Note:** For a true production HA setup, this single database would be replaced by a high-availability, active-active replicated database cluster.

## **1.4 Critical Concept: The Two Learning Paths for Caching**

A primary goal of this workshop is to give you hands-on experience with the two officially supported methods for cross-site replication in RHBK 26.2. They have different trade-offs, and the choice between them is critical.

* **Path A: Native RHBK Multi-Site (Embedded Cache)**  
  * **What it is:** This model uses the built-in, embedded Infinispan cache within each RHBK server node. The RHBK multi-site feature is enabled directly in keycloak.conf.  
  * **How it works:** The RHBK nodes themselves are responsible for both intra-site clustering (nodes in Site A finding each other) and inter-site replication (Site A sending session data to Site B) using the JGroups RELAY2 protocol.  
* **Path B: External Infinispan Cross-Site (Remote Cache)**  
  * **What it is:** This model uses a separate, standalone cluster of Infinispan servers. The RHBK nodes are configured as clients that connect to this external cache.  
  * **How it works:** The RHBK nodes are *not* clustered with each other. They simply connect to the external Infinispan cluster. The external Infinispan nodes *then* handle all clustering and cross-site replication (e.g., ispn-1-a in Site A replicates to ispn-1-b in Site B).

* **Choosing Path**
  You will implement **Path A** in Lab 03\. An optional "Challenge Lab" will guide you on how to re-configure the cluster for **Path B**, allowing you to directly compare the two. The following [Caching Architecture Comparison](/03-Multi-Site-Replication/caching-configuration-paths.md) breaks down the pros, cons, and scaling differences you requested.

## **1.5 Workshop Prerequisites**

Ready to start building?

## **Prerequisites**

Before starting, you will need to provision the virtual environment for our workshop.

### **VM Requirements**

You will need a total of **8 VMs** running RHEL 9, distributed across three simulated networks.

| VM Role | Site | Quantity | vCPU | RAM | Disk | Hostname (example) |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| RHBK Node | Site A | 2 | 2 | 4 GB | 30 GB | sso-1-a, sso-2-a |
| RHBK Node | Site B | 2 | 2 | 4 GB | 30 GB | sso-1-b, sso-2-b |
| Site LB | Site A | 1 | 1 | 1 GB | 20 GB | sso-lb-a |
| Site LB | Site B | 1 | 1 | 1 GB | 20 GB | sso-lb-b |
| GSLB / DNS | Site Zero | 1 | 2 | 2 GB | 20 GB | sso-gslb |
| Database | Site Zero | 1 | 2 | 4 GB | 30 GB | sso-db |
| Monitoring | Site Zero | 1 | 4 | 8 GB | 50 GB | sso-mon |

**Note on Database VM:** For this workshop, we are provisioning a separate database server (sso-db). This reflects a realistic enterprise model where the database is a shared service, reusable by other applications or workshops. If you are constrained on resources, you could install the PostgreSQL database on the sso-mon VM, but this guide will assume a dedicated server.

### **Software Requirements**

* RHEL 9 ISO or VM template.  
* RHBK v26.2.x ZIP distribution (downloaded from Red Hat Customer Portal).  
* Splunk Universal Forwarder .rpm package.  
* podman and podman-compose (or Docker) available on the Monitoring VM.  
* Basic Linux skills (using vi/nano, systemd, firewalld, running scripts).  
* Conceptual understanding of DNS, Load Balancing, and HTTPS/TLS principles.


