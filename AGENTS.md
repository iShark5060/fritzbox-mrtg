# FritzBox-MRTG

Alpine Docker image that polls a FRITZ!Box via UPnP and graphs bandwidth with MRTG / RRDtool / nginx.

## Engineering standards

Follow AppBase `docs/org-standards/` with personal-repo overrides (`personal-repos.md`):

- Runners: `ubuntu-latest`
- Checkout: `actions/checkout@v7`
- Quality gate: `scripts/validate` (`docker build`)

## OpenWiki

This repository has documentation located in the /openwiki directory.

Start here:

- [OpenWiki quickstart](openwiki/quickstart.md)

OpenWiki includes repository overview, architecture notes, workflows, domain concepts, operations, integrations, testing guidance, and source maps.

When working in this repository, read the OpenWiki quickstart first, then follow its links to the relevant architecture, workflow, domain, operation, and testing notes.
