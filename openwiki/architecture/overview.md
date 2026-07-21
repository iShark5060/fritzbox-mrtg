---
type: Architecture Overview
title: Container layout
description: How the FRITZ!Box polling and web UI fit together.
tags: [architecture]
timestamp: 2026-07-21T00:00:00Z
---

# Container layout

The image runs periodic UPnP polls against a FRITZ!Box, feeds MRTG/RRDtool, and serves graphs via nginx. Persistent data mounts at `/srv/www/htdocs`. Optional SSL certs mount at `/etc/nginx/ssl/`. Environment variables control poll interval, dark mode, bandwidth caps, and Fritz model/IP — see the root README.
