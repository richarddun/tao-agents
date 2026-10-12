# System Assessment — Standard Operating Procedure

> Referenced by: `taskrails/system-assessment.taskrail.json`
> Owner: System Sentinel agent
> Version: 0.1.0

## Purpose

This SOP defines the execution methodology for the system-assessment taskrail.
The taskrail provides the WHAT (constraints and validation gates); this SOP
provides the HOW (techniques, thresholds, and error handling).

## Pre-Assessment Checklist

- [ ] Confirm `bash` and `python3` are available
- [ ] Confirm `scripts/inventory.sh` is executable
- [ ] Note the privilege level — without admin, several fields will report `unknown`

## Collection

Run `scripts/inventory.sh` once and reuse its JSON. Do not run it repeatedly
during the assessment: the point of the snapshot is that it is a single point
in time.

## Thresholds

| Area | HIGH | MEDIUM | LOW / INFO |
|------|------|--------|------------|
| Filesystem usage | > 90% | 85–90% | < 85% |
| Swap usage | > 75% | 50–75% | < 50% |
| Load average (1m / cpus) | > 2.0× | 1.0–2.0× | < 1.0× |
| Pending updates | > 50 | 1–50 | 0 |
| Externally reachable listener | unexpected service | all listener | loopback only |
| Firewall | inactive/unknown | — | active |
| Disk encryption | none-detected | unknown | luks-present / FileVault On |

Thresholds are defaults; the local adaptation layer may tighten them.

## Per-Area Guidance

### Storage
Report each filesystem's usage. Flag the highest. State encryption status as
one of `luks-present`, `none-detected`, `FileVault On`, `FileVault Off`, or
`unknown`. Absence of detected encryption is a HIGH finding for a portable
machine and INFO for a server — state which assumption you are making.

### Memory and load
A single sampled load average can mislead. Report the 1/5/15-minute figures
together and compare the 1-minute figure to the CPU count. Swap *usage* above
50% is the useful risk signal, not swap *total*.

### Exposure
Split listeners into loopback (`127.*`, `::1`) and all-interfaces (`0.0.0.0`,
`*`, `::`). Every all-interfaces listener is externally reachable and must be
listed. Cross-check the firewall status: an inactive firewall with
all-interfaces listeners is a HIGH finding.

### Patching
Report the pending count. Do **not** infer severity from the count. Recommend
a maintenance window; never install.

### Summary
Produce the report against `schemas/posture-report.json`. Every finding cites
its `evidence_field`. Unknowns are listed explicitly.

## Error Recovery

| Scenario | Action |
|----------|--------|
| A collection command fails | Report the field as `unknown` with the reason; continue |
| The OS is unsupported | Report what was collected, state the limitation |
| A field needs admin | Report `unknown`; do not attempt privilege escalation |
| The operator asks for a fix | State the read-only authority boundary; hand them the recommendation |
