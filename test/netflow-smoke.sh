#!/usr/bin/env bash
# NetFlow smoke test: push synthetic NetFlow v5 at a collector and assert it
# parses flow records. Self-contained — no xScaler creds needed.
set -euo pipefail
cd "$(dirname "$0")/.."

COMPOSE="docker compose -f test/docker-compose.netflow.yml"
cleanup() { $COMPOSE down -v >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "==> starting collector + nflow generator"
$COMPOSE up -d

echo "==> waiting for flows to be parsed (up to 30s)"
deadline=$((SECONDS + 30))
found=0
while [ $SECONDS -lt $deadline ]; do
  if $COMPOSE logs collector 2>&1 | grep -q "flow.type: Str(netflow_v5)"; then
    found=1
    break
  fi
  sleep 2
done

if [ "$found" -ne 1 ]; then
  echo "FAIL: no parsed NetFlow v5 records in collector logs"
  $COMPOSE logs collector | tail -40
  exit 1
fi

echo "==> sample parsed flow:"
$COMPOSE logs collector 2>&1 | grep -E "source.address|destination.address|flow.io.bytes|flow.type" | head -8
echo "PASS: collector parsed synthetic NetFlow v5 into log records"
