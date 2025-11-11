# **Chapter 6: Observability \- Monitoring and Logging**

### **The Story So Far**

We have successfully built a complete, end-to-end, multi-site RHBK solution. Our system is:

* **Resilient:** It's clustered within each site.  
* **Highly Available:** It replicates sessions across sites using the native multi-site feature.  
* **Automated:** It uses a custom GSLB to automatically fail over traffic during an outage.

### **The New Problem**

Our system is fully functional, but it's a "black box." We have no idea what's happening inside it.

* How many users are logging in per second?  
* Is the server's CPU or memory usage high?  
* How long does a token refresh take?  
* If a user reports a "login failed" error, how can we see the exact, detailed log for that specific event?

An unmonitored service is not a production-ready service. This final chapter will guide you through setting up a comprehensive observability stack to give us the "x-ray vision" we need to manage our cluster professionally.

### **The Solution: A Centralized Observability Stack**

On our dedicated sso-mon VM in Site Zero, we will deploy a stack of industry-standard, containerized tools:

1. **Prometheus:** The time-series database. It will "scrape" (collect) the detailed performance metrics that our RHBK servers are exposing on their /metrics endpoints.  
2. **Grafana:** The dashboard. We will use this to connect to Prometheus and visualize our metrics on pre-built, official Keycloak dashboards.  
3. **Alertmanager:** The notification service. We will configure Prometheus to send alerts (like "KeycloakInstanceDown") to Alertmanager, which can then route them to Slack, email, etc.  
4. **Splunk:** The log aggregation server. This will be our central "library" for all keycloak.log files, allowing us to search and correlate events from all four RHBK nodes in one place.  
5. **Splunk Universal Forwarder:** This is a separate agent we will install on the RHBK servers themselves to collect their logs and send them to Splunk.

This chapter is divided into these main lab sections:

1. **[Deploying the Core Stack (Docker Compose)](/06-Observability-Stack/deployment.md)**  
2. **[Configuring Prometheus](/06-Observability-Stack/prometheus-config.md)**  
3. **[Configuring Log Forwarding (Splunk)](/06-Observability-Stack/splunk-config.md)**  
4. **[Importing Grafana Dashboards](/06-Observability-Stack/grafana-setup.md)**  
5. **[Configuring Alertmanager](/06-Observability-Stack/alertmanager-config.md)**