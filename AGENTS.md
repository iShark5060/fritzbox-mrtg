# FritzBox-MRTG

## Org standards

CI/README/validate conventions live in AppBase `docs/org-standards/` with personal-repo overrides (`personal-repos.md`). GitHub-hosted `ubuntu-latest`, not Blacksmith. Quality gate: `scripts/validate` (`docker build -f dockerfile`). Dockerfile is lowercase `dockerfile` at the repo root; image content lives under `fritzbox-mrtg/`.

## Overview

Alpine image that polls a FRITZ!Box over UPnP (`upnp2mrtg`), graphs with MRTG / RRDtool, and serves via nginx (`14all.cgi`). User-facing env and compose: `README.md`.

## Persistence

Mount `/srv/www/htdocs` for RRD, logs, and HTML. Optional SSL: mount `/etc/nginx/ssl/` with `cert.pem` + `cert.key` and set `USE_SSL=1` (nginx listens on **443** in-container).

`/etc/mrtg.cfg` is generated from the template only when missing. Changing bandwidth caps, dark mode, model, or poll interval on an existing container does **not** rewrite MRTG config until that file is gone or the container filesystem is recreated. `/etc/upnp2mrtg.cfg` **is** rewritten every start from `FRITZBOX_IP`. Volume `style.css` / `index.html` are seeded only if absent: delete `style.css` to restore stock assets; a stale `index.html` can keep an old stylesheet link after flipping `USE_DARKMODE`.

## Runtime

Fritz UPnP status export must be on; the container must reach `FRITZBOX_IP`. Binary flags are `0`/`1`. `POLL_INTERVAL` seconds become MRTG `Interval` via integer minutes (`/ 60`). Five consecutive `mrtg` failures exit the process. First-boot Rateup “could not read primary log file” warnings are normal.
