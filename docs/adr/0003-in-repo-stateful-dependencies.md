# 3. Tiny in-repo Postgres and Redis charts for dev; managed services in production

Date: 2026-11-21

## Status

Accepted

## Context

Both applications need Postgres; listmate also needs Redis when it runs more than one API replica. The usual
choices are:

1. **Bitnami charts** as dependencies: feature-rich, but large, many values, images pulled from a registry whose
   distribution terms changed in 2025, and heavy for a laptop cluster.
2. **Operators** (CloudNativePG, a Redis operator): the right answer for self-hosted production databases, with
   failover, backups and upgrades, but they add CRDs and controllers to every dev cluster.
3. **Small in-repo charts**: a single-instance Postgres StatefulSet with a PVC, and a Redis Deployment without
   persistence, each with probes, a non-root security context and a NetworkPolicy.

## Decision

Ship `charts/postgres` and `charts/redis` as local subcharts (`file://` dependencies, toggled by
`postgres.enabled` / `redis.enabled`) for dev and CI. In the prod-like AKS overlay both are disabled and the apps
point at Azure Database for PostgreSQL Flexible Server and Azure Cache for Redis.

Redis is a Deployment, not a StatefulSet: it only relays SignalR messages and holds the Data Protection key ring,
and nothing in it must survive a restart beyond a re-login.

## Consequences

- Dev installs are fast and need no extra registries or CRDs; every image is the official one, pinned by tag.
- These charts are **not** production databases: one replica, no backups, no failover, no TLS. The README says so.
- Running databases inside the cluster in production would mean adopting an operator (CloudNativePG is the first
  candidate) and writing a new ADR.
