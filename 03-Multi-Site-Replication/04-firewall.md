# Firewall & Network Requirements for RHBK Multi-Site Deployments

This document describes the **network and firewall ports** required for the RHBK multi-site workshop. It covers two deployment models and includes placeholders for diagrams (stored in `/assets`).

- **Option A - External Infinispan (RHBK Multi-Site Feature Enabled)**
- **Option B - Embedded Infinispan (JVM-local with site-to-site JGroups routes)**

> Both options assume a shared or replicated PostgreSQL database is available (network C). The database is used by both models.

---

## Quick Topology Summary

- **Site A**: 2x RHBK, HAProxy, (optional) External Infinispan node
- **Site B**: 2x RHBK, HAProxy, (optional) External Infinispan node
- **Shared/Replicated PostgreSQL**: Network C
- **Monitoring stack**: Prometheus, Grafana, Alertmanager

---

## Firewall matrix (high-level)

| Component A | Component B | Purpose | Ports | Direction |
|-------------|-------------|---------|-------|-----------|
| Browser | HAProxy (Site A/B) | HTTPS to Keycloak | 443 / 8443 | Incoming |
| HAProxy | RHBK nodes | Backend HTTP(S) | 8080 / 8443 | A \-\> B |
| RHBK nodes | PostgreSQL | DB access | 5432 | A/B \-\> DB |
| RHBK nodes | Prometheus | RHBK metrics access | 9000 | A/B \<\- Prometheus |
| RHBK nodes (Site A) | RHBK nodes (Site B) | Cross-site cluster traffic (Option B) | 7800 (tcp/udp) | A \<\-\> B |
| RHBK nodes | External Infinispan cluster | RHBK caching operations (Option A) | 11222 (hotrod) | A/B \-\> ISPN |
| Infinispan Site A | Infinispan Site B | Cross-site replication (Option A) | 7900, 7800, 7200 | A \<\-\> B |
| Prometheus | RHBK / HAProxy / Infinispan | Metrics scraping | 8080, 9000, 9090, etc. | Mon \-\> Targets |

---

## Deployment Option A - External Infinispan (RHBK multi-site)

**Behavior**
- RHBK connects to a local Infinispan node (HotRod) on the site.
- Infinispan clusters (site A and site B) perform cross-site replication (xsite) between themselves.

    ![RHBK and External Infinispan ports topology](/assets/rhbk-external-cache-firewall.png)


**Relevant `keycloak.conf` settings (example snippet for Site A):**

```ini
# 1. Set the cache stack to 'tcp' (the older 'ispn' stack is removed)
cache-stack=tcp

# 2. Define the connection details for the external cluster (local to the site)
cache-remote-host=<infinispan-node-ip>
cache-remote-port=11222
cache-remote-username=<admin_user>
cache-remote-password=<admin_password>
cache-remote-tls-enabled=false
```

**Ports to open (Site A/ Site B):**
- `11222/tcp` - HotRod (RHBK \-\> local Infinispan)
- `7800-7900/tcp` - JGroups / Infinispan internode (site-local)
- `7900/tcp` - xsite backup/replication
- `7200/udp` - optional diagnostics

**Example `firewalld` rules (external mode):**

```bash
sudo firewall-cmd --permanent --add-port=11222/tcp
sudo firewall-cmd --permanent --add-port=7800-7900/tcp
sudo firewall-cmd --permanent --add-port=7900/tcp
sudo firewall-cmd --permanent --add-port=7200/udp
sudo firewall-cmd --reload
```

---

## Deployment Option B - Embedded Infinispan (multi-site via JGroups routes)

**Behavior**
- Infinispan runs embedded inside each RHBK JVM.
- RHBK nodes communicate across sites using JGroups/TCP (or configured stack) and the multi-site settings in `keycloak.conf`.

    ![RHBK and Embedded Infinispan ports topology](/assets/rhbk-internal-cache-firewall.png)

**Relevant `keycloak.conf` snippet (native multi-site using embedded cache):**

```ini
# Intra-site caching
cache=ispn
cache-stack=jdbc-ping

# Native Multi-Site Configuration (example for Site A)
multi-site-enabled=true
multi-site-site-name=site-a
multi-site-port=7800
multi-site-routes-provider=static
multi-site-static-routes=site-b:10.20.1.11[7800],10.20.1.12[7800]
```

**Ports to open (embedded mode):**
- `7800/tcp` and/or `7800/udp` - JGroups site-to-site communication
- `7200/udp` - optional diagnostics

**Example `firewalld` rules (embedded mode):**

```bash
sudo firewall-cmd --permanent --add-port=7800/tcp
sudo firewall-cmd --permanent --add-port=7800/udp
sudo firewall-cmd --permanent --add-port=7200/udp
sudo firewall-cmd --reload
```

---

## Shared components (all modes)

**PostgreSQL (shared/replicated DB):**
- `5432/tcp` - RHBK \-\> DB

**HAProxy (site-local load balancer):**
- `443/tcp` - Client \-\> HAProxy
- `8080/8443/tcp` - HAProxy \-\> RHBK backend

**Monitoring stack (examples):**
- `9090/tcp` - Prometheus
- `3000/tcp` - Grafana
- `9093/tcp` - Alertmanager

**Example firewall commands**

```bash
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-port=8443/tcp
sudo firewall-cmd --permanent --add-port=9090/tcp
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=9000/tcp
sudo firewall-cmd --reload
```

---

## Verification & Troubleshooting

**Check open ports:**
```bash
sudo firewall-cmd --list-ports
```

**Test connectivity:**
```bash
nc -zv <infinispan-host> 11222
nc -zv <postgres-host> 5432
nc -zv <remote-rhbk-node> 7800
```

**Infinispan cross-site status:**
- Use the Infinispan management UI or CLI to view site status (should be `online`).

**RHBK cache & cluster check:**
- RHBK Admin Console \-\> Server Info \-\> Caches \-\> Nodes

---

## References
- [Lab: `Re-configuring RHBK to Use an External Cache` -\> `Update the keycloak.conf File`](/03-Multi-Site-Replication/02-rhbk-ispn-ext-deployment.md#step-2-update-the-keycloakconf-file)  
- [Lab `Configuring RHBK to Use an Embedded(Internal) Cache` -\> `Create the keycloak.conf File`](/03-Multi-Site-Replication/01-rhbk-ispn-int-deployment.md#1-create-the-keycloakconf-file)    
