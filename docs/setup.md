# Setup

This document describes how to configure and deploy the OpenWrt MANET Tools environment.

The current implementation targets OpenWrt-based devices such as the GL.iNet AXT1800.

---

# Requirements

## Hardware

Recommended hardware:

- GL.iNet AXT1800
- Similar OpenWrt-compatible routers may also work

---

# Software Requirements

## OpenWrt

An OpenWrt-based firmware is required.

The project currently relies on:

- SSH access
- uhttpd
- CGI support
- iw wireless utilities

---

# Development Environment

Recommended development environment:

- VSCode
- Git
- Python 3
- Linux VM or Linux host

---

# Network Configuration

## Recommended IP Scheme

To avoid conflicts with home routers:

| Device | IP |
|---|---|
| Node1 | 10.10.10.1 |
| Node2 | 10.10.10.2 |

Avoid common consumer subnets such as:

```text
192.168.0.x
192.168.1.x
192.168.8.x