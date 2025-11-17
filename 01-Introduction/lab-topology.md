# **Chapter 1: RHBK Lab Topology \- The Infrastructure inventory**
The following is defines the target topology, including all hostnames and IP addresses, for our multi-site workshop.    
The lab is divided into two paths (A and B) which have different resource requirements.

Before you begin, you **must** choose which caching path you will follow. The topology you build depends on this choice.

## **Path A: Embedded Cache Architecture**

This is the standard, recommended topology. In this model, the RHBK servers use their own **built-in** Infinispan caches and are configured to replicate data directly with each other across sites.

**Total Resources:** 10 core service nodes.

| Role | Hostname | IP Address | Site | Notes |
| :---- | :---- | :---- | :---- | :---- |
| RHBK Node 1 | sso-1-a | 10.10.1.11 | Site A |  |
| RHBK Node 2 | sso-2-a | 10.10.1.12 | Site A |  |
| Site LB | lb-a | 10.10.1.100 | Site A | VIP: sso.site-a.mydomain.com |
| RHBK Node 1 | sso-1-b | 10.10.2.11 | Site B |  |
| RHBK Node 2 | sso-2-b | 10.10.2.12 | Site B |  |
| Site LB | lb-b | 10.10.2.100 | Site B | VIP: sso.site-b.mydomain.com |
| RHBK Node 1 | sso-1-c | 10.10.3.11 | Site C |  |
| RHBK Node 2 | sso-2-c | 10.10.3.12 | Site C |  |
| Site LB | lb-c | 10.10.3.100 | Site C | VIP: sso.site-c.mydomain.com |
| Database | db.shared | 10.10.0.50 | Shared | PostgreSQL v16 |
| GSLB / DNS | gslb | 10.10.0.10 | Shared | BIND & Global HAProxy. VIP: sso.mydomain.com |
| Observability | monitor | 10.10.0.20 | Shared | Docker host (Prometheus, Grafana) |

## **EXTERNAL Path B: External Infinispan Architecture**

This is the advanced topology. In this model, the RHBK servers are configured as "clients" and offload all caching to a **separate, external Infinispan cluster**.

This path requires **all the nodes from Path A**, **PLUS** a new 3-node Infinispan cluster.

**Total Resources:** 13+ core service nodes.

### **Part 1: RHBK, LB, and Shared Services (Identical to Path A)**

| Role | Hostname | IP Address | Site | Notes |
| :---- | :---- | :---- | :---- | :---- |
| RHBK Node 1 | sso-1-a | 10.10.1.11 | Site A |  |
| RHBK Node 2 | sso-2-a | 10.10.1.12 | Site A |  |
| Site LB | lb-a | 10.10.1.100 | Site A | VIP: sso.site-a.mydomain.com |
| RHBK Node 1 | sso-1-b | 10.10.2.11 | Site B |  |
| RHBK Node 2 | sso-2-b | 10.10.2.12 | Site B |  |
| Site LB | lb-b | 10.10.2.100 | Site B | VIP: sso.site-b.mydomain.com |
| RHBK Node 1 | sso-1-c | 10.10.3.11 | Site C |  |
| RHBK Node 2 | sso-2-c | 10.10.3.12 | Site C |  |
| Site LB | lb-c | 10.10.3.100 | Site C | VIP: sso.site-c.mydomain.com |
| Database | db.shared | 10.10.0.50 | Shared | PostgreSQL v16 |
| GSLB / DNS | gslb | 10.10.0.10 | Shared | BIND & Global HAProxy. VIP: sso.mydomain.com |
| Observability | monitor | 10.10.0.20 | Shared | Docker host (Prometheus, Grafana) |

### **Part 2: New External Infinispan Cluster**

These are the **additional nodes** required *only* for Path B.      
We will deploy an Infinispan community cluster here.    
**NOTE:** As alternative, a standalone Red Hat Data Grid [(RHDG)](https://docs.redhat.com/en/documentation/red_hat_data_grid/8.5) may be deployed and used instead.   

| Role | Hostname | IP Address | Site | Notes |
| :---- | :---- | :---- | :---- | :---- |
| Infinispan Node 1 | ispn-1 | 10.10.0.31 | Shared |  |
| Infinispan Node 2 | ispn-2 | 10.10.0.32 | Shared |  |
| Infinispan Node 3 | ispn-3 | 10.10.0.33 | Shared |  |
