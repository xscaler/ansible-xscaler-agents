# Network telemetry: SNMP, NetFlow, sFlow, IPFIX

Routers, switches, and firewalls can't run an agent. Instead they **export** telemetry to a
dedicated **collector host** running the otel agent, which converts it for xScaler:

| Source protocol            | OTel receiver     | Becomes | Ships to        |
|----------------------------|-------------------|---------|-----------------|
| SNMP (v1 / v2c / v3)       | `snmpreceiver`    | metrics | xScaler metrics |
| NetFlow v5 / v9            | `netflowreceiver` | logs    | xScaler logs    |
| IPFIX                      | `netflowreceiver` | logs    | xScaler logs    |
| sFlow                      | `netflowreceiver` | logs    | xScaler logs    |

> SNMP is **pulled** (the collector polls devices). Flows are **pushed** (devices send to the
> collector). So SNMP needs device IPs + creds; flows need the device configured to export to
> the collector's IP:port.

## 1. Place a collector host

Add it to `collector_hosts` (a Linux box, dedicated — not also in `linux_hosts`):

```yaml
collector_hosts:
  hosts:
    netcollector-01.example.com:
```

## 2. SNMP polling

Define targets in `group_vars/collector_hosts.yml`. Each becomes its own receiver → metrics:

```yaml
snmp_targets:
  - name: core-switch-01
    endpoint: "udp://192.0.2.10:161"
    version: v2c
    community: "{{ vault_snmp_community }}"   # vault it
    collection_interval: "60s"

  - name: edge-router-01
    endpoint: "udp://192.0.2.20:161"
    version: v3
    security_level: auth_priv
    user: "monitor"
    auth_type: SHA
    auth_password: "{{ vault_snmp_auth_pw }}"
    privacy_type: AES
    privacy_password: "{{ vault_snmp_priv_pw }}"
```

**OIDs**: the default `snmp_metrics` spec collects 64-bit interface in/out octets (keyed by
interface index + name) and `sysUpTime`. To extend with vendor OIDs (CPU, memory, temps),
override `snmp_metrics` with your own block — same structure as
`roles/otelcol_network_collector/defaults/main.yml`.

## 3. Flow ingestion (NetFlow / sFlow / IPFIX)

The collector listens on UDP ports; default listeners:

| Scheme            | Default port |
|-------------------|--------------|
| NetFlow v5/v9     | `2055`       |
| sFlow             | `6343`       |
| IPFIX             | `4739`       |

Override in `group_vars/collector_hosts.yml`:

```yaml
flow_listeners:
  - { scheme: netflow, port: 2055 }
  - { scheme: sflow, port: 6343 }
  - { scheme: netflow, port: 4739 }
```

### Configure your devices to export

Point each device's flow exporter at the collector. Examples:

```text
# Cisco IOS NetFlow v9
ip flow-export destination 198.51.100.5 2055
ip flow-export version 9

# sFlow (sflowtool-style agents / many switch CLIs)
collector 198.51.100.5  6343
```

### Firewall

Open inbound UDP on the collector for each listener port from your device subnets only:

```bash
sudo ufw allow proto udp from 192.0.2.0/24 to any port 2055,6343,4739
```

## 4. Apply

```bash
ansible-playbook playbooks/network-collector.yml --ask-vault-pass --check
ansible-playbook playbooks/network-collector.yml --ask-vault-pass
```

## 5. Verify

```bash
systemctl status otelcol-contrib
journalctl -u otelcol-contrib -n 100 --no-pager   # look for receiver start + export success
# Confirm UDP listeners are up:
sudo ss -lunp | grep -E '2055|6343|4739'
```

In xScaler: query the SNMP metrics (e.g. `snmp_interface_in_octets`) and search the flow logs
from the collector host.

## Notes

- NetFlow v9/IPFIX use templates, so flow records appear only after the device sends its
  template packets (can take a minute).
- Requires an otel agent build that includes `snmpreceiver` + `netflowreceiver` (the
  standard upstream distribution does). Pin via `otelcol_version`.
