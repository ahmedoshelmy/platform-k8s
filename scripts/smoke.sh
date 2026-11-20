#!/usr/bin/env bash
# Smoke test installed releases through kubectl port-forward (no ingress controller needed).
# Usage: scripts/smoke.sh [listmate|trip-split ...]   (default: both)
# Checks: web /healthz, API liveness + readiness, then one short main flow through the web pod's nginx,
# so the request path is web -> Service "api" -> any API replica -> Postgres.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v jq >/dev/null || { echo "jq is required"; exit 2; }

PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null || true; done; }
trap cleanup EXIT

# forward <namespace> <service> <local-port> <service-port>; waits up to 15 s for the tunnel.
forward() {
  kubectl -n "$1" port-forward "svc/$2" "$3:$4" >/dev/null 2>&1 &
  PIDS+=($!)
  for _ in $(seq 1 30); do
    curl -s -o /dev/null "http://127.0.0.1:$3/" && return 0
    sleep 0.5
  done
  echo "FAIL port-forward to $1/$2"; return 1
}

post() { curl -fsS -X POST "$1" -H 'Content-Type: application/json' ${3:+-H "Authorization: Bearer $3"} -d "$2"; }

smoke_listmate() {
  local web=http://127.0.0.1:18081 api=http://127.0.0.1:18082 run email token list_id name
  forward listmate listmate-web 18081 80
  forward listmate api 18082 8080
  curl -fsS "$web/healthz" >/dev/null && echo "listmate: web healthy"
  curl -fsS "$api/health/live" >/dev/null && curl -fsS "$api/health/ready" >/dev/null && echo "listmate: api live + ready"

  run=$(date +%s); email="k8s-smoke-$run@example.com"
  post "$web/api/auth/register" "{\"email\":\"$email\",\"password\":\"Smoke-test-1\"}" >/dev/null
  token=$(post "$web/api/auth/login" "{\"email\":\"$email\",\"password\":\"Smoke-test-1\"}" | jq -r .accessToken)
  list_id=$(post "$web/api/lists" '{"name":"Cluster groceries"}' "$token" | jq -r .id)
  # Read it back several times: with two replicas behind the Service, some reads land on the other pod,
  # which only works when both share the Redis key ring that protects the token.
  for _ in 1 2 3 4; do
    name=$(curl -fsS "$web/api/lists/$list_id" -H "Authorization: Bearer $token" | jq -r .list.name)
    [ "$name" = "Cluster groceries" ] || { echo "FAIL listmate read-back gave '$name'"; return 1; }
  done
  echo "listmate: register -> login -> create list -> 4 read-backs OK"
}

smoke_tripsplit() {
  local web=http://127.0.0.1:18083 api=http://127.0.0.1:18084 trip id a b total
  forward trip-split trip-split-web 18083 80
  forward trip-split api 18084 8080
  curl -fsS "$web/healthz" >/dev/null && echo "trip-split: web healthy"
  curl -fsS "$api/actuator/health/liveness" | grep -q UP && curl -fsS "$api/actuator/health/readiness" | grep -q UP \
    && echo "trip-split: api live + ready"

  trip=$(post "$web/api/trips" '{"name":"Cluster trip","baseCurrency":"EGP","members":["Ana","Ben"]}')
  id=$(jq -r .id <<<"$trip"); a=$(jq -r '.members[0].id' <<<"$trip"); b=$(jq -r '.members[1].id' <<<"$trip")
  post "$web/api/trips/$id/expenses" \
    "{\"description\":\"Dinner\",\"paidBy\":\"$a\",\"amount\":\"300.00\",\"currency\":\"EGP\",\"split\":{\"kind\":\"EQUAL\",\"participants\":[\"$a\",\"$b\"]}}" >/dev/null
  total=$(curl -fsS "$web/api/trips/$id/balances" | jq '[.balances[].balanceMinor] | add')
  [ "$total" = "0" ] || { echo "FAIL trip-split balances sum to $total"; return 1; }
  echo "trip-split: create trip -> add expense -> balances net to zero OK"
}

APPS=("$@"); [ ${#APPS[@]} -eq 0 ] && APPS=(listmate trip-split)
for app in "${APPS[@]}"; do
  case "$app" in
    listmate) smoke_listmate ;;
    trip-split) smoke_tripsplit ;;
    *) echo "unknown app: $app"; exit 2 ;;
  esac
done
echo "SMOKE PASS"
