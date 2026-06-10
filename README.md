# ansible-xscaler-agents

Ansible automation to install the xScaler OpenTelemetry agent bootstrap on Linux,
Windows, and dedicated network-collector hosts.

The installer does one job: install `otelcol-contrib`, install `opampsupervisor`,
and enroll the host with xScaler fleet manager over OpAMP. Fleet manager delivers
the actual metrics, logs, traces, SNMP, and flow collector config.

## What it installs

| Host group        | Role                        | Local install result                         |
|-------------------|-----------------------------|----------------------------------------------|
| `linux_hosts`     | `otelcol_linux`             | `otelcol-contrib` + `opampsupervisor`        |
| `windows_hosts`   | `otelcol_windows`           | `otelcol-contrib.exe` + `opampsupervisor`    |
| `collector_hosts` | `otelcol_network_collector` | `otelcol-contrib` + `opampsupervisor`        |

Standalone `otelcol-contrib` services are disabled after install. The supervisor
owns collector lifecycle and applies remote config from fleet manager.

## Quickstart

```bash
# 1. Install required collections
ansible-galaxy collection install -r requirements.yml

# 2. Copy the sample inventory and fill in your hosts
cp -r inventories/sample inventories/prod
$EDITOR inventories/prod/hosts.yml
$EDITOR inventories/prod/group_vars/all.yml

# 3. Store the enrollment token in an encrypted vault
mkdir -p inventories/prod/group_vars/all
cp inventories/sample/group_vars/all/vault.yml.example inventories/prod/group_vars/all/vault.yml
$EDITOR inventories/prod/group_vars/all/vault.yml
ansible-vault encrypt inventories/prod/group_vars/all/vault.yml

# 4. Dry-run, then apply
ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml --ask-vault-pass --check
ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml --ask-vault-pass

# 5. Verify local supervisor health
ansible-playbook -i inventories/prod/hosts.yml playbooks/verify.yml --ask-vault-pass
```

Run a single tier instead of the whole fleet:

```bash
ansible-playbook playbooks/linux-agents.yml --ask-vault-pass
ansible-playbook playbooks/windows-agents.yml --ask-vault-pass
ansible-playbook playbooks/network-collector.yml --ask-vault-pass
```

## Fleet Config

Example remote config bodies live in `examples/fleet-manager/`:

- `linux-host.yaml`
- `windows-host.yaml`
- `network-collector.yaml`

Create the required config secrets in fleet manager, create config templates from
these files, then assign them by labels such as `agent_profile=linux_host`,
`agent_profile=windows_host`, or `agent_profile=network_collector`.

## Requirements

- Ansible 2.15+ on the control node.
- Linux targets: SSH, `sudo`, and `systemd`.
- Windows targets: WinRM configured plus `ansible.windows` and `community.windows`.
- An xScaler enrollment token with prefix `xse_`.

## Testing

CI runs:

| Check | Command | Proves |
|-------|---------|--------|
| Lint & syntax | `yamllint . && ansible-lint && ansible-playbook --syntax-check playbooks/site.yml` | style + playbook validity |
| Render & validate | `ansible-playbook test/render.yml` plus collector validation on `examples/fleet-manager/*.yaml` | bootstrap templates render and fleet config examples are valid |
| NetFlow smoke | `bash test/netflow-smoke.sh` | a synthetic NetFlow v5 stream is parsed into log records |
| End-to-end Linux | `bash test/e2e-linux.sh` | the Linux role installs collector, disables standalone collector, and starts supervisor |

Override the collector/supervisor version with `OTELCOL_VERSION`.

## Documentation

- [docs/index.md](docs/index.md)
- [docs/architecture.md](docs/architecture.md)
- [docs/quickstart-linux.md](docs/quickstart-linux.md)
- [docs/quickstart-windows.md](docs/quickstart-windows.md)
- [docs/network-telemetry.md](docs/network-telemetry.md)
- [docs/authentication.md](docs/authentication.md)
- [docs/troubleshooting.md](docs/troubleshooting.md)
