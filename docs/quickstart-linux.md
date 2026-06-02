# Quickstart: Linux

Send **metrics, logs, and traces** from Linux servers to xScaler.

## Overview

Installs the otel agent (from the upstream `.deb`/`.rpm`) and runs it as a `systemd`
service. Collects host metrics, journald + selected log files, and accepts OTLP from local
apps for traces.

## Prerequisites

- SSH access with `sudo` to each target.
- Targets run `systemd` (Ubuntu/Debian or RHEL/Rocky/CentOS).
- xScaler `xscaler_endpoint`, `xscaler_org_id`, and an API key (see
  [authentication.md](authentication.md)).

## Setup

1. Add hosts under `linux_hosts` in your inventory:

   ```yaml
   linux_hosts:
     hosts:
       web-01.example.com:
       db-01.example.com:
   ```

2. Set targets in `group_vars/all.yml` and put the key in the vault (see README quickstart).

3. (Optional) Tune in `group_vars/linux_hosts.yml` — scrape interval, extra log files:

   ```yaml
   otelcol_linux_collection_interval: "30s"
   otelcol_linux_log_files:
     - /var/log/syslog
     - /var/log/nginx/*.log
   ```

4. Apply:

   ```bash
   ansible-playbook playbooks/linux-agents.yml --ask-vault-pass --check   # dry run
   ansible-playbook playbooks/linux-agents.yml --ask-vault-pass
   ```

## Sending app traces

Point your application's OTLP exporter at the local agent (no auth needed locally — the
agent adds it):

```
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
```

The agent batches and forwards the traces to xScaler with the right credentials.

## Verification

```bash
systemctl status otelcol-contrib
journalctl -u otelcol-contrib -n 50 --no-pager
ansible-playbook playbooks/verify.yml --ask-vault-pass
```

Then query the host's metrics in xScaler for your tenant.

## Troubleshooting

See [troubleshooting.md](troubleshooting.md). Most common: 401/403 = bad key or
`xscaler_org_id` not matching the key's tenant.
