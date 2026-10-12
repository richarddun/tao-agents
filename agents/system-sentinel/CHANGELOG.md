# Changelog

## 0.1.0 — Experimental Release

- Initial package following TAO specification v0.1
- Read-only posture inventory (`scripts/inventory.sh`): OS, kernel, uptime,
  CPU, memory, swap, load, filesystems, listening sockets, firewall, disk
  encryption, pending updates, privileged users
- Core taskrail: 6-step system assessment (inventory → storage → memory/load →
  exposure → patching → summary)
- Induction taskrail: 5-step onboarding
- SOP with default warning thresholds per area
- Result contract: `schemas/posture-report.json`
- Tests: readiness, boundary, evidence and a read-only scenario rehearsal
- Authority: read-only by design; no mutation capability

### Known gaps
- Windows is not supported in v0.1 (collection commands differ materially)
- Pending-update severity is not available from package managers; only the
  count is reported
- Some fields (firewall state, privileged groups) report `unknown` without
  administrator access
