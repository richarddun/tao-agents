# Team Orchestration — Standard Operating Procedure

> Referenced by: `taskrails/hardening-baseline.taskrail.json`
> Owner: Workstation Hardening Team (`system-sentinel` lead)
> Version: 0.1.0

## Purpose

This SOP defines how the two members are sequenced, what crosses the member
boundary, and where the gates are. The taskrail is the authoritative workflow;
this SOP explains the mechanics.

## Roles

- **Lead (`system-sentinel`)** — owns intake, the combined approval gate,
  synthesis and the final result. Read-only.
- **Telemetry member (`privacy-champion`)** — audits telemetry surfaces and,
  with per-surface operator approval, applies closures.

## Handoff contracts

Each handoff passes the minimum task-relevant context. Full inventories and
full conversations are not inherited.

| From → To | Passed | Not passed |
|-----------|--------|------------|
| operator → lead | objective, target machine | — |
| lead → telemetry member | posture findings relevant to telemetry, target | full inventory, operator identity |
| telemetry member → lead | tiered plan, then applied change log + verification | raw environment details |
| lead → operator | combined plan, then hardening report | member tool transcripts |

## Sequence

```
intake → posture (lead) → telemetry plan (member, paused at gate)
       → combined approval gate (lead) → apply approved (member)
       → verify + synthesise (lead)
```

1. **Intake** — the lead restates objective, target and aggregate authority,
   and records member availability.
2. **Posture** — the lead runs its read-only assessment and returns findings.
3. **Telemetry plan** — the member runs its audit up to its classify step and
   stops. It must not apply anything.
4. **Combined gate** — the lead merges posture recommendations and telemetry
   tiers into one plan, marks every mutating action and its member, and waits.
5. **Apply** — the member applies only approved closures through its gated
   tooling, logging each change and halting on failure.
6. **Verify + synthesise** — the lead re-collects posture, confirms every
   approved closure verified, and produces `schemas/hardening-report.json`.

## Gates

| Gate | Owner | Rule |
|------|-------|------|
| Approval | lead | One explicit operator decision before any mutation |
| Apply | member | `--apply --approved` only; dry-run default |
| Verification | lead | Completion requires confirmed `DISABLED` per approved surface |

## Failure policy

`halt_before_mutation_if_required_member_fails`. If the telemetry member is
unavailable, the run continues in `DEGRADED` mode with no mutation. If a
closure fails during apply, the member halts and reports; the lead synthesises
a `PARTIAL` result and preserves the failure as an unresolved risk.

## Budgets

`max_agents: 3`, `max_parallel: 1`, `max_iterations: 2` (declared in
`team.yaml`). The workflow is intentionally serial: telemetry work depends on
posture findings and on approval.
