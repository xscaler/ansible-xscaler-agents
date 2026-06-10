# Quickstart: Linux

Enroll Linux servers with xScaler fleet manager.

## Overview

The role installs upstream `otelcol-contrib`, downloads `opampsupervisor`, renders
`/etc/opampsupervisor/supervisor.yaml`, disables the standalone collector service,
and starts `opampsupervisor`.

Fleet manager delivers the collector config for host metrics, logs, and local
OTLP intake.

## Prerequisites

- SSH access with `sudo` to each target.
- Targets run `systemd`.
- An xScaler enrollment token with prefix `xse_`.

## Setup

1. Add hosts under `linux_hosts`:

   ```yaml
   linux_hosts:
     hosts:
       web-01.example.com:
       db-01.example.com:
   ```

2. Set bootstrap labels in `group_vars/all.yml` or `group_vars/linux_hosts.yml`:

   ```yaml
   xscaler_agent_labels:
     environment: prod
     region: us
   ```

3. Put the enrollment token in `group_vars/all/vault.yml`:

   ```yaml
   xscaler_enrollment_token: "xse_..."
   ```

4. Apply:

   ```bash
   ansible-playbook playbooks/linux-agents.yml --ask-vault-pass --check
   ansible-playbook playbooks/linux-agents.yml --ask-vault-pass
   ```

## Verification

```bash
systemctl status opampsupervisor
journalctl -u opampsupervisor -n 100 --no-pager
ansible-playbook playbooks/verify.yml --ask-vault-pass
```

Then confirm the host appears in fleet manager with `agent_profile=linux_host`.
