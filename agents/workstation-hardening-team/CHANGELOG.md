# Changelog

## 0.1.0 — Experimental Release

- Initial example team package following TAO specification v0.1
- Composes two real in-repo agents: `system-sentinel` (lead) and
  `privacy-champion` (telemetry)
- Orchestration workflow: 6-step hardening baseline
  (intake → posture → telemetry plan → combined approval gate → apply → verify)
- Shared-state contract (`schemas/team-state.json`) and result contract
  (`schemas/hardening-report.json`)
- Aggregate authority: least-privilege intersection; mutations require
  target-specific explicit approval; destructive prohibited by default
- Failure policy: `halt_before_mutation_if_required_member_fails`
- Orchestration test validating manifest, members, owners and budgets

### Notes
- **Non-deploying example.** This package is not offered as a supported
  deployment; it exists to exercise the team manifest and orchestration model.
