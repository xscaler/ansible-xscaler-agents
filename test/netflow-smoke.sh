#!/usr/bin/env bash
# NetFlow smoke test: push synthetic NetFlow v5 at a collector and assert it
# parses flow records. Self-contained — no xScaler creds needed.
set -euo pipefail
cd "$(dirname "$0")/.."

COMPOSE="docker compose -f test/docker-compose.netflow.yml"
cleanup() { $COMPOSE down -v >/dev/null 2>&1 || true; }
trap cleanup EXIT

TIMEOUT="${NETFLOW_SMOKE_TIMEOUT:-120}"

echo "==> starting collector + nflow generator"
$COMPOSE up -d

# The generator may hit 'connection refused' until the collector binds UDP/2055,
# then restarts with backoff — so on a slow runner the first parsed record can
# take a while. Poll until a netflow_v5 record shows up or we hit the timeout.
echo "==> waiting for flows to be parsed (up to ${TIMEOUT}s)"
deadline=$((SECONDS + TIMEOUT))
found=0
logs=""
while [ $SECONDS -lt $deadline ]; do
  # Match with a bash glob on the captured string — NOT `... | grep -q`. Under
  # `set -o pipefail`, grep -q closes the pipe on first match, the upstream
  # producer dies with SIGPIPE (non-zero), and pipefail turns the result false
  # even though it matched. A case glob has no pipe, so no false negative.
  logs="$($COMPOSE logs collector 2>&1 || true)"
  case "$logs" in
    *netflow_v5*) found=1; break ;;
  esac
  sleep 3
done

if [ "$found" -ne 1 ]; then
  echo "FAIL: no parsed NetFlow v5 records after ${TIMEOUT}s"
  echo "--- collector logs ---"; printf '%s\n' "$logs" | tail -40
  echo "--- generator logs ---"; $COMPOSE logs generator 2>&1 | tail -20 || true
  exit 1
fi

echo "==> sample parsed flow:"
printf '%s\n' "$logs" | grep -E "source.address|destination.address|flow.io.bytes|flow.type" | head -8 || true
echo "PASS: collector parsed synthetic NetFlow v5 into log records"
