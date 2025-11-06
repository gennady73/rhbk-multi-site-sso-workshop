# **Chapter 1: Introduction \- Building a Resilient SSO Infrastructure**

Welcome to the workshop\!

## **1.1 The Challenge: Why Multi-Site?**

You are likely here because you need to provide a truly high-availability (HA) authentication service. A single Keycloak instance, or even a single cluster in one datacenter, represents a single point of failure. Modern enterprises require services that can survive network outages, datacenter maintenance, or even a full site disaster.

**Our Goal:** In this workshop, we will build a complete, end-to-end, multi-site Red Hat Build of Keycloak (RHBK) architecture. We will simulate two distinct geographical sites (Site A and Site B) and a third "management" site (Site Zero). We will configure our RHBK nodes for cross-site replication and build an automated global failover system on top of them.

This is a "story" in chapters. We will start with a single server, make it a robust systemd service, cluster it, build a second site, and then, piece by piece, add the load balancing, DNS failover, and observability that constitute a complete enterprise solution.

## **1.2 Target Audience & Learning Objectives**

This guide is aimed at **DevOps engineers, system administrators, and architects** who have a solid grasp of general IT concepts (like networking, VMs) but are new to SSO or are migrating from an older RH-SSO product. We will not assume deep prior knowledge of Keycloak itself.

**By completing this workshop, you will learn how to:**

* Install and configure RHBK v26.2 in a clustered, multi-site topology.  
* Securely run RHBK as a systemd service using best practices.  
* Configure **both native and external** Infinispan models for cross-site replication and understand the trade-offs.  
* Configure HAProxy for both site-local load balancing and GSLB simulation.  
* Set up BIND as a dynamic, health-check-driven DNS server for failover.  
* Deploy and configure a Prometheus/Grafana/Splunk stack for observability.

## **1.3 Why a VM-Based Workshop?**

While Kubernetes and OpenShift are powerful platforms for deploying Keycloak, this workshop intentionally focuses on a **VM-based deployment using RHEL 9**. This is a deliberate choice for several key reasons:

1. **Focus on Fundamentals:** We want to **understand the fundamentals of RHBK on VMs in order to remove the complexity of a Kubernetes/OpenShift cluster layer.** By deploying directly onto VMs, we remove orchestration abstractions and can see exactly how the components interact at the OS and network level.  
2. **Clearer Networking:** Multi-site networking, cross-site communication (like Infinispan replication), and GSLB simulation involve intricate network configurations. Managing these directly on VMs with distinct IP subnets makes the traffic flow and firewall rules explicit and easier to grasp.  
3. **Real-World Use Case (Service Independence):** Many organizations run their core identity services on dedicated VMs *outside* of their application-hosting platforms. This provides a critical benefit: **the SSO service remains available even if the Kubernetes/OpenShift cluster is unavailable** (e.g., during an upgrade, a CNI failure, or a full cluster outage). This independent, VM-based SSO can then serve *multiple* platforms (K8s, legacy apps, etc.) as a stable, external dependency.  
4. **Broader Applicability:** The principles you learn here are directly transferable. Mastering this setup provides a rock-solid foundation that makes a future transition to a containerized deployment much easier.

## **1.4 Lab Architecture Overview**

We will simulate a three-site setup.

* **Site A & Site B:** Our primary application sites. Each will host two RHBK nodes behind a local HAProxy instance.  
* **Site Zero:** An independent site hosting our "Global" services:  
  * A BIND DNS server and HAProxy instance that work together to simulate a GSLB.  
  * A dedicated Database VM (PostgreSQL).  
  * A dedicated Monitoring VM (Prometheus, Grafana, etc.).

### **A Note on the Database**

For this workshop, we will provision a **dedicated, separate VM for our PostgreSQL database** (sso-db).

* **Why?** This mimics a real-world enterprise "shared services" model, where the database is a central resource, not co-located with a single application. This also allows this workshop environment to be extended, with other services potentially using the same DB server.  
* **Low-Resource Alternative:** If you are constrained by hardware, you could choose to install the PostgreSQL server on the same VM as the Monitoring Stack (sso-mon). The workshop will proceed with the dedicated VM, but the configuration is easily adaptable.  
* **Production Note:** For a true production HA setup, this single database would be replaced by a high-availability, active-active replicated database cluster.

## **1.5 Let's Begin\!**

Ready to start building? Proceed to the next chapter: **Workshop Prerequisites & Initial Setup**.