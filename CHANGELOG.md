# Changelog

## [Unreleased] — Repository revival

### Added
- **Second agent: [`system-sentinel`](agents/system-sentinel/)** — read-only
  workstation posture assessment (storage, memory, exposure, patching,
  accounts), with a deterministic inventory script, 6-step taskrail, tests.
- **Example team: [`workstation-hardening-team`](agents/workstation-hardening-team/)**
  — a non-deploying team that composes `system-sentinel` (lead) and
  `privacy-champion` (telemetry) around one objective, with shared-state and
  result contracts and an orchestration test.
- **Registry index** (`tao.json`) and `scripts/build_index.py` to generate and
  verify it.
- **Repository conformance tests**: `tests/validate_packages.py` (layout +
  manifest + cross-package reference checks) and `tests/run_all.sh`.
- **Repository-level taskrail** `taskrails/new-agent-checklist.taskrail.json`.
- **Privacy Champion script set**: `enumerate_surfaces.sh`, `probe_surface.sh`,
  `apply_closure.sh` (dry-run default + explicit approval gate) and
  `verify_closure.sh`, alongside the existing `fingerprint.sh`.
- **Privacy Champion test suite**: readiness, boundary, authority, evidence and
  a read-only scenario rehearsal.
- **Privacy Champion `.pi/`** host integration surface (skill, prompt,
  workflow and extension notes) and a real `onboarding/README.md`.

### Changed
- **`docs/package-spec.md`** now documents the actual nested `agent:` /
  `team:` manifest schema used by the reference implementation, adds the
  repository layout and a registry-index section, and lists the script
  approval-gate requirement.
- **`README.md`** reflects the real repository layout and adds registry-index
  and conformance sections, plus the second agent and the example team.
- **Privacy Champion `agent.yaml`** is now valid YAML (it previously mixed a
  sequence and a mapping under `state:`), records the full script/test set, and
  points at the monorepo path rather than a non-existent standalone repository.
- **Privacy Champion `README.md`** clones the monorepo and uses the taskrail
  runner for induction and audit.
- **Privacy Champion `data/surface-catalog.json`** gained machine-executable
  `probe_command` / `closure_command` metadata with disabled/enabled
  indicators, and explicit `probe_kind: manual` markers for GUI surfaces.

### Removed
- Root-level `sops/` and `onboarding/` placeholder directories (these belong
  inside each package, per the specification).
- The daemon-specific `sysadmin-health-check` taskrail, which referenced
  infrastructure paths outside the registry.

## [0.1.0] — Initial scaffold

### Added
- Repository scaffold: directory structure, README, LICENSE, .gitignore
- Package specification v0.1 (docs/package-spec.md)
- Local adaptation layer template (local/)
- [`privacy-champion`](agents/privacy-champion/) — the first TAO agent
- Vendored `taskrail` CLI and an example taskrail
