---
type: Operations
title: CI and PR checks
description: Docker build validate on ubuntu-latest.
tags: [operations, ci]
timestamp: 2026-07-21T00:00:00Z
---

# CI and PR checks

`pr.yml` / `ci.yml` run `bash scripts/validate` on `ubuntu-latest` (`actions/checkout@v7`). Default branch is `master`.
