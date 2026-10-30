#!/usr/bin/env bash
# End-to-end Linux test: run the real otelcol_linux role inside a systemd
# container against packages.xscalerlabs.com, then assert the xscaler-collector
# service is active. A fake leftover otelcol-contrib/opampsupervisor install is
# seeded first to check the upgrade path removes it.
set -euo pipefail
cd "$(dirname "$0")/.."

IMG="${E2E_IMAGE:-geerlingguy/docker-ubuntu2204-ansible:latest}"
NAME="xs-e2e-linux"
XSCALER_COLLECTOR_VERSION="${XSCALER_COLLECTOR_VERSION:-0.6.0}"

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

echo "==> seeding a legacy opampsupervisor install"
docker exec "$NAME" bash -c '
  install -d /etc/opampsupervisor /var/lib/opampsupervisor
  install -m 0755 /bin/sleep /usr/local/bin/opampsupervisor
  printf "[Service]\nExecStart=/usr/local/bin/opampsupervisor infinity\n[Install]\nWantedBy=multi-user.target\n" \
    > /etc/systemd/system/opampsupervisor.service
  systemctl daemon-reload
  systemctl enable --now opampsupervisor
  systemctl is-active opampsupervisor
'

echo "==> running otelcol_linux role via ansible (connection=local)"
docker exec "$NAME" bash -lc "
  cd /repo &&
  ansible-playbook -i test/inventory-localhost.ini playbooks/linux-agents.yml \
    -e xscaler_opamp_endpoint=ws://127.0.0.1:4320/v1/opamp \
    -e xscaler_enrollment_token=xse_test000000000000000000000000 \
    -e xscaler_collector_version=${XSCALER_COLLECTOR_VERSION}
"

echo "==> asserting xscaler-collector service is active"
state=$(docker exec "$NAME" systemctl is-active xscaler-collector || true)
echo "xscaler-collector service: $state"
[ "$state" = "active" ] || { echo "FAIL: xscaler-collector not active"; docker exec "$NAME" journalctl -u xscaler-collector --no-pager | tail -80; exit 1; }

echo "==> asserting the pinned version is installed"
docker exec "$NAME" /usr/bin/xscaler-collector --version
docker exec "$NAME" dpkg-query -W -f='${Version}\n' xscaler-collector | grep -qx "${XSCALER_COLLECTOR_VERSION}"

echo "==> asserting the legacy supervisor is gone"
if docker exec "$NAME" systemctl is-active opampsupervisor >/dev/null 2>&1; then echo "FAIL: opampsupervisor still active"; exit 1; fi
if docker exec "$NAME" test -e /etc/systemd/system/opampsupervisor.service -o -e /usr/local/bin/opampsupervisor -o -e /etc/opampsupervisor; then
  echo "FAIL: legacy opampsupervisor files remain"; exit 1
fi

echo "==> checking supervisor config"
docker exec "$NAME" grep -q 'xscaler.distribution: xscaler-collector' /etc/xscaler-collector/supervisor.yaml
if docker exec "$NAME" grep -Eq '^[[:space:]]*reports_remote_config:' /etc/xscaler-collector/supervisor.yaml; then echo "FAIL: reports_remote_config set"; exit 1; fi

echo "==> re-running the role to check it is idempotent"
docker exec "$NAME" bash -lc "
  cd /repo &&
  ansible-playbook -i test/inventory-localhost.ini playbooks/linux-agents.yml \
    -e xscaler_opamp_endpoint=ws://127.0.0.1:4320/v1/opamp \
    -e xscaler_enrollment_token=xse_test000000000000000000000000 \
    -e xscaler_collector_version=${XSCALER_COLLECTOR_VERSION}
" | tee /dev/stderr | grep -Eq 'changed=0 '

echo "PASS: otelcol_linux role installed xscaler-collector and started its supervisor"
