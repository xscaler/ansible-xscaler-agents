# Quickstart: Linux (Docker installer)

Enroll Linux servers without installing Ansible or Python locally.
The installer runs inside Docker — you only need Docker on your machine.

## Prerequisites

- Docker installed on your local machine ([get Docker](https://docs.docker.com/get-docker/))
- SSH access with `sudo` to each target server
- An xScaler enrollment token with prefix `xse_`

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/xscalerlabs/ansible-xscaler-agents.git
cd ansible-xscaler-agents
```

### 2. Dry-run to check connectivity

```bash
./install.sh --hosts web-01.example.com --check
```

You will be prompted for your enrollment token:

```
xScaler enrollment token (xse_...): ████████████
```

The token is typed hidden and is never written to your terminal or shell
history. On first run the `xscaler-installer` image is built automatically
(downloads Ansible and required collections — takes ~1 minute). Subsequent
runs reuse the cached image.

`--check` runs Ansible in check mode — it shows what would change without
applying anything. Fix any SSH or sudo errors before the real run.

### 3. Apply

```bash
./install.sh --hosts web-01.example.com,db-01.example.com
```

The script will:

1. Start the installer container
2. Generate an inventory from `--hosts`
3. Run `playbooks/linux-agents.yml` inside the container against your servers
4. Exit — the container is removed when done

### 4. Verify

SSH into a target and check the supervisor:

```bash
systemctl status opampsupervisor
journalctl -u opampsupervisor -n 50 --no-pager
```

Then confirm the host appears in fleet manager with `agent_profile=linux_host`.

---

## Options

| Flag | Description | Default |
|---|---|---|
| `--token` | Enrollment token (`xse_...`) — omit to be prompted securely | prompted |
| `--hosts` | Comma-separated hostnames or IPs | required if no `--inventory` |
| `--inventory` | Path to a custom Ansible inventory file | — |
| `--key` | SSH private key path | `~/.ssh/id_rsa` |
| `--user` | SSH username | `root` |
| `--env` | `environment` label sent to fleet manager | `prod` |
| `--region` | `region` label sent to fleet manager | `us` |
| `--check` | Dry run — show changes without applying | off |
| `--build` | Force-rebuild the installer image from source | off |

---

## Common scenarios

### Supplying the token without a prompt (CI / scripted use)

Set `XSCALER_TOKEN` in the environment before running. The script uses it
directly and skips the prompt:

```bash
export XSCALER_TOKEN=xse_...
./install.sh --hosts web-01.example.com
```

Avoid passing it via `--token` in scripts — it will appear in `ps` output and
shell history on the machine running the installer.

### Non-root SSH user

```bash
./install.sh \
  --token xse_... \
  --hosts web-01.example.com \
  --user ubuntu \
  --key ~/.ssh/my_key
```

### Custom labels

```bash
./install.sh \
  --token xse_... \
  --hosts web-01.example.com \
  --env staging \
  --region eu
```

### Multiple hosts with a custom inventory

Create `hosts.yml`:

```yaml
linux_hosts:
  hosts:
    web-01.example.com:
    db-01.example.com:
  vars:
    ansible_user: ubuntu
```

Then run:

```bash
./install.sh --token xse_... --inventory ./hosts.yml
```

### Force a fresh image rebuild

```bash
./install.sh --token xse_... --hosts web-01.example.com --build
```

Use `--build` after pulling new commits to rebuild the `xscaler-installer`
image with updated roles or collections.

---

## How it works

```
your machine          installer container          target server
─────────────         ──────────────────           ─────────────
install.sh
  └─ docker run ───► docker-entrypoint.sh
                        generates inventory
                        writes group_vars
                        ansible-playbook ─────SSH──► installs otelcol-contrib
                                                     installs opampsupervisor
                                                     starts opampsupervisor
                     container exits ◄──────────────  supervisor connects to
                                                       fleet manager over OpAMP
```

The enrollment token is passed as an environment variable — no `ansible-vault`
step is needed with this workflow.

---

## Troubleshooting

**SSH connection refused**
Ensure port 22 is open and the user in `--user` can log in with the key in `--key`.

**`sudo` password required**
Add `--extra-vars ansible_become_password=yourpassword` after the `./install.sh`
command, or configure passwordless sudo on the target.

**Wrong architecture**
The installer image is `linux/amd64`. Targets can be any architecture
(`amd64` or `arm64`) — the role downloads the correct collector binary at
run time.

**Re-enroll / update labels**
Re-run `install.sh` with the same or updated flags. The playbook is idempotent.

For general troubleshooting see [troubleshooting.md](troubleshooting.md).
