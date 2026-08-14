# **Red Hat Build of Keycloak (RHBK) Multi-Site High Availability Workshop**

An interactive, hands-on technical laboratory engineered to deploy, secure, and validate a highly available, multi-site Single Sign-On (SSO) infrastructure using **Red Hat Build of Keycloak (v26.2/v26.6)** on **RHEL 9 Virtual Machines and Bare-Metal** environments.

---

### **⚠️ CRITICAL DISCLAIMER**

> **EXPERIMENTAL Proof of Concept (POC) Warning**
>
> This workshop guide is an experimental proof of concept and is intended strictly for educational and self-paced learning purposes. It represents a transition effort from legacy versions toward RHBK 26.2+. 
> 
> *   **No Official Support:** This is NOT an officially supported Red Hat product, reference architecture, or consulting delivery standard.
> *   **Production Warning:** DO NOT deploy these configuration files, scripts, or architectures directly into a production environment. 
> *   **Inherent Risks:** An experimental approach tests new ideas without a long track record. It involves unknown risks, fast learning loops, and uncertain results.
> *   **Liability:** All materials, templates, and automation playbooks are provided "as-is" for demonstration only. For production-grade architectures, consult official Red Hat documentation and authorized support channels.

---

### **Workshop Overview & Architectural Narrative**

In modern enterprise infrastructures, authentication services are classified as **Tier-Zero critical components**. If the SSO tier fails, entire business operations grind to a halt. 

While containerized orchestration platforms (like Red Hat OpenShift) represent Red Hat's primary product path, layering Kubernetes on top of distributed identity clusters often obscures the fundamental mechanics of network binding, JGroups clustering, and cross-site cache replication. 

By stripping away the container abstractions, this workshop deploys Keycloak directly onto **pure RHEL 9 virtual machines**. This unmasks the low-level operating system configurations, systemd process management rules, local and global proxy routing protocols, and active-active serialization parameters that drive high-availability clusters.

---

### **The "Split-Path" Caching Strategy**

A core objective of this workshop is to evaluate and compare the two officially supported multi-site replication models in the Red Hat Build of Keycloak ecosystem:

#### **Path A: Native RHBK Multi-Site (Embedded Cache)**
*   **Mechanics:** Infinispan runs coupled inside Keycloak's JVM process.
*   **Intra-Site Discovery:** Driven natively by JGroups protocols (utilizing a shared SQL database table via `JDBC_PING` to prevent multicast requirements).
*   **Cross-Site Replication:** Handled directly by the Keycloak nodes forwarding backup updates across sites via JGroups `RELAY2`.
*   **Use Case:** Highly optimal for smaller, lightweight footprints where operational simplicity and low resource overhead are prioritized.

#### **Path B: Standalone Infinispan (Decoupled Cache)**
*   **Mechanics:** Keycloak acts as a stateless application layer connecting as a client to a completely independent, remote Infinispan cluster.
*   **Communication:** Keycloak communicates with local cache servers using the high-performance binary **Hot Rod protocol**.
*   **Cross-Site Replication:** Offloaded entirely to the standalone Infinispan nodes, which handle JGroups `RELAY2` replication over the WAN.
*   **Use Case:** Large-scale, high-throughput environments where cache scaling (memory-dense) and authentication scaling (CPU-heavy) must be managed independently.

---

### **Workshop Project Roadmap**

This repository is structured around a continuous modernization roadmap, moving from a manual blueprint to automated cloud-native environments:

```
┌─────────────────────────────────┐
│ Phase 1: Foundational Baseline  │ ◄── [Current Workshop Focus]
│ (Manual RHEL 9 VMs, Custom PKI) │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  Phase 2: Enterprise Automation │
│ (Ansible IaC, Red Hat Data Grid)│
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│ Phase 3: Cloud-Native Hybrid    │
│ (OpenShift, Operators, Galera)  │
└─────────────────────────────────┘
```

*   **Phase 1 (V1) - Foundational Baseline:** Manual configuration of four RHEL 9 VM nodes, active-active local HAProxy instances, custom BIND DNS failover scripts, and containerized Prometheus/Splunk monitoring.
*   **Phase 2 (V2) - Enterprise Automation:** Transitioning VM configurations to automated, idempotent **Ansible Playbooks** and upgrading the caching layer to **Red Hat Data Grid (RHDG)**.
*   **Phase 3 (V3) - Cloud-Native Hybrid:** Migrating application instances to separate OpenShift clusters managed by Operators, using **OpenShift Virtualization (KubeVirt)** to host legacy services, and establishing a geographically distributed active-active database.

---

### **Workshop Structure & Lab Guide**

Follow the labs sequentially to build your multi-site SSO environment:

#### **Chapter 1: Foundations**
*   [1.1 Architecture & Core Goals](./00-Architecture-Overview/./01-system-overview.md)

#### **Chapter 2: RHBK Core Server Setup**
*   [2.1 Service Management (systemd) Guide](./02-Keycloak-Server-Setup/01-service-management.md)
*   [2.2 Administrative Build & Maintenance Guide](02-Keycloak-Server-Setup/02-build-and-maintenance.md)
*   [2.3 Automated PKI and Certificate Setup](./02-Keycloak-Server-Setup/03-certificate-setup.md)
*   [2.4 Core Server Configuration (keycloak.conf)](./02-Keycloak-Server-Setup/04-core-configuration.md)

#### **Chapter 3: Caching & Replication Modernization**
*   [3.1 Path A: Embedded Intra-Site Clustering Guide](./03-High-Availability-Core/01-rhbk-ispn-int-deployment.md)
*   [3.2 Path B: External Infinispan Client Configuration](./03-High-Availability-Core/02-rhbk-ispn-ext-deployment.md)
*   [3.3 Path B: Standalone Infinispan Cluster XML Setup](./03-High-Availability-Core/03-ispn-ext-deployment.md)
*   [3.4 Firewalld Port Mapping & Security Hardening](./03-High-Availability-Core/04-firewall.md)

#### **Chapter 4: Site-Local Load Balancers**
*   [4.1 HAProxy Local Configuration & Stickiness](./04-Load-Balancing-and-Failover/01-site-local-HAProxy-configuration.md)

#### **Chapter 5: GSLB Simulation**
*   [5.1 BIND Authoritative DNS Setup](./05-External-Infrastructure/01-bind-setup.md)
*   [5.2 health_check.sh nsupdate Failover Engine](./05-External-Infrastructure/02-health-check-script.md)
*   [5.3 Global HAProxy Resolver Front Door](./05-External-Infrastructure/03-global-haproxy.md)

---

### **System Requirements & Lab Topology**

To establish the complete multi-site simulation, the lab topology defines ten virtual interfaces mapped across three virtual local area networks (vLANs):

1.  **Site A Gateway:** `sso-lb-a` VM (HAProxy local load balancer).
2.  **Site A App Tier:** `sso-1-a` and `sso-2-a` VMs (Keycloak server nodes).
3.  **Site B Gateway:** `sso-lb-b` VM (HAProxy local load balancer).
4.  **Site B App Tier:** `sso-1-b` and `sso-2-b` VMs (Keycloak server nodes).
5.  **Site Zero Shared Services:**
    *   `sso-gslb` VM (BIND authoritative DNS + Global HAProxy entrypoint).
    *   `db-host` VM (Shared PostgreSQL database node).
    *   `sso-mon` VM (Observability monitoring VM hosting Prometheus, Grafana, and Splunk).
