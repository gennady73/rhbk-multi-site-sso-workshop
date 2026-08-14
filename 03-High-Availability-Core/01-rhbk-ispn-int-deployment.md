# **3.1 Lab: Configuring RHBK to Use an Embedded (Internal) Cache **
##### (v26.2/v26.6 Production-Hardened Guide)

⚠️  
```
DISCLAIMER: An experimental approach tests new ideas without a long track record. 
It involves unknown risks, fast learning loops, and uncertain results.
```

In this lab, we will configure Path A (Native Embedded Cache) cross-site replication. Under this architecture, the Infinispan caching tier runs entirely inside Keycloak's own Java Virtual Machine processes, requiring no remote caching servers to be deployed.

---

### **The "Why": Keycloak 26 Cross-Site Configuration Paradigm Shift**

In legacy versions of Red Hat Build of Keycloak (such as RHBK 24.x and early 26.0 betas), cross-site replication was driven by experimental, proprietary build flags in `keycloak.conf` (such as `multi-site-site-name`, `multi-site-port`, and `multi-site-static-routes`). 

With the stabilization of multi-site clustering in **RHBK v26.2 / v26.6**, these legacy parameters have been deprecated and removed. In modern production deployments, Keycloak aligns strictly with native Infinispan configuration standards:

1.  **SPI Property Declarations:** We define node-specific topology attributes (like site, rack, and machine names) directly using standard SPI properties in `keycloak.conf`:
    *   `spi-cache-embedded-default-site-name=site-a`
2.  **Custom JGroups Stack XML Configuration:** For actual WAN replication (replicate Site A to Site B), we reference a custom cache configuration XML file using the build option:
    *   `cache-config-file=cache-ispn-xsite.xml`
    This XML file contains standard JGroups protocol layers (including the `RELAY2` protocol) to bridge the datacenters.

---

### **Lab Task: Configure and Deploy the Custom Clustered XML**

You will perform these steps on **all four** RHBK VM nodes (`sso-1-a`, `sso-2-a`, `sso-1-b`, and `sso-2-b`).

#### **1. Create the Cross-Site Cache XML (`cache-ispn-xsite.xml`)**

We will create a customized Infinispan configuration file that includes JGroups cross-site coordination protocols. Create the file `/opt/keycloak/conf/cache-ispn-xsite.xml` on all nodes.

This configuration defines:
*   Local intra-site clustering via **`JDBC_PING`** (which shares the database for discovery, making it highly robust for VMs where multicast is disabled).
*   Cross-site WAN replication using the **`RELAY2`** protocol to bridge the sites over TCP channels.

```xml
<infinispan xmlns="urn:infinispan:config:15.0"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="urn:infinispan:config:15.0 https://infinispan.org/schemas/infinispan-config-15.0.xsd
                                urn:org:jgroups http://www.jgroups.org/schema/jgroups-5.3.xsd">

    <jgroups>
        <!-- Standard TCP stack optimized for VM environments with JDBC_PING discovery -->
        <stack name="jdbc-ping-xsite" extends="tcp">
            <JDBC_PING connection_driver="org.postgresql.Driver"
                       connection_username="keycloak"
                       connection_password="your_secure_db_password"
                       connection_url="jdbc:postgresql://db-host.mydomain.com:5432/keycloak"
                       initialize_sql="CREATE TABLE IF NOT EXISTS JGROUPSPING (address varchar(200) NOT NULL, cluster_name varchar(200) NOT NULL, ping_data bytea DEFAULT NULL, CONSTRAINT PK_JGROUPSPING PRIMARY KEY (address, cluster_name))"
                       insert_single_sql="INSERT INTO JGROUPSPING (address, cluster_name, ping_data) VALUES (?, ?, ?)"
                       delete_single_sql="DELETE FROM JGROUPSPING WHERE address = ? AND cluster_name = ?"
                       select_all_pingdata_sql="SELECT ping_data FROM JGROUPSPING WHERE cluster_name = ?"
                       stack.combine="REPLACE"
                       stack.position="MPING" />
                       
            <!-- RELAY2 handles cross-site bridging between Site A and Site B -->
            <relay.RELAY2 site="${spi-cache-embedded-default-site-name}"
                          max_site_masters="10"
                          can_become_site_master="true"
                          async_relay_creation="true"
                          xmlns="urn:org:jgroups" />
            <remote-sites default-stack="tcp">
                <remote-site name="site-a" />
                <remote-site name="site-b" />
            </remote-sites>
        </stack>
    </jgroups>

    <cache-container name="keycloak">
        <transport cluster="${spi-cache-embedded-default-cluster-name:ISPN}" 
                   stack="jdbc-ping-xsite" />
                   
        <!-- sessions cache configured to replicate to the backup site asynchronously -->
        <distributed-cache name="sessions" owners="2">
            <backups>
                <backup site="${spi-cache-embedded-default-site-name-backup}" strategy="ASYNC" />
            </backups>
        </distributed-cache>
        
        <distributed-cache name="clientSessions" owners="2">
            <backups>
                <backup site="${spi-cache-embedded-default-site-name-backup}" strategy="ASYNC" />
            </backups>
        </distributed-cache>

        <distributed-cache name="offlineSessions" owners="2">
            <backups>
                <backup site="${spi-cache-embedded-default-site-name-backup}" strategy="ASYNC" />
            </backups>
        </distributed-cache>

        <distributed-cache name="offlineClientSessions" owners="2">
            <backups>
                <backup site="${spi-cache-embedded-default-site-name-backup}" strategy="ASYNC" />
            </backups>
        </distributed-cache>
    </cache-container>
</infinispan>
```

#### **2. Update `keycloak.conf` properties**

To bind this XML config and define topology properties, update `/opt/keycloak/conf/keycloak.conf` on your nodes:

**On Site A Nodes (`sso-1-a`, `sso-2-a`):**
```properties
cache=ispn
cache-config-file=cache-ispn-xsite.xml
spi-cache-embedded-default-cluster-name=site-a-kc-cluster
spi-cache-embedded-default-site-name=site-a
spi-cache-embedded-default-site-name-backup=site-b
```

**On Site B Nodes (`sso-1-b`, `sso-2-b`):**
```properties
cache=ispn
cache-config-file=cache-ispn-xsite.xml
spi-cache-embedded-default-cluster-name=site-b-kc-cluster
spi-cache-embedded-default-site-name=site-b
spi-cache-embedded-default-site-name-backup=site-a
```

#### **3. Rebuild and Restart the Servers**

On all nodes, run the rebuild script to ingest the new XML cache configuration:

```sh
sudo /opt/keycloak/bin/rebuild_keycloak.sh
```

Once built, restart the systemd service to activate the cross-site cluster:

```sh
sudo systemctl restart keycloak
```

#### **4. Verification**

Verify that your nodes successfully initialized the `RELAY2` channel and merged with the database ping coordinate table:

```sh
journalctl -u keycloak.service -n 100 --no-pager | grep -i -E "jgroups|relay"
```

You should see confirmation logs that the `jdbc-ping-xsite` channel has successfully initialized and site master election was completed.