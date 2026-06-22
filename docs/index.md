# xScaler Agents (Ansible)

Install the xScaler OpenTelemetry bootstrap on Linux hosts, Windows hosts, and
network collector hosts. Ansible installs the collector binary and OpAMP
supervisor; xScaler fleet manager delivers the actual telemetry config.

## Pick Your Path

| You want to enroll…          | Read                                           |
|------------------------------|------------------------------------------------|
| Linux servers (Ansible)      | [quickstart-linux.md](quickstart-linux.md)     |
| Linux servers (Docker)       | [quickstart-linux-docker.md](quickstart-linux-docker.md) |
| Windows servers              | [quickstart-windows.md](quickstart-windows.md) |
| Network collector hosts      | [network-telemetry.md](network-telemetry.md)   |
| Enrollment/auth flow         | [authentication.md](authentication.md)         |
| Troubleshooting              | [troubleshooting.md](troubleshooting.md)       |
| Architecture                 | [architecture.md](architecture.md)             |

## In One Paragraph

Each target runs `opampsupervisor`, which connects to
`wss://agents.xscalerlabs.com/v1/opamp` with an enrollment token. The xScaler
OpAMP control plane mints a per-agent credential, stores the agent labels, and
pushes the matching collector config from fleet manager. The local installer no
longer embeds ingestion endpoints or telemetry pipelines.
