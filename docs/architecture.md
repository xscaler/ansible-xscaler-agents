# Architecture

## Control Flow

```text
Ansible
  ├─ installs xscaler-collector (apt/yum package or Windows MSI)
  ├─ removes any otelcol-contrib and opampsupervisor left by older versions
  └─ renders supervisor bootstrap config

xscaler-collector service (the OpAMP supervisor)
  ├─ connects to agent-api over OpAMP
  ├─ enrolls with xse_ token
  ├─ stores returned xag_ per-agent credential
  ├─ receives matching remote config from fleet manager
  └─ starts/restarts xscaler-collector with that config
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
| `otelcol_linux`             | sets the `linux_host` label and includes the supervisor role |
| `otelcol_windows`           | sets the `windows_host` label and includes the supervisor role |
| `otelcol_network_collector` | sets the `network_collector` label and includes the supervisor role |
| `opampsupervisor`           | removes the old otelcol-contrib install, installs the pinned `xscaler-collector` package or MSI, renders the supervisor config and starts the service |

## Installed Layout

| | Linux | Windows |
|---|---|---|
| Binaries | `/usr/bin/xscaler-collector`, `/usr/bin/xscaler-supervisor` | `C:\Program Files\xScaler Collector` |
| Service | `xscaler-collector` (user `xscaler-collector`) | `xscaler-collector` (LocalSystem) |
| Supervisor config | `/etc/xscaler-collector/supervisor.yaml` | `C:\ProgramData\xScaler Collector\supervisor.yaml` |
| Token and endpoint | `/etc/xscaler-collector/xscaler-collector.env` | in `supervisor.yaml` |
| State | `/var/lib/xscaler-collector` | `C:\ProgramData\xScaler Collector\state` |

Linux packages come from the signed repository at
`https://packages.xscalerlabs.com` (`/apt` and `/rpm`). Windows installs
`xscaler-collector_<version>_windows_<arch>.msi` from the `xscaler/xscaler-agent`
GitHub release.

## Versions

`xscaler_collector_version` (default `0.6.0`) pins the package version. Set
`opampsupervisor_packages_channel: testing` to follow release candidates. The
variables `otelcol_version` and `opampsupervisor_version` are gone; the playbooks
stop with an error if an inventory still sets them.

## Upgrading From otelcol-contrib

The first run on a host that has the old install stops and disables the
`otelcol-contrib` and `opampsupervisor` services, removes the `otelcol-contrib`
package, the `opampsupervisor` unit and binary, `/etc/opampsupervisor` and
`/var/lib/opampsupervisor` (Windows: the two services and their install and
config folders), then installs `xscaler-collector`. The agent enrolls again
with the same token and appears in fleet manager as a new agent.
