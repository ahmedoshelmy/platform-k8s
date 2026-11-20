# 2. Helm charts with per-environment values files, not Kustomize

Date: 2026-11-21

## Status

Accepted

## Context

Two applications need the same shape of manifests (API + web Deployments, Services, Ingress, probes, HPA, PDB,
NetworkPolicies, a database) and two targets: a local kind cluster and a prod-like AKS cluster that swaps the
in-cluster Postgres/Redis for managed services and adds Workload Identity and a different ingress class.

Options considered:

1. **Kustomize** bases and overlays: plain YAML, no templating language, built into kubectl.
2. **Helm** charts with `environments/<env>/<app>.yaml` values files.
3. Helm for packaging plus Kustomize post-rendering for environment patches.

## Decision

Use Helm charts and keep environments as values files (`environments/dev`, `environments/aks`).

- The differences between environments are mostly *conditional resources* (no Postgres StatefulSet on AKS,
  no Secret when an external one is used, a PDB only when there is more than one replica). Helm conditionals
  express that directly; Kustomize would need delete patches or components.
- Guard rails belong in the render step: the listmate chart refuses to render more than one API replica without
  the Redis backplane, and the trip-split chart refuses to scale its single in-memory STOMP broker. Helm's `fail`
  gives that; Kustomize cannot.
- Argo CD, AKS tooling and most teams consume Helm charts natively.

## Consequences

- Go templates are harder to read than plain YAML. Mitigated by small templates, shared helpers and
  `scripts/validate.sh`, which renders every chart with every environment and validates the output with
  kubeconform in strict mode.
- The two app charts duplicate some helpers. A library chart would remove that; it is not worth it for two charts.
- If an environment ever needs a patch the chart does not expose, Helm's `--post-renderer` with Kustomize is the
  escape hatch, without changing this decision.
