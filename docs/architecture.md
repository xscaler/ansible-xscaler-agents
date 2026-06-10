# Architecture

## Control Flow

```text
Ansible
  ├─ installs otelcol-contrib
  ├─ installs opampsupervisor
  └─ renders supervisor bootstrap config

opampsupervisor
  ├─ connects to agent-api over OpAMP
  ├─ enrolls with xse_ token
  ├─ stores returned xag_ per-agent credential
  ├─ receives matching remote config from fleet manager
  └─ starts/restarts otelcol-contrib with that config
```

## Data Flow

Telemetry flow is not encoded by Ansible anymore. Fleet manager config templates
define receivers, processors, exporters, and pipelines. Example templates live in
`examples/fleet-manager/`.

Typical assignments:

| Host group        | Bootstrap label                         | Fleet config example |
|-------------------|------------------------------------------|----------------------|
| `linux_hosts`     | `agent_profile=linux_host`               | `linux-host.yaml`    |
| `windows_hosts`   | `agent_profile=windows_host`             | `windows-host.yaml`  |
| `collector_hosts` | `agent_profile=network_collector`        | `network-collector.yaml` |

Fleet manager can also target labels such as `environment`, `region`, `team`, or
`tier`. Labels come from `xscaler_agent_labels` and the profile label added by
each role.

## Roles

| Role                        | Responsibility |
|-----------------------------|----------------|
| `otelcol_common`            | validates OpAMP endpoint and enrollment token |
| `otelcol_linux`             | installs Linux collector package and includes supervisor role |
| `otelcol_windows`           | installs Windows collector binary and includes supervisor role |
| `otelcol_network_collector` | installs Linux collector package and includes supervisor role with network profile |
| `opampsupervisor`           | installs supervisor, renders bootstrap config, disables standalone collector service |
