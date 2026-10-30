# Quickstart: Windows

Enroll Windows servers with xScaler fleet manager.

## Overview

The role installs the `xscaler-collector` MSI from the `xscaler/xscaler-agent`
GitHub release at `xscaler_collector_version` (default `0.6.0`), renders
`C:\ProgramData\xScaler Collector\supervisor.yaml`, and starts the
`xscaler-collector` service, which is the OpAMP supervisor.

Hosts that ran an earlier version of this role have their `otelcol-contrib` and
`opampsupervisor` services and folders removed first.

Fleet manager delivers the collector config for host metrics, Windows Event Log,
and local OTLP intake.

## Prerequisites

- WinRM reachable from the control node.
- Targets can reach `https://github.com` to download the MSI.
- A local admin account for install and service registration.
- `ansible.windows` and `community.windows` collections.
- An xScaler enrollment token with prefix `xse_`.

## Setup

1. Add hosts under `windows_hosts` with WinRM connection vars:

   ```yaml
   windows_hosts:
     hosts:
       win-app-01.example.com:
     vars:
       ansible_connection: winrm
       ansible_user: Administrator
       ansible_winrm_transport: ntlm
       ansible_port: 5986
       ansible_winrm_server_cert_validation: ignore
   ```

2. Set bootstrap labels in inventory:

   ```yaml
   xscaler_agent_labels:
     environment: prod
     region: us
   ```

3. Put the enrollment token in `group_vars/all/vault.yml`.

4. Apply:

   ```bash
   ansible-playbook playbooks/windows-agents.yml --ask-vault-pass --check
   ansible-playbook playbooks/windows-agents.yml --ask-vault-pass
   ```

## Verification

```powershell
Get-Service xscaler-collector
Get-Content "C:\ProgramData\xScaler Collector\supervisor.yaml"
```

Then confirm the host appears in fleet manager with `agent_profile=windows_host`.
