# **5.5 Lab: Visualizing Keycloak with Grafana Dashboards**

We have successfully configured Prometheus to collect metrics, but looking at raw query results is not an effective way to monitor a system. In this final step of our observability setup, we will import our pre-built Grafana dashboards to visualize all this data.

### **The "Why": Dashboards for Different Perspectives**

You cannot have one single dashboard that answers all questions. A good monitoring setup uses different dashboards to answer different questions. We will import three dashboards that you have prepared, each with a specific purpose:

1. **RHBK Troubleshooting Dashboard:** The primary dashboard for real-time health. It answers, "Is the system healthy *right now*?"  
2. **RHBK Capacity Planning Dashboard:** The long-term planning dashboard. It answers, "How is our service *growing*?"  
3. **Modified Community Dashboard:** A good general-purpose "at-a-glance" dashboard for basic JVM and login metrics.

### **Step 1: Log into Grafana**

Open your Grafana UI in a browser: `http://<sso-mon-ip>:3000`  
Log in with the default credentials (admin / admin) and set a new password.

### **Step 2: Add Your Prometheus Data Source**

Before you can import a dashboard, Grafana needs to know where to get its data.

1. On the left-hand menu, click the **Connections** (plug) icon.  
2. Click **Add new connection**.  
3. Type Prometheus in the search box and select it.  
4. In the "Prometheus server URL" field, enter: `http://prometheus:9090`  
   * **Note:** We use the container name prometheus because Grafana is in the same docker-compose network as Prometheus. This is more robust than using an IP address.  
5. Click **Save & Test**. You should see a green checkmark confirming "Data source is working."

### **Step 3: Import the Dashboards**

We will now import the three JSON dashboard files you have in your assets directory.

1. On the left-hand menu, click the **Dashboards** (four squares) icon.  
2. On the Dashboards page, click the **New** button in the top-right corner and select **Import**.  
3. Click **Upload dashboard JSON file**.  
4. Navigate to your `assets/grafana-dashboards` directory and select [Adapted-RHBK-Troubleshooting-Dashboard.json](/assets/grafana-dashboards/Adapted-RHBK-Troubleshooting-Dashboard.json).  
5. On the next screen, at the bottom, select your prometheus data source from the dropdown.  
6. Click **Import**.

**Repeat this import process** for the other two dashboard files:

* [Adapted-RHBK-Capacity-Planning-Dashboard.json](/assets/grafana-dashboards/Adapted-RHBK-Capacity-Planning-Dashboard.json)  
* [Modified-Keycloak-Metrics-Community-Dashboard.json](/assets/grafana-dashboards/Modified-Keycloak-Metrics-Community-Dashboard.json)

### **Step 4: Explore Your Data\!**

You have now completed the entire observability stack. Go to your Dashboards list and open the **"Adapted RHBK Troubleshooting Dashboard"**.

After a few moments, the panels will populate with data. You can now:

* See your **SLO Metrics** for availability and latency in real-time.  
* Monitor **JVM Metrics** like heap memory and CPU usage for all four nodes.  
* Inspect **Database Connection Pool** usage.  
* Analyze **HTTP Metrics** to see request rates and errors.  
* Dive deep into **Infinispan Cache** statistics (hits, misses, evictions) for all your caches.  
* Use the **job** and **instance** dropdowns at the top to filter the view for your entire cluster or a single node.

Congratulations\! Your multi-site RHBK cluster is now fully instrumented, resilient, and observable.