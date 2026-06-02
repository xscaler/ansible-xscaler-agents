# Troubleshooting

## Triage order

1. Is the agent running? `systemctl status otelcol-contrib` (Linux) / `Get-Service otelcol-contrib` (Windows).
2. Is the config valid? `otelcol-contrib validate --config <path>`.
3. What does the agent log say? `journalctl -u otelcol-contrib -n 100` / Event Viewer → Application.
4. Do the endpoints accept our creds? `ansible-playbook playbooks/verify.yml`.

## Symptoms

### 401 Unauthorized on export
Bad or missing API key, or missing `X-Scope-OrgID`. Check the vault value and that the
`Authorization` header is present in the rendered config.

### 403 `x-scope-orgid mismatch`
`xscaler_org_id` doesn't match the tenant the key belongs to. Set `xscaler_org_id` to the
key's tenant id. See [authentication.md](authentication.md).

### Service starts then exits
Almost always a config error. Run `otelcol-contrib validate --config <path>`. The Ansible
template step also validates before writing, so a bad render fails the play rather than
shipping a broken file.

### No metrics in xScaler but agent is healthy
- Confirm `signals.metrics: true`.
- `otlphttp/metrics` exporter errors show in the agent log — look for non-2xx from
  `xscaler.m.xscalerlabs.com`.
- Check the `xscaler_endpoint` id / URL is right for your account.

### No logs (Linux)
- journald: ensure `/var/log/journal` exists (persistent journald). If you only use rsyslog,
  rely on `filelog` + `otelcol_linux_log_files`.
- filelog: confirm the paths/globs exist and the collector user can read them.

### No Windows Event Log
Confirm the channels in `otelcol_windows_eventlog_channels` exist and the service account can
read `Security` (needs appropriate privileges).

### No flow logs on the collector
- Listeners up? `sudo ss -lunp | grep -E '2055|6343|4739'`.
- Firewall open from the device subnet to those UDP ports?
- Device actually exporting to the collector IP:port? NetFlow v9/IPFIX need template packets
  first — wait ~1 min.
- Scheme/port mismatch (sFlow on a netflow listener won't parse).

### No SNMP metrics
- Reachability: `snmpwalk -v2c -c <community> <device> 1.3.6.1.2.1.1.3.0`.
- v3 auth/priv settings must match the device exactly.
- Wrong OIDs for the vendor → override `snmp_metrics`.

### otel agent build lacks snmp/netflow
Pin a contrib release that includes them via `otelcol_version`. The standard
`opentelemetry-collector-releases` contrib build ships both.
