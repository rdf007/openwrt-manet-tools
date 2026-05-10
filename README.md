# OpenWrt MANET Tools

Lightweight tools for RF telemetry, observability, and range testing on OpenWrt-based MANET nodes.

This project focuses on practical field testing and operational visibility for 802.11s mesh networks used with systems such as ATAK, tactical VoIP, and off-grid communications.

---

# Overview

The project currently provides:

- 802.11s mesh telemetry dashboard
- Browser-based RF observability
- CSV logging for field measurements
- Python-based graph generation
- Distance-aware range testing
- ATAK-oriented test methodology
- Lightweight OpenWrt deployment
- Mobile-friendly operation

The goal is to create a simple and practical toolkit for understanding real-world mesh network behavior under mobility and field conditions.

---

# Current Capabilities

## OpenWrt Mesh Dashboard

The dashboard runs directly on OpenWrt using CGI shell scripts and provides live telemetry from the mesh interface.

Current metrics include:

- RSSI
- Signal Average
- ACK Signal
- Noise Floor
- SNR
- Channel Busy %
- TX/RX PHY Rate
- TX/RX MCS
- Retries
- TX Fail Count
- Airtime Metric
- Connected Time

The dashboard also supports:

- CSV logging
- measurement counting
- CSV download
- CSV clearing
- distance tagging

---

## Python Analysis Tools

The Python analysis pipeline currently supports:

- CSV loading
- automatic numeric conversion
- averaging multiple samples per distance
- graph generation
- RF trend visualization

Current plots include:

- RSSI vs Distance
- SNR vs Distance
- Airtime vs Distance
- MCS vs Distance
- Retries vs Distance
- Channel Busy vs Distance

---

# Example Topology

```text
 Smartphone
     |
 5 GHz AP
     |
NODE1 ))) 802.11s 2.4GHz ((( NODE2
     |
 5 GHz AP
     |
 Smartphone
```
---

# Documentation

- [Architecture](docs/architecture.md)
- [Setup](docs/setup.md)
- [Range Test Protocol](docs/protocol.md)
- [Metrics](docs/metrics.md)
- [Analysis](docs/analysis.md)
- [Roadmap](docs/roadmap.md)