# **Chapter 6: (Advanced) Alternative Caching \- External Infinispan**

### **The Story So Far**

Our RHBK cluster is fully operational using the modern, **native multi-site** feature (multi-site-enabled=true). This is a simple, elegant, and powerful solution where the Keycloak servers themselves form a single, distributed cache across both sites.

### **The New Scenario: An Alternative Architecture**

Before the "native" feature existed, the *only* way to achieve cross-site replication was by using a completely **external Infinispan cluster**. This architecture is more complex but offers different scaling characteristics.

**The "Why":**

* **Decoupled Scaling:** In this model, the Infinispan cache cluster is a separate service. You can scale your Keycloak "application" nodes (which become stateless) and your "cache" nodes (Infinispan) independently.  
* **Legacy / RH-SSO Migration:** This is the architecture that older RH-SSO 7.x versions used. Understanding it is critical for migrating or managing older systems.

In this advanced, optional chapter, we will **replace** our native multi-site setup with this external Infinispan architecture.

### **Architecture Comparison**

| Native Multi-Site (What we have) | External Infinispan (What we are building) |
| :---- | :---- |
| **Simple:** Keycloak handles all clustering. | **Complex:** Requires deploying, managing, and securing a separate Infinispan cluster. |
| **Combined:** App and cache scale together. | **Decoupled:** App nodes and cache nodes can be scaled independently. |
| **Configuration:** keycloak.conf | **Configuration:** keycloak.conf \+ infinispan-xsite.xml \+ Infinispan startup scripts. |

### **Lab Task Overview**

1. **[Deploy External Infinispan:](/06-Alternative-Caching-External-Infinispan/ispn-ext-deployment.md)** We will deploy two new Infinispan server containers on our sso-mon VM (one for Site A, one for Site B) using docker-compose.  
2. **[Configure Infinispan:](/06-Alternative-Caching-External-Infinispan/ispn-ext-deployment.md#step-3-create-the-infinispan-xsitexml-file)** We will provide the infinispan-xsite.xml file to configure them for cross-site replication with each other.  
3. **[Re-configure RHBK:](/06-Alternative-Caching-External-Infinispan/rhbk-configuration.md)** We will update our keycloak.conf on all four RHBK nodes to disable the native multi-site feature and point to these new external servers instead.
