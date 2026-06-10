# Network Telemetry

Routers, switches, and firewalls cannot run an agent. Use a dedicated Linux host
in the `collector_hosts` inventory group, enroll it with OpAMP supervisor, and
assign a network collector config from fleet manager.

## Enroll a Collector Host

```yaml
collector_hosts:
  hosts:
    netcollector-01.example.com:
```

Run:

```bash
ansible-playbook playbooks/network-collector.yml --ask-vault-pass --check
ansible-playbook playbooks/network-collector.yml --ask-vault-pass
```

The role adds `agent_profile=network_collector`; use that label in fleet-manager
assignments.

## Configure SNMP and Flows

Use `examples/fleet-manager/network-collector.yaml` as the starting remote config.
Edit device addresses, SNMP credentials, OIDs, and flow listener ports in fleet
manager, not in Ansible inventory.

Default example listeners:

| Scheme        | Port |
|---------------|------|
| NetFlow v5/v9 | 2055 |
| sFlow         | 6343 |
| IPFIX         | 4739 |

Open inbound UDP from device subnets to those ports on the collector host.

## Verify

```bash
systemctl status opampsupervisor
sudo ss -lunp | grep -E '2055|6343|4739'
```

In fleet manager, check that the network config assignment applied and the
effective config includes the expected `snmp` and `netflow` receivers.
