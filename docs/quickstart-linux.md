# Quickstart: Linux

Enroll Linux servers with xScaler fleet manager.

## Overview

The role adds the signed xScaler package repository (`packages.xscalerlabs.com`),
installs `xscaler-collector` at `xscaler_collector_version` (default `0.6.0`),
writes `/etc/xscaler-collector/supervisor.yaml` and the token in
`/etc/xscaler-collector/xscaler-collector.env`, and starts the `xscaler-collector`
service, which is the OpAMP supervisor.

Hosts that ran an earlier version of this role have their `otelcol-contrib` and
`opampsupervisor` services and packages removed first, so only one supervisor
runs.

Fleet manager delivers the collector config for host metrics, logs, and local
OTLP intake.

## Prerequisites

- SSH access with `sudo` to each target.
- Targets run `systemd` on Debian, Ubuntu, or an RPM family distribution (RHEL, Rocky, Alma, Amazon Linux 2023).
- Targets can reach `https://packages.xscalerlabs.com`.
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
systemctl status xscaler-collector
journalctl -u xscaler-collector -n 100 --no-pager
/usr/bin/xscaler-collector --version
ansible-playbook playbooks/verify.yml --ask-vault-pass
```

Then confirm the host appears in fleet manager with `agent_profile=linux_host`.
