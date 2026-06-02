# Authentication & tenancy

Every request to xScaler carries two things:

| Header             | Value                          | Purpose                                   |
|--------------------|--------------------------------|-------------------------------------------|
| `Authorization`    | `Bearer <API_KEY>`             | Identifies + authorizes the caller        |
| `X-Scope-OrgID`    | `<tenant_id>` (`xscaler_org_id`) | Selects the tenant namespace            |

The xScaler ingestion gateway validates the key, then **requires** `X-Scope-OrgID` and checks
it **matches the tenant the key belongs to**. Mismatch → `403`
(`x-scope-orgid mismatch`); missing → `401` (`missing x-scope-orgid`). So `xscaler_org_id`
must be the exact tenant id of the API key.

> Note: some older xScaler integration docs mention `X-OrgId-Scope`. The ingestion edge reads
> **`X-Scope-OrgID`** — that's what these roles send for all three signals.

## Getting a key

1. xScaler portal → **Settings → API Keys** → create a key for the tenant you want to ingest
   into. Copy it once (it's stored hashed server-side; you can't read it back).
2. Note the tenant id (e.g. `xs_acme_ab12cd34`) → that's `xscaler_org_id`.

## Storing the key

Never commit the key. Keep it in an ansible-vault file:

```bash
cp inventories/<env>/group_vars/all.vault.yml.example inventories/<env>/group_vars/all.vault.yml
# edit it to set xscaler_api_key
ansible-vault encrypt inventories/<env>/group_vars/all.vault.yml
```

Run playbooks with `--ask-vault-pass` (or `--vault-password-file`). `.gitignore` already
blocks `*.vault.yml` while tracking the `.example` stub.

The key lands in each rendered `config.yaml` (mode `0640`, root-only on Linux). Verify tasks
use `no_log: true` so it never prints.

## Rotating

1. Mint a new key in the portal.
2. Update `all.vault.yml`, re-encrypt.
3. Re-run the relevant playbook — configs re-render and the service restarts via handler.
4. Revoke the old key in the portal.
