# Architecture

This document describes the current architecture of the OpenWrt MANET Tools project.

The system is designed for lightweight, field-deployable MANET experimentation and RF observability using OpenWrt-based hardware.

---

# Hardware Platform

## GL.iNet AXT1800

Current hardware platform:

- GL.iNet AXT1800
- OpenWrt-based
- Dual-band Wi-Fi
- Compact form factor
- Portable deployment
- Low power consumption

The platform provides sufficient performance for:

- 802.11s mesh networking
- ATAK traffic
- telemetry collection
- browser dashboards
- VoIP testing
- CSV logging

---

# Network Architecture

The current architecture separates:

- mesh backhaul traffic
- client access traffic

This separation improves:

- RF isolation
- operational stability
- client usability
- mesh consistency

---

# Mesh Backhaul

## Interface

```text
wlan1