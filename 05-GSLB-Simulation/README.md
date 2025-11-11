# **Chapter 5: Building the Global Load Balancer (GSLB) Simulation**

### **The Story So Far**

We have two fully operational, high-availability sites: Site A and Site B. Each one has its own HAProxy load balancer (sso-lb-a, sso-lb-b) managing its own cluster of RHBK nodes. A user could (in theory) be given either URL and log in successfully.

### **The New Problem**

This setup leaves us with two major problems:

1. **No Automated Failover:** If Site A fails, how will our users know to switch to using the URL for Site B? An administrator would have to manually send an email, and all client applications would need to be reconfigured. This is not high availability.  
2. **No Single Entry Point:** We want our users and applications to have one single, simple, permanent address for our SSO service (e.g., sso.mydomain.com), not a list of site-specific URLs.

### **The Solution: The "GSLB-in-a-Box"**

In a public, production environment, you would solve this with a managed, global DNS failover service. Since our workshop is in a private lab using a non-registered domain, we will build a powerful simulation of this system using the tools on our sso-gslb VM in Site Zero.

This GSLB has two components that work together:

1. **The "Brain" (BIND DNS Server):** A local, authoritative DNS server that holds the "active" IP address for sso.mydomain.com.  
2. **The "Heart" (Health Check Script):** A cron job that constantly checks the health of Site A and Site B and tells the "Brain" (BIND) which IP to serve.  
3. **The "Front Door" (Global HAProxy):** The single HAProxy instance that our clients will talk to. It is configured to use our local BIND server as its "resolver," allowing it to *dynamically* discover the correct, healthy site for every new connection.

This chapter is divided into three main lab sections:

1. **[Configuring the BIND DNS Server](/05-GSLB-Simulation/bind-setup.md) (The "Brain")**  
2. **[Deploying the Health Check Script](/05-GSLB-Simulation/health-check-script.md) (The "Heart")**  
3. **[Configuring the Global HAProxy](/05-GSLB-Simulation/global-haproxy.md) (The "Front Door")**