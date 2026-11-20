# 4. GitOps with Argo CD (app of apps)

Date: 2026-11-21

## Status

Accepted (manifests only; not installed by CI)

## Context

`scripts/up.sh` runs `helm upgrade --install` from a laptop or a CI job. That is fine for a dev cluster but leaves
no single answer to "what is running in the cluster and who changed it?", and drift (a manual `kubectl edit`) goes
unnoticed.

## Decision

Describe the desired state in Git and let Argo CD reconcile it:

- `gitops/root.yaml` is the only object applied by hand. It is an Argo CD `Application` that syncs `gitops/apps/`.
- `gitops/apps/` holds an `AppProject` (allowed repo and namespaces) and one `Application` per workload, each
  pointing at a chart in `charts/` with the environment's values file.
- Sync is automated with `prune` and `selfHeal`, so removed resources are deleted and manual edits are reverted.
- The listmate Application ignores `/spec/replicas` on the API Deployment, because the HPA owns that field.

Flux would work equally well; Argo CD was chosen for its UI, which makes sync state and drift visible to people
who do not live in a terminal.

## Consequences

- Promotion becomes a Git change (image tag or values file), reviewed like code.
- CI never needs cluster credentials; the cluster pulls.
- Secrets cannot live in Git. The AKS overlay expects a Secret synced from Azure Key Vault by the Secrets Store CSI
  driver; Sealed Secrets or SOPS would be the alternatives for clusters without a cloud vault.
- The manifests are validated in CI with kubeconform against the Argo CD CRD schemas, but no Argo CD instance is
  installed by this repository.
