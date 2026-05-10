# Metrics

This document describes the telemetry metrics currently collected by the OpenWrt MANET Tools dashboard.

Understanding these metrics is critical for interpreting:

- RF link quality
- PHY adaptation behavior
- mesh stability
- operational usability
- congestion
- interference

The dashboard intentionally exposes metrics from multiple layers:

- RF layer
- PHY layer
- MAC layer
- Mesh routing layer

This provides significantly better visibility than RSSI alone.

---

# RF Metrics

RF metrics describe the physical radio environment.

These metrics are strongly influenced by:

- distance
- obstacles
- interference
- reflections
- antenna placement
- environment

---

# RSSI

## Definition

RSSI stands for:

```text
Received Signal Strength Indicator