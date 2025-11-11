# **RHBK Multi-Site High Availability Workshop**

**Welcome\!** As someone working with identity and access management, you've likely seen the evolution from older RH-SSO versions or are perhaps diving into enterprise-grade SSO for the first time. You understand that in a modern infrastructure, an authentication service isn't just a "nice-to-have" utility—it's a critical, tier-zero component. When it goes down, it doesn't just cause an error; it can bring the entire business to a halt.

This workshop is designed as a practical, hands-on journey to build a resilient, multi-site Red Hat Build of Keycloak (RHBK) deployment. We are moving beyond a single-instance setup to tackle the real-world challenge of high availability (HA) and disaster recovery (DR).

**The Challenge:** How do we keep our SSO service running smoothly, even if an entire datacenter or site goes offline? How do we ensure users maintain their sessions during a failover? And how do we build a system that is not only robust but also observable and maintainable?

**Our Approach:** We will build a complete, end-to-end, multi-site architecture on RHEL 9 VMs. We'll leverage RHBK's powerful native features (like multi-site replication), combine them with industry-standard tools like HAProxy and BIND, and build a complete observability stack with Prometheus, Grafana, and Splunk.

Because this is a workshop using a non-registered domain, we will also implement a clever **Global Server Load Balancer (GSLB) simulation** using HAProxy and BIND. This gives us all the automated, health-check-driven failover benefits of a real GSLB without the cost and complexity of public DNS delegation.


## **Target Audience**

This guide is aimed at **DevOps engineers, system administrators, and architects** who have a solid grasp of general IT concepts (like networking, VMs) but are new to SSO or are migrating from an older RH-SSO product. We will not assume deep prior knowledge of Keycloak itself.


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


## **Workshop Structure (Learning Objectives)**

This workshop is divided into the following labs. It is recommended to proceed in order.

* 01 **[Introduction](/01-Introduction/introduction.md)**

   * [Overview](/01-Introduction/introduction.md#11-the-challenge-why-multi-site)
   * [Architecture](/01-Introduction/introduction.md#13-workshop-architecture-overview)
   * [Choosing Your Caching Path (Path A vs. Path B)](/01-Introduction/introduction.md#14-critical-concept-the-two-learning-paths-for-caching)
   * [Prerequisites](/01-Introduction/introduction.md#15-workshop-prerequisites)

* 02 **[RHBK-Server-Setup](/02-RHBK-Server-Setup/README.md)**

   * [Configuring a secure systemd service](/02-RHBK-Server-Setup/01-service-management.md)    
   * [Hardening the build and maintenance lifecycle](/02-RHBK-Server-Setup/02-build-and-maintenance.md)    
   * [TLS and Keystore setup](/02-RHBK-Server-Setup/03-certificate-setup.md)    
   * [Base server configuration (keycloak.conf)](/02-RHBK-Server-Setup/04-core-configuration.md)    

* 03 **[Multi-Site-Replication](/03-Multi-Site-Replication/README.md)**

   * [Implementing the "Split Path" caching configuration](/03-Multi-Site-Replication/README.md#the-two-learning-paths-for-caching)
   * [Path A: Native RHBK Multi-Site (Embedded Cache)](/03-Multi-Site-Replication/01-rhbk-ispn-int-deployment.md)    
   * Path B
      * [Path B: RHBK Multi-Site (Remote Cache)](/03-Multi-Site-Replication/02-rhbk-ispn-ext-deployment.md)    
      * [Path B: External Infinispan Cross-Site (Remote Cache)](/03-Multi-Site-Replication/03-ispn-ext-deployment.md)    

* 04 **[Site-LoadBalancers](/04-Site-Local-Load-Balancers/README.md)**

   * [Configuring site-local HAProxy instances](/04-Site-Local-Load-Balancers/01-site-local-HAProxy-configuration.md)
   * TLS Termination and Forwarded headers
   * [Session affinity (stickiness) using KC_SESSION](/04-Site-Local-Load-Balancers/01-site-local-HAProxy-configuration.md#step-5-create-the-haproxy-configuration)    

* 05 **[GSLB-Simulation](/05-GSLB-Simulation/README.md)**

   * Simulating a Global Server Load Balancer (GSLB)
   * [Configuring BIND as an authoritative DNS server](/05-GSLB-Simulation/bind-setup.md)    
   * [Configuring the global HAProxy entrypoint](/05-GSLB-Simulation/global-haproxy.md)    
   * [Implementing the gslb_check.sh health check script](/05-GSLB-Simulation/health-check-script.md)    

* 06 **[Observability-Stack](/06-Observability-Stack/README.md)**
   * [Deploying the stack (Prometheus, Grafana, Splunk) via docker-compose](/06-Observability-Stack/01-deployment.md)    
   * [Configuring Prometheus to scrape RHBK metrics](/06-Observability-Stack/02-prometheus-config.md)    
   * [Integrating Splunk for log aggregation](/06-Observability-Stack/03-splunk-config.md)    
   * [Configuring Alertmanager](/06-Observability-Stack/04-alertmanager-config.md)
   * [Importing and analyzing Grafana dashboards](/06-Observability-Stack/05grafana-setup.md)    


## **References**
   At moment of writing this workshop guide, the latest released version was `RHBK v.26.2.x`.

- [Red Hat Build of Keycloak 26.2 - Server Configuration Guide.](https://docs.redhat.com/ko/documentation/red_hat_build_of_keycloak/26.2/pdf/server_configuration_guide/index)

- [Red Hat Build of Keycloak 26.2 - High Availability Guide.](https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/26.2/pdf/high_availability_guide/Red_Hat_build_of_Keycloak-26.2-High_Availability_Guide-en-US.pdf)

- [Keycoak - Configuring distributed caches.](https://www.keycloak.org/server/caching)
