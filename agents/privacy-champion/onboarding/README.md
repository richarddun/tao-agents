# Onboarding — induction

Induction adapts the Privacy Champion to a specific machine **without touching
the curated core**. It interviews the user for facts that cannot be discovered,
observes the environment with read-only scripts, proposes bindings, confirms
them, validates readiness, and writes the local adaptation layer.

The workflow lives in [`induction.taskrail.json`](induction.taskrail.json) — a
seven-task rail driven one task at a time.

## What induction produces

A single generated file, `../local/environment.yaml`, holding the environment
bindings:

```yaml
detected_os: linux
detected_browsers: [firefox, chrome]
privilege_level: standard
tier_preference: "Tiers 1+2"
workspace: ./local/
backup_location: ./local/backups/
report_format: markdown
```

`local/` is gitignored. Induction never edits anything under `scripts/`,
`taskrails/`, `sops/`, `data/`, `SYSTEM.md` or `agent.yaml` — the curated core
is immutable per the TAO two-layer portability model.

## Running induction

```bash
# From the repository root, using the vendored reference runner:
bash scripts/taskrail start --name induction \
    --taskrails-dir agents/privacy-champion/onboarding
```

Or, in a host that supports named rails natively, start the `induction` rail.

## The seven steps

| # | Task | Produces |
|---|------|----------|
| 1 | `verify_platform` | Supported OS confirmed (Windows / macOS / Linux) |
| 2 | `check_dependencies` | Missing tools reported with install commands |
| 3 | `explain_approval_model` | User understands tiers and the approval gate |
| 4 | `run_dry_run_fingerprint` | Environment validated end to end |
| 5 | `generate_local_config` | `local/environment.yaml` |
| 6 | `run_readiness_check` | PASS / PARTIAL / FAIL readiness report |
| 7 | `complete_induction` | Handoff to the audit rail |

## Readiness

Step 6 runs [`../tests/readiness-check.sh`](../tests/readiness-check.sh). It
checks tools, script permissions, catalog and taskrail parsing, and workspace
writability, then performs a read-only smoke probe. It exits `0` (PASS),
`1` (PARTIAL — the audit can proceed with limitations) or `2` (FAIL).

## Security rules

- Induction **never** asks for credentials in conversational text.
- Induction **never** embeds secrets in generated configuration.
- Memory handling happens locally; nothing is transmitted.
