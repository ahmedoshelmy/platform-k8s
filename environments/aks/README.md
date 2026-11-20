# AKS (prod-like) overlay

These values describe how the same charts would run on Azure Kubernetes Service. Nothing in this repository
creates Azure resources or deploys to AKS; CI only renders these values and validates the output.

| Concern | Dev (kind) | AKS overlay |
| --- | --- | --- |
| Images | built locally, `kind load` | Azure Container Registry, pulled via the kubelet identity (`az aks update --attach-acr`) |
| Postgres | `charts/postgres` StatefulSet | Azure Database for PostgreSQL Flexible Server, `SSL Mode=Require` / `sslmode=require` |
| Redis (listmate) | `charts/redis` Deployment | Azure Cache for Redis (TLS port 6380); connection string from Key Vault |
| Secrets | chart-created Secret with placeholders | `secrets.existingSecret`, synced from Key Vault by the Secrets Store CSI driver |
| Identity | none | Workload Identity: service account annotated with a managed identity client id, pods labelled `azure.workload.identity/use` |
| Ingress | `nginx` class (optional on kind) | application routing add-on (`webapprouting.kubernetes.azure.com`, managed NGINX) or AGIC (`azure-application-gateway`) |
| NetworkPolicy | kindnet | Azure CNI powered by Cilium (or Azure NPM); ingress namespace `app-routing-system` |
| Autoscaling | fixed replicas | HPA on CPU (metrics-server is built in); cluster autoscaler on the node pool |
| Migrations | on API start | `migrateOnStartup: false`; run as a pipeline step before the rollout |

## Steps a real rollout would take

1. Provision with Bicep or Terraform: AKS (OIDC issuer + Workload Identity enabled, app routing add-on), ACR,
   Postgres Flexible Server, Azure Cache for Redis, Key Vault, one user-assigned managed identity per app with a
   federated credential for `system:serviceaccount:<app>:<app>`.
2. Put the database password and the Redis connection string into Key Vault; create a `SecretProviderClass` with
   `secretObjects` that materialises `listmate-secrets` / `trip-split-secrets` (keys `password`, `redis-connection`).
3. Replace the placeholder client id, registry and host names in `listmate.yaml` and `trip-split.yaml`.
4. Point the Argo CD Applications in `gitops/apps/` at these values files (or install with
   `helm upgrade --install <app> charts/<app> -n <app> -f environments/aks/<app>.yaml`).

## Known gaps

- The apps authenticate to Postgres with a password. Passwordless Entra ID authentication would need an app change
  (token-based password provider in Npgsql / the JDBC driver).
- The `SecretProviderClass` and the TLS certificate (cert-manager or Key Vault certificate) are not templated here.
