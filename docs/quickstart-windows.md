# Quickstart: Windows

Send **metrics, Windows Event Log, and traces** from Windows servers to xScaler.

## Overview

Downloads the upstream otel agent release zip, installs it under
`C:\Program Files\OpenTelemetry Collector`, and registers a native Windows service
(`otelcol-contrib`) pointed at `C:\ProgramData\otelcol-contrib\config.yaml`.

## Prerequisites

- **WinRM** reachable from the control node (HTTPS/5986 recommended).
- A local admin account for install + service registration.
- `ansible.windows` and `community.windows` collections (`ansible-galaxy collection install -r requirements.yml`).
- xScaler `xscaler_endpoint`, `xscaler_org_id`, and an API key.

### Enabling WinRM (on each target, once)

```powershell
# From an elevated PowerShell on the Windows host:
winrm quickconfig -quiet
# For HTTPS, install a cert and create the listener, then open 5986.
```

## Setup

1. Add hosts under `windows_hosts` with WinRM connection vars (see `inventories/sample/hosts.yml`):

   ```yaml
   windows_hosts:
     hosts:
       win-app-01.example.com:
     vars:
       ansible_connection: winrm
       ansible_user: Administrator
       ansible_winrm_transport: ntlm
       ansible_port: 5986
       ansible_winrm_server_cert_validation: ignore   # use 'validate' in prod
   ```

2. (Optional) Tune `group_vars/windows_hosts.yml` — Event Log channels, scrape interval:

   ```yaml
   otelcol_windows_eventlog_channels:
     - Application
     - System
     - Security
   ```

3. Apply:

   ```bash
   ansible-playbook playbooks/windows-agents.yml --ask-vault-pass --check
   ansible-playbook playbooks/windows-agents.yml --ask-vault-pass
   ```

## Sending app traces

Point the app's OTLP exporter at `http://127.0.0.1:4318` on the host; the agent forwards the
traces to xScaler.

## Verification

```powershell
Get-Service otelcol-contrib
Get-Content "C:\ProgramData\otelcol-contrib\config.yaml"
```

Or run `ansible-playbook playbooks/verify.yml`. Then confirm the host appears in xScaler.

## Troubleshooting

- Service won't start: check the rendered config and the collector log (Event Viewer →
  Application, source `otelcol-contrib`). Validate config locally:
  `& 'C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe' validate --config 'C:\ProgramData\otelcol-contrib\config.yaml'`.
- WinRM errors: see Ansible's Windows setup docs; confirm the listener and firewall.
- 401/403 on export: see [authentication.md](authentication.md).
