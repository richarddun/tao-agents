# Onboarding — induction

Induction adapts the System Sentinel to a specific machine without touching the
curated core. It verifies the platform, checks tooling, confirms warning
thresholds, writes the local adaptation layer, and runs a readiness check.

The workflow is [`induction.taskrail.json`](induction.taskrail.json) — five
tasks driven one at a time.

## What induction produces

`../local/environment.yaml`:

```yaml
detected_os: linux
privilege_level: standard
report_format: markdown
thresholds:
  disk_warn_percent: 85
  disk_high_percent: 90
  swap_warn_percent: 50
  load_warn_multiple: 1.0
```

`local/` is gitignored. Induction never edits `scripts/`, `taskrails/`,
`sops/`, `schemas/`, `SYSTEM.md` or `agent.yaml`.

## Running induction

```bash
# From the repository root:
scripts/taskrail start --name induction \
    --taskrails-dir agents/system-sentinel/onboarding
```

## The five steps

| # | Task | Produces |
|---|------|----------|
| 1 | `verify_platform` | Supported OS + privilege level confirmed |
| 2 | `check_dependencies` | Missing tools reported with install commands |
| 3 | `set_thresholds` | Warning thresholds chosen |
| 4 | `write_local_config` | `local/environment.yaml` |
| 5 | `run_readiness_and_complete` | Readiness report + handoff |

## Readiness

Step 5 runs [`../tests/readiness-check.sh`](../tests/readiness-check.sh), which
checks tools, script permissions, taskrail parsing, schema parsing and
workspace writability, then performs a read-only collection. It exits `0`
(PASS), `1` (PARTIAL) or `2` (FAIL).

## Security rules

- Induction never asks for credentials.
- Induction never embeds secrets in generated configuration.
