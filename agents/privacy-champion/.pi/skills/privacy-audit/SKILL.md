---
name: privacy-audit
description: Run the Privacy Champion's telemetry audit and hardening loop on a personal computer. Fingerprints the OS and browsers, enumerates 40+ known telemetry surfaces, probes current state, classifies risk, presents a gated approval plan, applies approved closures, verifies, and reports. Use when the user asks to audit or reduce what their computer shares with vendors.
---

# Privacy Audit

## When to use

- First-time setup of a personal computer
- Periodic (quarterly) privacy hygiene
- After a major OS or browser update (telemetry is sometimes re-enabled)
- Pre-travel preparation
- The user asks "what is my computer sharing?" or "harden my privacy"

## Prerequisites

Run `tests/readiness-check.sh` first. It verifies `bash` and `python3`,
that every bundled script is executable, that the surface catalog and both
taskrails parse, and that a workspace is writable. If it reports `FAIL`,
resolve the reported items before starting.

## How to run

Drive the audit through the taskrail — one task at a time, never pre-completing:

```bash
# From the repository root, pointing the vendored runner at this package:
bash scripts/taskrail start --name privacy-audit \
    --taskrails-dir agents/privacy-champion/taskrails
```

Hosts that support named taskrails natively (e.g. Pi Coding Agent heads) can
load `privacy-audit` directly. The induction rail lives in the package's
`onboarding/` directory.

The eight steps are: fingerprint → enumerate → probe → classify →
**approval gate** → apply → verify → report. The taskrail embeds the
constraints and the evidence gate for each step; the methodology lives in
`sops/privacy-audit.sop.md`.

## Non-negotiable

1. **No mutation without explicit approval.** `scripts/apply_closure.sh`
   refuses unless called with both `--apply` and `--approved`.
2. **No claim without verification.** After applying, re-probe with
   `scripts/verify_closure.sh`.
3. **No transmission.** Audit data never leaves the machine.
4. **No guessing.** Surfaces the agent cannot probe are reported as
   `UNKNOWN` with the reason, not silently skipped.

## Tooling

| Script | Mode | Purpose |
|--------|------|---------|
| `scripts/fingerprint.sh` | read-only | OS/browser/tool detection |
| `scripts/enumerate_surfaces.sh` | read-only | Filter the catalog for this platform |
| `scripts/probe_surface.sh` | read-only | Probe one surface's state |
| `scripts/apply_closure.sh` | **mutating** | Apply a pre-approved closure |
| `scripts/verify_closure.sh` | read-only | Re-probe after closure |
