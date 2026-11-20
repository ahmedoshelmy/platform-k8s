#!/usr/bin/env bash
# Lint every chart with every environment and validate the rendered manifests against Kubernetes 1.31 schemas.
# Same checks as the CI "validate" job. Needs helm and kubeconform on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

K8S_VERSION="${K8S_VERSION:-1.31.0}"
OUT=.out/rendered
rm -rf "$OUT" && mkdir -p "$OUT"

for chart in listmate trip-split; do
  helm dependency build "charts/$chart" >/dev/null
  for env in default dev aks; do
    args=()
    [ "$env" != default ] && args=(-f "environments/$env/$chart.yaml")
    echo "== $chart ($env)"
    helm lint --strict "charts/$chart" "${args[@]}" | tail -1
    helm template "$chart" "charts/$chart" --namespace "$chart" "${args[@]}" > "$OUT/$chart-$env.yaml"
  done
done

# Guard rails must fail the render, not the rollout.
if helm template x charts/listmate --set api.replicaCount=2 >/dev/null 2>&1; then
  echo "FAIL: listmate rendered 2 API replicas without the Redis backplane"; exit 1
fi
if helm template x charts/trip-split --set api.replicaCount=2 >/dev/null 2>&1; then
  echo "FAIL: trip-split rendered 2 API replicas with the in-memory broker"; exit 1
fi
echo "== guard rails: OK"

echo "== kubeconform (Kubernetes $K8S_VERSION, strict)"
kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" "$OUT"

echo "== kubeconform gitops (Argo CD CRD schemas)"
kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  gitops
