# Authentication & Enrollment

Agents connect to xScaler over OpAMP:

```yaml
server:
  endpoint: wss://agents.xscalerlabs.com/v1/opamp
  headers:
    Authorization: "Bearer xse_..."
```

The `xse_` value is an enrollment token minted in the xScaler portal. On first
connect, `agent-api` validates the enrollment token, registers the agent, and
returns a per-agent `xag_` credential through OpAMP connection settings. The
supervisor stores that credential in its storage directory and reuses it on
restart.

## Store the Enrollment Token

Never commit the token. Keep it in an ansible-vault file:

```bash
mkdir -p inventories/<env>/group_vars/all
cp inventories/sample/group_vars/all/vault.yml.example inventories/<env>/group_vars/all/vault.yml
$EDITOR inventories/<env>/group_vars/all/vault.yml
ansible-vault encrypt inventories/<env>/group_vars/all/vault.yml
```

Run playbooks with `--ask-vault-pass` or `--vault-password-file`.

## Ingestion Secrets

Ingestion credentials are no longer rendered by Ansible. Store them in xScaler
fleet-manager config secrets, then reference them from remote config templates
with `${secret:NAME}`. The example fleet templates use:

- `XSCALER_OTLP_TOKEN`
- `SNMP_COMMUNITY` for the network collector example

`X-Scope-OrgID` is not a secret; set it directly in the fleet-manager config
template to the tenant scope id for the target organization.

Reported effective configs are redacted by `agent-api` before persistence.
