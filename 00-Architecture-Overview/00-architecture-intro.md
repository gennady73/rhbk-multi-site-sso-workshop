# RHBK Multi-Site Workshop — Architecture Overview

## Core Principle

This workshop is based on real distributed systems architecture.  
There is no "clustered architecture toggle" in Keycloak or RHBK.

Instead, high availability is achieved by composing independent layers:

- Keycloak clustering (JGroups / JDBC_PING)
- Embedded or external Infinispan caching
- HAProxy load balancing
- DNS / GSLB routing simulation
- PostgreSQL as system of record

## Key Rule

Multi-site is NOT a feature.  
It is an emergent property of system design.
