---
type: Quickstart
title: FritzBox-MRTG quickstart
description: Entry point for the FRITZ!Box MRTG Docker image.
tags: [quickstart]
timestamp: 2026-07-21T00:00:00Z
---

# FritzBox-MRTG quickstart

Dockerized FRITZ!Box bandwidth monitoring: `upnp2mrtg` → MRTG/RRDtool → nginx (optional SSL, dark mode).

## Stack

- Alpine base image (`dockerfile`)
- Shell + nginx + MRTG + RRDtool
- Validate: `scripts/validate` → `docker build`

## Next

- [architecture/overview.md](architecture/overview.md)
- [operations/ci.md](operations/ci.md)
- Root [README.md](../README.md) for compose/env vars
