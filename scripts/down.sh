#!/usr/bin/env bash
# Delete the kind cluster and everything in it (releases, volumes, loaded images).
set -euo pipefail
cd "$(dirname "$0")/.."
CLUSTER="${CLUSTER:-platform}"
kind delete cluster --name "$CLUSTER"
rm -rf .out/images
