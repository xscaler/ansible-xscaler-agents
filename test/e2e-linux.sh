#!/usr/bin/env bash
# End-to-end Linux test: run the real otelcol_linux role inside a systemd
# container, then assert the otel agent service is active and the rendered
# config validates. Exporters point at xScaler but no creds are needed — the
# service stays up and the config is validated by the role's `validate:` step.
set -euo pipefail
cd "$(dirname "$0")/.."

IMG="geerlingguy/docker-ubuntu2204-ansible:latest"
NAME="xs-e2e-linux"
OTELCOL_VERSION="${OTELCOL_VERSION:-0.147.0}"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

echo "==> starting systemd container ($IMG)"
docker run -d --name "$NAME" --privileged \
  -v "$PWD":/repo:ro \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  --cgroupns=host \
  "$IMG" /lib/systemd/systemd >/dev/null

echo "==> waiting for systemd to come up"
for _ in $(seq 1 20); do
  if docker exec "$NAME" systemctl is-system-running --wait >/dev/null 2>&1; then break; fi
  sleep 1
done

echo "==> running otelcol_linux role via ansible (connection=local)"
docker exec "$NAME" bash -lc "
  cd /repo &&
  ansible-playbook -i test/inventory-localhost.ini playbooks/linux-agents.yml \
    -e xscaler_endpoint=xscaler \
    -e xscaler_org_id=xs_test_00000000 \
    -e xscaler_api_key=TESTKEY \
    -e otelcol_version=${OTELCOL_VERSION}
"

echo "==> asserting service is active"
state=$(docker exec "$NAME" systemctl is-active otelcol-contrib || true)
echo "otel agent service: $state"
[ "$state" = "active" ] || { echo "FAIL: service not active"; docker exec "$NAME" journalctl -u otelcol-contrib --no-pager | tail -40; exit 1; }

echo "==> validating rendered config with the installed binary"
docker exec "$NAME" otelcol-contrib validate --config /etc/otelcol-contrib/config.yaml

echo "PASS: otelcol_linux role installed, configured, and started the otel agent"
