# **Chapter 3: (Advanced) Alternative Caching \- External Infinispan**

### **The Story So Far**

Our RHBK cluster is fully operational using the modern, **native multi-site** feature (multi-site-enabled=true). This is a simple, elegant, and powerful solution where the Keycloak servers themselves form a single, distributed cache across both sites.

### **The New Scenario: An Alternative Architecture**

Before the "native" feature existed, the *only* way to achieve cross-site replication was by using a completely **external Infinispan cluster**. This architecture is more complex but offers different scaling characteristics.

**The "Why":**

* **Decoupled Scaling:** In this model, the Infinispan cache cluster is a separate service. You can scale your Keycloak "application" nodes (which become stateless) and your "cache" nodes (Infinispan) independently.  
* **Legacy / RH-SSO Migration:** This is the architecture that older RH-SSO 7.x versions used. Understanding it is critical for migrating or managing older systems.

In this advanced, optional chapter, we will **replace** our native multi-site setup with this external Infinispan architecture.

## **The Two Learning Paths for Caching**

A primary goal of this workshop is to give you hands-on experience with the two officially supported methods for cross-site replication in RHBK 26.2. They have different trade-offs, and the choice between them is critical.

* **Path A: Native RHBK Multi-Site (Embedded Cache)**  
  * **What it is:** This model uses the built-in, embedded Infinispan cache within each RHBK server node. The RHBK multi-site feature is enabled directly in keycloak.conf.  
  * **How it works:** The RHBK nodes themselves are responsible for both intra-site clustering (nodes in Site A finding each other) and inter-site replication (Site A sending session data to Site B) using the JGroups RELAY2 protocol.  
* **Path B: External Infinispan Cross-Site (Decoupled Cache)**  
  * **What it is:** This model uses a separate, standalone cluster of Infinispan servers. The RHBK nodes are configured as clients that connect to this external cache.  
  * **How it works:** The RHBK nodes are *not* clustered with each other. They simply connect to the external Infinispan cluster. The external Infinispan nodes *then* handle all clustering and cross-site replication (e.g., ispn-1-a in Site A replicates to ispn-1-b in Site B).

#### **Caching Architecture Comparison**

The following matrix breaks down the pros, cons, and scaling differences you requested.

| Feature | Path A: Native RHBK Multi-Site (Embedded) | Path B: External Infinispan (Decoupled) |
| :---- | :---- | :---- |
| **Architecture** | **Coupled:** Infinispan cache runs inside the RHBK JVM. | **Decoupled:** RHBK and Infinispan run in separate processes(usually, on remote server). |
| **Key Config** | cache=ispn, multi-site-enabled=true | cache-stack=tcp, cache-remote-host=... |
| **Use Case** | Simpler deployments, smaller environments, or where operational simplicity is key. | Large-scale, high-throughput environments requiring fine-tuned cache control. |
| **Scaling Model** | **Coupled:** To add cache capacity, you must add a full RHBK node (Cache \+ Keycloak). | **Independent:** You can scale the RHBK application tier and the Infinispan cache tier separately. |
| **Pros** | \- **Simpler Setup:** Fewer moving parts; no separate cache cluster to manage. \- **Lower Resource "Floor":** Fewer VMs/processes required to get started. | \- **Independent Scaling:** Add RHBK nodes for auth load or Infinispan nodes for cache load. \- **Fine-Tuned Cache:** Full access to advanced Infinispan tuning. \- **Resilience:** RHBK restarts do not restart the cache, preserving state. |
| **Cons** | \- **Coupled Scaling:** A temporary login surge may force you to scale up expensive cache nodes. \- **"Noisy Neighbor":** A busy cache (e.g., during replication) can impact RHBK performance (CPU/Memory). \- **Opaque:** Harder to tune the embedded cache. | \- **Complexity:** Requires managing, securing, and monitoring a separate cluster. \- **Higher Resource "Floor":** Requires more VMs/processes to start. \- **Network Hop:** Adds a network call from RHBK to Infinispan. |
| **Network/Protocol** | 1\. **Intra-Site:** JGroups (e.g., jdbc-ping) for node discovery. 2\. **Inter-Site:** JGroups RELAY2 protocol for replication. | 1\. **RHBK \-\> Infinispan:** Hot Rod protocol (client-server). 2\. **Infinispan Intra-Site:** JGroups (e.g., tcp-ping). 3\. **Infinispan Inter-Site:** JGroups RELAY2 protocol. |


### **Architecture Comparison**

| Native Multi-Site (What we have) | External Infinispan (What we are building) |
| :---- | :---- |
| **Simple:** Keycloak handles all clustering. | **Complex:** Requires deploying, managing, and securing a separate Infinispan cluster. |
| **Combined:** App and cache scale together. | **Decoupled:** App nodes and cache nodes can be scaled independently. |
| **Configuration:** keycloak.conf | **Configuration:** keycloak.conf \+ infinispan-xsite.xml \+ Infinispan startup scripts. |


### **Lab Task Overview**

* **Path A: Native RHBK Multi-Site (Embedded Cache)**  
1. **[Configure RHBK and Infinispan:](/03-Multi-Site-Replication/01-rhbk-ispn-int-deployment.md)** We will update our keycloak.conf on all four RHBK nodes to configure a multi-site cluster using the embedded Infinispan cache.  

* **Path B: External Infinispan Cross-Site (Decoupled Cache)**  
1. **[Deploy External Infinispan:](/03-Multi-Site-Replication/01-ispn-ext-deployment.md)** We will deploy two new Infinispan server containers on our sso-mon VM (one for Site A, one for Site B) using docker-compose.  
2. **[Re-configure RHBK:](/03-Multi-Site-Replication/02-rhbk-ispn-ext-deployment.md)** We will update our keycloak.conf on all four RHBK nodes to disable the native multi-site feature and point to these new external servers instead.
3. **[Configure Infinispan:](/03-Multi-Site-Replication/03-ispn-ext-deployment.md#step-3-create-the-infinispan-xsitexml-file)** We will provide the infinispan-xsite.xml file to configure them for cross-site replication with each other.  

