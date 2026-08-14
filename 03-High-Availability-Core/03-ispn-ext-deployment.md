# **3.3 Lab: Deploying an External Infinispan Cluster (v26.2/v26.6 Production-Hardened Guide)**

In this lab, we will deploy the standalone, external cache servers representing our decoupled cache layer (Path B). For the workshop lab environment, we will run both Infinispan nodes as containerized services on our `sso-mon` VM in "Site Zero." In an actual production environment, these nodes would be deployed on separate, bare-metal or RHEL 9 VM nodes within their respective physical datacenters.

Using a decoupled external cache (Path B) is highly valued in enterprise environments because it separates our stateless Keycloak application servers from the stateful, memory-intensive session-tracking layer [Keycloak HA Overview](https://www.keycloak.org/high-availability/introduction) and [Multi-cluster deployments (v1) Guide](https://www.keycloak.org/high-availability/multi-cluster/introduction).

---

### **Step 1: Create the Configuration Directory**

Log into your `sso-mon` VM and create a dedicated configuration folder to hold your Docker Compose and XML configuration templates:

```bash
mkdir -p /opt/monitoring/infinispan
cd /opt/monitoring/infinispan
```

---

### **Step 2: Create the Infinispan [docker-compose.yml](../assets/infinispan/docker-compose.yml)**

Create the `docker-compose.yml` file to launch two distinct Infinispan server containers. We use `infinispan/server:15.0` to represent the caching nodes. Node `infinispan-a` will act as the local cache server for Site A, and node `infinispan-b` will act as the local cache server for Site B.

**File: `docker-compose.yml` ([docker-compose.yml](../assets/infinispan/docker-compose.yml))**

```yaml
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
      - JGROUPS_TCPPING_INITIAL_HOSTS=infinispan-b[7800]
    ports:
      - "11222:11222" # Site A Hot Rod endpoint
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
      - "11223:11222" # Site B Hot Rod endpoint (mapped to port 11223 to avoid conflicts)
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

---

### **Step 3: Create the Hardened [infinispan-xsite.xml](../assets/infinispan/infinispan-xsite.xml) Configuration**

This is the central configuration file defining our clustering JGroups stack and Infinispan cache topologies. Keycloak 26 introduced critical architectural changes that make standard legacy configurations completely incompatible [Keycloak 26 Caching Guide](https://www.keycloak.org/server/caching). 

#### **Crucial Keycloak 26 Caching Concepts:**
1. **The Protostream Marshalling Shift:** In Keycloak 26, the internal marshalling engine migrated from legacy *JBoss Marshalling* to **Infinispan Protostream** (Google Protocol Buffers) [Keycloak 26 Caching Guide](https://www.keycloak.org/server/caching). 
2. **The Media-Type Requirement:** Because of this shift, all distributed session caches (`sessions`, `clientSessions`, `offlineSessions`, `offlineClientSessions`, `authenticationSessions`, `actionTokens`) **must** explicitly define their encoding media-type as `application/x-protostream` [Keycloak 26 Caching Guide](https://www.keycloak.org/server/caching). Without this configuration in the remote Infinispan XML, the Keycloak Hot Rod client will suffer immediate, unrecoverable serialization crashes during session replication.
3. **Local Cache Objects:** Conversely, local in-memory caches (`realms`, `users`, `authorization`, `keys`, `crl`) must continue using `application/x-java-object` because they reside strictly within the local JVM and do not replicate [Keycloak Distributed Caching Guide](https://www.keycloak.org/server/caching#_configuring_caches).

Create the following file in `/opt/monitoring/infinispan/infinispan-xsite.xml` ([infinispan-xsite.xml](../assets/infinispan/infinispan-xsite.xml)):

```xml
<infinispan xmlns="urn:infinispan:config:15.0"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="urn:infinispan:config:15.0 https://infinispan.org/schemas/infinispan-config-15.0.xsd
                                urn:infinispan:server:15.0 https://infinispan.org/schemas/infinispan-server-15.0.xsd
                                urn:org:jgroups http://www.jgroups.org/schema/jgroups-5.3.xsd"
            xmlns:server="urn:infinispan:server:15.0">

    <jgroups>
        <!-- Unicast/Multicast stack for cross-datacenter WAN relaying -->
        <stack name="relay-global" extends="tcp">
            <TCPPING initial_hosts="${jgroups.tcpping.initial_hosts:192.0.2.0[7800]}"
                     stack.combine="REPLACE"
                     stack.position="MPING"
                     port_range="0" />
            <MERGE3 min_interval="10000" max_interval="30000" />
            <FD_SOCK2 />
            <FD_ALL3 timeout="40000" interval="5000" /> <!-- Tuned for WAN network latency spikes -->
            <VERIFY_SUSPECT2 timeout="1500" />
            <BARRIER />
            <UNICAST3 />
            <MFC max_credits="2M" min_threshold="0.4" />
            <FRAG3 />
        </stack>

        <!-- Local datacenter JGroups stack with RELAY2 bridging enabled -->
        <stack name="tcp-xsite" extends="udp">
            <!-- max_site_masters is set to match cluster size so every node can replicate directly to avoid bottlenecks -->
            <!-- can_become_site_master MUST be set to true to allow site master election -->
            <relay.RELAY2 site="${infinispan.site.name}"
                          xmlns="urn:org:jgroups"
                          max_site_masters="10"
                          can_become_site_master="true"
                          async_relay_creation="true" />
            <remote-sites default-stack="relay-global" cluster="${infinispan.cluster.name:cluster}">
                <remote-site name="${infinispan.site.name}" />
                <remote-site name="${infinispan.backup.site.name}" />
            </remote-sites>
        </stack>
    </jgroups>

    <cache-container name="default" statistics="true">
        <transport cluster="${infinispan.cluster.name:cluster}" 
                   stack="${infinispan.cluster.stack:tcp-xsite}" 
                   site="${infinispan.site.name}" 
                   node-name="${infinispan.node.name:}" />
        <security>
            <authorization />
        </security>
        <metrics gauges="true" histograms="true" names_as_tags="true" />

        <!-- JVM-Local Caches (Do not cross-replicate, stay inside local JVM process) -->
        <local-cache name="realms" simple-cache="true" statistics="true">
            <encoding>
                <key media-type="application/x-java-object" />
                <value media-type="application/x-java-object" />
            </encoding>
            <memory max-count="10000" />
        </local-cache>

        <local-cache name="users" simple-cache="true" statistics="true">
            <encoding>
                <key media-type="application/x-java-object" />
                <value media-type="application/x-java-object" />
            </encoding>
            <memory max-count="10000" />
        </local-cache>

        <local-cache name="authorization" simple-cache="true" statistics="true">
            <encoding>
                <key media-type="application/x-java-object" />
                <value media-type="application/x-java-object" />
            </encoding>
            <memory max-count="10000" />
        </local-cache>

        <local-cache name="keys" simple-cache="true" statistics="true">
            <encoding>
                <key media-type="application/x-java-object" />
                <value media-type="application/x-java-object" />
            </encoding>
            <expiration max-idle="3600000" />
            <memory max-count="1000" />
        </local-cache>

        <local-cache name="crl" simple-cache="true" statistics="true">
            <encoding>
                <key media-type="application/x-java-object" />
                <value media-type="application/x-java-object" />
            </encoding>
            <expiration lifespan="-1" />
            <memory max-count="1000" />
        </local-cache>

        <!-- Replicated Invalidation Caches -->
        <replicated-cache name="work" statistics="true">
            <transaction mode="FULL_XA" />
            <expiration lifespan="-1" />
            <backups>
                <backup site="${infinispan.backup.site.name}" strategy="SYNC" />
            </backups>
        </replicated-cache>

        <!-- Keycloak 26 Protostream Distributed Session Caches -->
        <distributed-cache name="authenticationSessions" owners="4" statistics="true">
            <transaction mode="NON_XA" />
            <expiration lifespan="-1" />
            <encoding>
                <key media-type="application/x-protostream" />
                <value media-type="application/x-protostream" />
            </encoding>
            <backups>
                <backup site="${infinispan.backup.site.name}" strategy="SYNC" />
            </backups>
        </distributed-cache>

        <distributed-cache name="sessions" owners="4" statistics="true">
            <transaction mode="NON_XA" />
            <expiration lifespan="-1" />
            <encoding>
                <key media-type="application/x-protostream" />
                <value media-type="application/x-protostream" />
            </encoding>
            <memory max-count="10000" />
            <backups>
                <backup site="${infinispan.backup.site.name}" strategy="SYNC" />
            </backups>
        </distributed-cache>

        <distributed-cache name="clientSessions" owners="4" statistics="true">
            <transaction mode="NON_XA" />
            <expiration lifespan="-1" />
            <encoding>
                <key media-type="application/x-protostream" />
                <value media-type="application/x-protostream" />
            </encoding>
            <memory max-count="10000" />
            <backups>
                <backup site="${infinispan.backup.site.name}" strategy="SYNC" />
            </backups>
        </distributed-cache>

        <distributed-cache name="offlineSessions" owners="4" statistics="true">
            <transaction mode="NON_XA" />
            <expiration lifespan="-1" />
            <encoding>
                <key media-type="application/x-protostream" />
                <value media-type="application/x-protostream" />
            </encoding>
            <memory max-count="10000" />
            <backups>
                <backup site="${infinispan.backup.site.name}" strategy="SYNC" />
            </backups>
        </distributed-cache>

        <distributed-cache name="offlineClientSessions" owners="4" statistics="true">
            <transaction mode="NON_XA" />
            <expiration lifespan="-1" />
            <encoding>
                <key media-type="application/x-protostream" />
                <value media-type="application/x-protostream" />
            </encoding>
            <memory max-count="10000" />
            <backups>
                <backup site="${infinispan.backup.site.name}" strategy="SYNC" />
            </backups>
        </distributed-cache>

        <distributed-cache name="loginFailures" owners="4" statistics="true">
            <transaction mode="NON_XA" />
            <expiration lifespan="-1" />
            <encoding>
                <key media-type="application/x-protostream" />
                <value media-type="application/x-protostream" />
            </encoding>
            <backups>
                <backup site="${infinispan.backup.site.name}" strategy="SYNC" />
            </backups>
        </distributed-cache>

        <distributed-cache name="actionTokens" owners="4" statistics="true">
            <transaction mode="NON_XA" />
            <encoding>
                <key media-type="application/x-protostream" />
                <value media-type="application/x-protostream" />
            </encoding>
            <expiration max-idle="-1" lifespan="-1" interval="300000" />
            <memory max-count="-1" />
            <backups>
                <backup site="${infinispan.backup.site.name}" strategy="SYNC" />
            </backups>
        </distributed-cache>
    </cache-container>

    <server:server>
        <server:interfaces>
            <server:interface name="public">
                <server:inet-address value="${infinispan.bind.address:0.0.0.0}" />
            </server:interface>
        </server:interfaces>
        <server:socket-bindings default-interface="public" port-offset="${infinispan.socket.binding.port-offset:0}">
            <server:socket-binding name="default" port="${infinispan.bind.port:11222}" />
        </server:socket-bindings>
        <server:security>
            <server:security-realms>
                <server:security-realm name="default">
                    <server:properties-realm />
                </server:security-realm>
            </server:security-realms>
        </server:security>
        <server:endpoints socket-binding="default" security-realm="default" />
    </server:server>
</infinispan>
```

---

### **Step 4: Start the Standalone Cache Containers**

Run Docker Compose to pull the official Infinispan server images and launch our geographical mock deployments:

```bash
docker compose up -d
```

Verify that both cache systems started and formed clusters successfully by inspecting the log views:

```bash
docker logs infinispan-site-a
docker logs infinispan-site-b
```

Look for `ISPN000094: Received new cluster view` entries confirming the nodes detected each other and established WAN socket handshakes across their virtual networks [Keycloak Cluster and Network Verification Guide](https://www.keycloak.org/server/caching#_verify_cluster_and_network_health).