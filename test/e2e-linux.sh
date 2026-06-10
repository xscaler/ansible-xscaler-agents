#!/usr/bin/env bash
# End-to-end Linux test: run the real otelcol_linux role inside a systemd
# container, then assert the OpAMP supervisor service is active and owns the
# collector lifecycle.
set -euo pipefail
cd "$(dirname "$0")/.."

IMG="geerlingguy/docker-ubuntu2204-ansible:latest"
NAME="xs-e2e-linux"
OTELCOL_VERSION="${OTELCOL_VERSION:-0.154.0}"

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
    -e xscaler_opamp_endpoint=ws://127.0.0.1:4320/v1/opamp \
    -e xscaler_enrollment_token=xse_test000000000000000000000000 \
    -e otelcol_version=${OTELCOL_VERSION}
"

echo "==> asserting supervisor service is active"
state=$(docker exec "$NAME" systemctl is-active opampsupervisor || true)
echo "opampsupervisor service: $state"
[ "$state" = "active" ] || { echo "FAIL: supervisor not active"; docker exec "$NAME" journalctl -u opampsupervisor --no-pager | tail -80; exit 1; }

echo "==> asserting standalone collector service is disabled"
enabled=$(docker exec "$NAME" systemctl is-enabled otelcol-contrib || true)
echo "otelcol-contrib enabled: $enabled"
[ "$enabled" = "disabled" ] || { echo "FAIL: standalone collector service not disabled"; exit 1; }

echo "==> checking supervisor config"
docker exec "$NAME" test -s /etc/opampsupervisor/supervisor.yaml

echo "PASS: otelcol_linux role installed collector and started OpAMP supervisor"
