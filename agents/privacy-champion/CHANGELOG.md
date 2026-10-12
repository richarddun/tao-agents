# Changelog

## 0.1.0 — Experimental Release

### Package structure
- Initial package following TAO specification v0.1
- `agent.yaml` manifest with authority boundaries, compatibility matrix, lifecycle and local-adapter definitions
- `SYSTEM.md` operating doctrine with non-negotiable boundaries and failure modes
- README with quick start, platform support and safety notes
- `.pi/` host integration surface (skills, prompts, workflows, extensions)

### Workflows
- Core taskrail: 8-step privacy audit (fingerprint → enumerate → probe → classify → approval gate → apply → verify → report)
- Induction taskrail: 7-step onboarding (verify platform → check dependencies → explain model → dry run → generate config → readiness check → complete)

### Knowledge
- Surface catalog: 40+ known telemetry surfaces across Windows 10/11, macOS 13–15 and Linux (Ubuntu/Fedora/Debian), plus Chrome, Firefox, Edge, Safari and Brave
- Each catalog entry carries a `probe_kind`. Entries whose probe is a real shell command also carry `probe_command`, `closure_command` and disabled/enabled indicators so the tooling can execute and classify them. GUI and browser-preference surfaces are marked `manual` rather than pretending to be automated.

### Tooling (deterministic scripts)
- `scripts/fingerprint.sh` — OS/browser/tool detection, JSON output
- `scripts/enumerate_surfaces.sh` — filter the catalog by platform and detected browsers
- `scripts/probe_surface.sh` — probe one surface's state (read-only)
- `scripts/apply_closure.sh` — the only mutating script; dry-run by default and a hard `--approved` gate
- `scripts/verify_closure.sh` — re-probe after closure

### Tests
- `tests/readiness-check.sh` — tools, script permissions, catalog/rail parsing, workspace, smoke probe
- `tests/boundary_test.sh` — out-of-scope and over-authority refusals
- `tests/authority_test.sh` — approval-gate enforcement (declared and behavioural)
- `tests/evidence_test.sh` — machine-readable evidence contracts
- `tests/scenario_test.sh` — read-only end-to-end rehearsal
- `tests/run_all.sh` — all suites

### Known gaps
- Windows: closed-source telemetry channels cannot be fully verified (a probe may show "disabled" while kernel-level collection continues)
- macOS: System Integrity Protection (SIP) prevents modifying some OS-level telemetry paths
- Linux: distribution fragmentation means not all package telemetry channels are catalogued
- All platforms: browser fingerprinting (canvas, WebGL, font enumeration) is a privacy surface not yet addressed
- All platforms: application-level telemetry beyond browsers is minimal in v0.1
- Network: DNS-over-HTTPS configuration is recommended but not automated (requires a resolver choice)
- Manual surfaces (`probe_kind: manual`) require the agent to walk the user through GUI checks; they are not machine-verifiable
