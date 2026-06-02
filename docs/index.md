# xScaler Agents (Ansible)

Install the xScaler otel agent across your **Linux** and
**Windows** servers, and stand up dedicated **network-telemetry collectors** for
**SNMP**, **NetFlow**, **sFlow**, and **IPFIX** — all shipping **metrics, logs, and traces**
to xScaler.

## Pick your path

| You want to monitor…                          | Read                                              |
|-----------------------------------------------|---------------------------------------------------|
| Linux servers (metrics, logs, app traces)     | [quickstart-linux.md](quickstart-linux.md)        |
| Windows servers (metrics, Event Log, traces)  | [quickstart-windows.md](quickstart-windows.md)    |
| Routers / switches / firewalls (SNMP + flows) | [network-telemetry.md](network-telemetry.md)      |
| How auth + tenancy works                      | [authentication.md](authentication.md)            |
| Something's not arriving                       | [troubleshooting.md](troubleshooting.md)          |
| The big picture                                | [architecture.md](architecture.md)                |

## In one paragraph

A single otel agent runs on each host. It scrapes host metrics, tails logs
(journald / files on Linux, Event Log on Windows), and accepts OTLP from local apps for
traces. Network gear can't run an agent, so they export SNMP/NetFlow/sFlow/IPFIX to a small
fleet of **collector hosts** that translate those into metrics and logs. Everything is
authenticated with a Bearer API key and your tenant id, and routed to xScaler as metrics,
logs, and traces.

See the repo [README](../README.md) for the install commands.
