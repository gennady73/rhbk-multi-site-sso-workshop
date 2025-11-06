# **Chapter 2: RHBK Server Setup \- From ZIP to Service**

Welcome to the first major hands-on section of the workshop. So far, we have a set of blank RHEL 9 virtual machines. In this chapter, we will take the raw RHBK .zip distribution and transform it into a secure, robust, and manageable enterprise service.

This is a foundational step. We will not be just "running a script"; we will be establishing the professional practices that make the system secure and maintainable.

## **The "Story" of This Chapter**

Our goal is to configure the RHBK server on **all four** application nodes (sso-1-a, sso-2-a, sso-1-b, sso-2-b). We will follow a "why-first" narrative:

1. **Why** run as an unprivileged user? For security.  
   * **What** we will do: Create a keycloak user and group.  
2. **Why** use systemd? For manageability and reliability.  
   * **What** we will do: Create a systemd unit file to manage the service, including granting it special permissions to bind to port 443 without running as root.  
3. **Why** separate build from start? For performance and audibility.  
   * **What** we will do: Create a rebuild\_keycloak.sh script to handle the one-time kc.sh build command and log our changes. The systemd service will *only* use the fast kc.sh start \--optimized command.  
4. **Why** use an internal CA? For a secure, trusted network.  
   * **What** we will do: Create a Java Keystore (.p12) from the certificates generated in the prerequisite step.  
5. **Why** use keycloak.conf? To centralize all configuration.  
   * **What** we will do: Define the core keycloak.conf file, setting up our database, proxy, and logging—and most importantly, enabling the **native multi-site** features.

## **Learning Objectives**

By the end of this chapter, you will have:

* A keycloak user and group on all four RHBK nodes.  
* A systemd service file that manages the RHBK process.  
* A rebuild\_keycloak.sh script for managing build-time changes.  
* A server.keystore file for enabling TLS.  
* A keycloak.conf file that configures the database, proxy, logging, metrics, and native multi-site replication.  
* Four fully functional, running RHBK server nodes, two in Site A and two in Site B.

Let's begin with the first step: setting up the systemd service.

## **Sections in this Chapter**

* [**01 \- Service Management (systemd)**](http://docs.google.com/01-service-management.md)  
* [**02 \- Build and Maintenance (rebuild\_keycloak.sh)**](http://docs.google.com/02-build-and-maintenance.md)  
* [**03 \- Certificate Setup**](http://docs.google.com/03-certificate-setup.md)  
* [**04 \- Core Configuration (keycloak.conf)**](http://docs.google.com/04-core-configuration.md)