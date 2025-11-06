# **RHBK Multi-Site High Availability Workshop**

**Welcome\!** As someone working with identity and access management, you've likely seen the evolution from older RH-SSO versions or are perhaps diving into enterprise-grade SSO for the first time. You understand that in a modern infrastructure, an authentication service isn't just a "nice-to-have" utility—it's a critical, tier-zero component. When it goes down, it doesn't just cause an error; it can bring the entire business to a halt.

This workshop is designed as a practical, hands-on journey to build a resilient, multi-site Red Hat Build of Keycloak (RHBK) deployment. We are moving beyond a single-instance setup to tackle the real-world challenge of high availability (HA) and disaster recovery (DR).

**The Challenge:** How do we keep our SSO service running smoothly, even if an entire datacenter or site goes offline? How do we ensure users maintain their sessions during a failover? And how do we build a system that is not only robust but also observable and maintainable?

**Our Approach:** We will build a complete, end-to-end, multi-site architecture on RHEL 9 VMs. We'll leverage RHBK's powerful native features (like multi-site replication), combine them with industry-standard tools like HAProxy and BIND, and build a complete observability stack with Prometheus, Grafana, and Splunk.

Because this is a workshop using a non-registered domain, we will also implement a clever **Global Server Load Balancer (GSLB) simulation** using HAProxy and BIND. This gives us all the automated, health-check-driven failover benefits of a real GSLB without the cost and complexity of public DNS delegation.

## **Workshop Goals**

By the end of this workshop, you will have:

1. **Deployed** a two-site RHBK cluster (v26.2) on RHEL 9 VMs.  
2. **Configured** RHBK to run as a secure, unprivileged systemd service.  
3. **Implemented** intra-site (within a site) clustering using RHBK's embedded Infinispan cache.  
4. **Explored** and **compared** two different cross-site replication models:  
   * RHBK's **native multi-site feature**.  
   * The **external Infinispan cluster** model.  
5. **Set up** site-local high availability using HAProxy load balancers.  
6. **Simulated** a Global Server Load Balancer (GSLB) for automated, health-check-driven site failover.  
7. **Deployed** a containerized observability stack (Prometheus, Grafana, Alertmanager, Splunk).  
8. **Configured** monitoring for RHBK metrics and logs.  
9. **Understood** the key architectural decisions and trade-offs involved in a multi-site HA deployment.

## **High-Level Architecture**

We will build the following three-site architecture:

* **Site A & Site B:** Identical application sites, each containing two RHBK nodes and a local HAProxy load balancer.  
* **Site Zero:** An independent management site hosting our GSLB simulation components (BIND DNS, Global HAProxy), our central Observability Stack, and our database.  
* **Internal CA:** All TLS communication will be secured using certificates from a private Certificate Authority we will create.

*(This diagram, from your SSO High-Level Architecture.docx, illustrates the relationship between Site A, Site B, and Site Zero.)*

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