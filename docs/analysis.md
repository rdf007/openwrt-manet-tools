# Analysis

This document describes the CSV logging and Python-based analysis pipeline used by the OpenWrt MANET Tools project.

The purpose of the analysis pipeline is to transform raw telemetry collected during field tests into interpretable RF and mesh performance graphs.

---

# Analysis Pipeline Overview

Current workflow:

```text
Field Test
→ CSV Logging
→ CSV Download
→ Python Processing
→ Averaging
→ Graph Generation
→ RF Interpretation