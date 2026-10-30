# Troubleshooting

## Triage Order

1. Is the supervisor running?
   `systemctl status xscaler-collector` or `Get-Service xscaler-collector`.
2. Is the old install gone?
   `systemctl is-enabled otelcol-contrib opampsupervisor` should not report `enabled`.
3. What does the supervisor log say?
   `journalctl -u xscaler-collector -n 100 --no-pager`.
4. Does fleet manager show the agent online with expected labels?
5. Does the assigned remote config show an applied hash and effective config?

## Symptoms

### Agent does not appear in fleet manager

- Check `xscaler_opamp_endpoint`.
- Check that `xscaler_enrollment_token` starts with `xse_`.
- Check supervisor logs for `401` or websocket connection errors.

### Supervisor is running but collector is not

If no remote config has been delivered yet, supervisor may run without a managed
collector. Assign a fleet config template to the agent labels and wait for the
remote config hash to update.

### Remote config fails to apply

Validate the config body with the installed collector:

```bash
xscaler-collector validate --config linux-host.yaml
```

Then check the fleet-manager delivery status and error message.

### Logs are missing

Linux file and journald access depends on the collector process privileges and
the paths referenced by the remote collector config.

### Network flow data is missing

- Confirm the remote config assigned to `agent_profile=network_collector`.
- Confirm UDP reachability from devices to the collector host.
- NetFlow v9/IPFIX require template packets before records parse.
