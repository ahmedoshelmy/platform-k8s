#!/usr/bin/env bash
# Create (or reuse) a kind cluster, load the app images into it, install the charts and wait for them.
# Usage: scripts/up.sh [listmate|trip-split ...]   (default: both)
# Env:
#   APPS_DIR   folder holding the listmate/ and trip-split/ checkouts (default: ..)
#   BUILD      1 = docker build the images from APPS_DIR first (default 1); 0 = use local images as they are
#   CLUSTER    kind cluster name (default: platform)
#   KIND_EXPERIMENTAL_PROVIDER=podman for rootless podman instead of Docker
# Images go into the node with `kind load image-archive`; nothing is pushed to a registry.
set -euo pipefail
cd "$(dirname "$0")/.."
CLUSTER="${CLUSTER:-platform}"
APPS_DIR="${APPS_DIR:-..}"
BUILD="${BUILD:-1}"
TAG=dev
WORK=.out/images
mkdir -p "$WORK"

APPS=("$@"); [ ${#APPS[@]} -eq 0 ] && APPS=(listmate trip-split)

# image name -> build context inside APPS_DIR
declare -A CONTEXT=(
  [listmate-api]=listmate [listmate-web]=listmate/src/Web
  [trip-split-api]=trip-split [trip-split-web]=trip-split/web
)

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --config kind/cluster.yaml --wait 120s
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

load() {
  local image="$1" archive="$WORK/$(echo "$1" | tr '/:' '__').tar"
  # Docker 25+ with the containerd image store saves the whole multi-arch index but only the local platform's
  # layers, and kind's `ctr import --all-platforms` then fails. Save just the platform the node runs.
  if docker save --help 2>/dev/null | grep -q -- '--platform'; then
    docker save --platform "linux/$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')" "$image" -o "$archive"
  else
    docker save "$image" -o "$archive"
  fi
  kind load image-archive "$archive" --name "$CLUSTER"
  rm -f "$archive"
}

# Postgres and Redis are loaded too, so the node never pulls from Docker Hub (rate limits, slow links).
load_dep() { docker image inspect "$1" >/dev/null 2>&1 || docker pull "$1" >/dev/null; load "$1"; }

for app in "${APPS[@]}"; do
  for tier in api web; do
    image="localhost/$app-$tier:$TAG"
    if [ "$BUILD" = 1 ]; then
      # BuildKit adds a provenance attestation, turning the image into a manifest list kind can't import.
      if docker build --help 2>/dev/null | grep -q -- '--provenance'; then
        docker build --provenance=false --sbom=false -t "$image" "$APPS_DIR/${CONTEXT[$app-$tier]}"
      else
        docker build -t "$image" "$APPS_DIR/${CONTEXT[$app-$tier]}"
      fi
    fi
    load "$image"
  done
  load_dep docker.io/library/postgres:17-alpine
  [ "$app" = listmate ] && load_dep docker.io/library/redis:7-alpine

  helm dependency build "charts/$app" >/dev/null
  helm upgrade --install "$app" "charts/$app" \
    --namespace "$app" --create-namespace \
    -f "environments/dev/$app.yaml" \
    --wait --timeout 10m
  kubectl -n "$app" get pods -o wide
done
