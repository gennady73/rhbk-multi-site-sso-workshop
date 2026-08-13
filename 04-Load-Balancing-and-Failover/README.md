# **Chapter 4: Site-Local Load Balancers (HAProxy)**

### **The Story So Far**

In the previous chapter, we successfully configured all four of our RHBK server nodes (`sso-1-a`, `sso-2-a`, `sso-1-b`, `sso-2-b`). They are now running as secure systemd services, are configured to use our shared database, and have their multi-site replication settings in place.

### **The New Problem**

We have a new architectural challenge: how do our users and applications access these servers?

Right now, we just have four independent nodes.

* What happens if a user authenticates against `sso-1-a` and their next request goes to `sso-2-a`? The session might not have replicated yet, forcing a re-login.  
* What happens if `sso-1-a` fails? How do we direct traffic to `sso-2-a`?  
* How do we present a single, clean hostname for all of Site A (e.g., sso-lb-a.mydomain.com)?

### **The Solution: The Site-Local Load Balancer**

This is the job of our **Site-Local HAProxy** instances (`sso-lb-a` and `sso-lb-b`). These servers act as the "front door" for each of our sites.

In this chapter, we will configure these two load balancers to provide three critical functions:

1. **TLS Termination:** They will handle all incoming HTTPS traffic, decrypt it, and forward it to the RHBK nodes.  
2. **Session Affinity (Stickiness):** We will configure HAProxy to inspect Keycloak's `KC_SESSION` cookie. This ensures that once a user starts a session with one RHBK node, all their subsequent requests are "stuck" to that same node, guaranteeing session consistency.  
3. **Health Checking:** Our HAProxy instances will continuously monitor the `/health/ready` endpoint of the RHBK nodes. If one node fails, HAProxy will automatically and instantly stop sending traffic to it, ensuring zero downtime for the site.    

<br>

## References
* [Red Hat Build of Keycloak 26.2 - High Availability Guide](https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/26.2/html-single/high_availability_guide/index) 
