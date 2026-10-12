---
name: workstation-hardening-team
description: An objective-driven team that brings a personal workstation to a hardened, low-telemetry baseline. The system-sentinel leads a read-only posture assessment; the privacy-champion audits telemetry and applies only operator-approved closures; the lead synthesises one evidence-backed hardening report.
---

# Workstation Hardening Team

> **Status: non-deploying example.** This package demonstrates the TAO *team*
> manifest and orchestration model. It composes two real member agents shipped
> in this repository. It is experimental and is not offered as a supported
> deployment.

## Objective

Bring a machine to a hardened baseline: assess its security posture, audit and
close telemetry surfaces with the operator's per-surface approval, and deliver
one evidence-backed hardening report.

## Composition

| Member | Role | Authority ceiling |
|--------|------|-------------------|
| [`system-sentinel`](../system-sentinel/) | **Lead** — intake, posture assessment, synthesis, final result | read + propose |
| [`privacy-champion`](../privacy-champion/) | Telemetry auditor and closure operator | read + propose; mutate only with per-surface approval |

A team is not a folder of personas. Each member is an independently bounded
agent with its own doctrine. The team package adds only orchestration, shared
contracts, aggregate authority and end-to-end verification.

## Why two members

The objective needs a read-only assessor and a gated closure operator. One
agent could not hold both honestly: the assessor must remain incapable of
mutation while the auditor must be able to mutate with approval. Keeping them
separate preserves that boundary and gives the operator independent visibility.

## Workflow

```
intake → posture (lead) → telemetry plan (member, paused at gate)
       → combined approval gate (lead) → apply approved (member)
       → verify + synthesise (lead)
```

The workflow is `taskrails/hardening-baseline.taskrail.json`; the methodology
is `sops/team-orchestration.sop.md`.

## Contracts

| Contract | Path |
|----------|------|
| Shared state | `schemas/team-state.json` |
| Result | `schemas/hardening-report.json` |

## Authority

```
aggregate:   least_privilege_intersection
mutate:      target_specific_explicit_approval
destructive: prohibited_by_default
```

No member inherits the team's authority. Every mutation waits for one explicit
operator decision at the combined gate. Failure policy:
`halt_before_mutation_if_required_member_fails`.

## Package Structure

```
workstation-hardening-team/
├── README.md
├── SYSTEM.md
├── team.yaml
├── CHANGELOG.md
├── LICENSE
├── taskrails/
│   └── hardening-baseline.taskrail.json  ← Orchestration workflow (6 steps)
├── sops/
│   └── team-orchestration.sop.md
├── schemas/
│   ├── team-state.json                    ← Shared state contract
│   └── hardening-report.json              ← Result contract
├── tests/
│   └── run_all.sh                         ← Orchestration test
├── onboarding/
│   └── README.md
└── .pi/
    └── README.md
```

## Validate

```bash
bash agents/workstation-hardening-team/tests/run_all.sh
```

## License

MIT — see LICENSE file.
