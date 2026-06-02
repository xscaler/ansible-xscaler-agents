# ansible-xscaler-agents

Ansible automation to install and configure the **xScaler otel agent** on **Linux** and
**Windows** servers, plus a dedicated **network-telemetry collector**
role for **SNMP**, **NetFlow**, **sFlow**, and **IPFIX** — all shipping **metrics, logs, and
traces** to [xScaler](https://xscalerlabs.com).

## What it does

| Host group        | Role                        | Signals collected                                                              |
|-------------------|-----------------------------|--------------------------------------------------------------------------------|
| `linux_hosts`     | `otelcol_linux`             | host metrics, journald + file logs, app traces (local OTLP intake)             |
| `windows_hosts`   | `otelcol_windows`           | host metrics, Windows Event Log, app traces (local OTLP intake)                |
| `collector_hosts` | `otelcol_network_collector` | SNMP device metrics; NetFlow/sFlow/IPFIX flow logs from routers/switches/fw     |

Everything exports to three xScaler endpoints derived from `xscaler_endpoint`:

| Signal  | Endpoint                                              | Protocol  |
|---------|-------------------------------------------------------|-----------|
| Metrics | `https://xscaler.m.xscalerlabs.com/otlp/v1/metrics` | OTLP HTTP |
| Logs    | `https://xscaler.l.xscalerlabs.com/otlp/v1/logs`    | OTLP HTTP |
| Traces  | `https://xscaler.t.xscalerlabs.com/otlp/v1/traces`  | OTLP HTTP |

Auth on every request: `Authorization: Bearer <API_KEY>` + `X-Scope-OrgID: <tenant_id>`.

## Quickstart

```bash
# 1. Install required collections
ansible-galaxy collection install -r requirements.yml

# 2. Copy the sample inventory and fill in your hosts
cp -r inventories/sample inventories/prod
$EDITOR inventories/prod/hosts.yml
$EDITOR inventories/prod/group_vars/all.yml          # set xscaler_endpoint + xscaler_org_id

# 3. Store the API key in an encrypted vault (NEVER commit the real key)
cp inventories/prod/group_vars/all.vault.yml.example inventories/prod/group_vars/all.vault.yml
ansible-vault encrypt inventories/prod/group_vars/all.vault.yml   # set xscaler_api_key inside

# 4. Dry-run, then apply
ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml --ask-vault-pass --check
ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml --ask-vault-pass

# 5. Verify ingestion end-to-end
ansible-playbook -i inventories/prod/hosts.yml playbooks/verify.yml --ask-vault-pass
```

Run a single tier instead of the whole fleet:

```bash
ansible-playbook playbooks/linux-agents.yml --ask-vault-pass
ansible-playbook playbooks/windows-agents.yml --ask-vault-pass
ansible-playbook playbooks/network-collector.yml --ask-vault-pass
```

## Requirements

- Ansible **2.15+** on the control node.
- Linux targets: SSH + `sudo`, `systemd`.
- Windows targets: WinRM configured, `ansible.windows` collection (see
  [docs/quickstart-windows.md](docs/quickstart-windows.md)).
- An xScaler **API key** and your **tenant id** (`xscaler_org_id`) — mint one in the portal
  (see [docs/authentication.md](docs/authentication.md)).

## Testing

CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs four jobs on every push/PR;
all are runnable locally:

| Check | Command | Proves |
|-------|---------|--------|
| Lint & syntax | `yamllint . && ansible-lint && ansible-playbook --syntax-check playbooks/site.yml` | style + playbook validity |
| Render & validate | `ansible-playbook test/render.yml` then `otelcol-contrib validate` on `test/output/*.yaml` (via the contrib image) | templates produce schema-valid configs; snmp/netflow receivers present in the pinned distro |
| NetFlow smoke | `bash test/netflow-smoke.sh` | a synthetic NetFlow v5 stream is parsed into log records |
| End-to-end Linux | `bash test/e2e-linux.sh` | the `otelcol_linux` role installs, configures, and starts the service in a systemd container |

The two `bash` scripts only need Docker. The render/lint jobs need `ansible-core`
(+ `ansible-lint`, `yamllint`). Override the otel agent version with `OTELCOL_VERSION`.

## Documentation

- [docs/index.md](docs/index.md) — start here
- [docs/architecture.md](docs/architecture.md) — how the pieces fit
- [docs/quickstart-linux.md](docs/quickstart-linux.md)
- [docs/quickstart-windows.md](docs/quickstart-windows.md)
- [docs/network-telemetry.md](docs/network-telemetry.md) — SNMP + NetFlow/sFlow/IPFIX
- [docs/authentication.md](docs/authentication.md)
- [docs/troubleshooting.md](docs/troubleshooting.md)
