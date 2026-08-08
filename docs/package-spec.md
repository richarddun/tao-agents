# TAO Package Specification v0.1

## 1. Overview

A TAO package is a versioned directory containing a complete, portable, operational AI agent or agent team. The package separates the **curated operational core** (maintained by the TAO project) from the **local adaptation layer** (generated during user induction).

## 2. Required Files

| File | Required | Description |
|------|----------|-------------|
| `README.md` | Yes | Human-readable overview, install instructions, task examples |
| `SYSTEM.md` | Yes | Agent or team operating doctrine — the system prompt |
| `agent.yaml` / `team.yaml` | Yes | Machine-readable manifest (see §3) |
| `CHANGELOG.md` | Yes | Version history and behavioural changes |
| `LICENSE` | Yes | Distribution license |
| `sops/` | Yes | Standard operating procedures (markdown, one per procedure) |
| `scripts/` | Conditional | Deterministic scripts, if the agent uses any |
| `tests/` | Yes | Boundary, authority, and scenario tests |
| `onboarding/` | Yes | Induction interview and readiness checks |
| `.pi/` | Yes | Pi SDK extensions, skills, prompts, workflows |

## 3. Manifest Schema

### 3.1 `agent.yaml`

```yaml
# Identity
name: string           # Machine-readable slug
title: string          # Human-readable name
version: string        # Semver
type: agent            # agent | team
description: string    # 1-2 sentence mission statement
maintainer: string     # Name or handle
license: string        # SPDX identifier

# Compatibility
pi_version: string     # Minimum Pi SDK version
os: [string]           # Supported operating systems
model_recommendations: # Optional guidance
  provider: string
  family: [string]

# Authority
authority:
  read: string         # automatic | explicit_approval | prohibited
  propose: string
  mutate: string
  destructive: string

# Inputs / Outputs
inputs: [string]       # Required context fields
outputs: [string]      # Evidence and result fields

# State
state:
  memory: string       # Memory storage description
  retention: string    # Retention policy
  sharing: string      # What crosses agent boundaries

# Resources
resources:
  skills: [string]     # Skill names
  scripts: [string]    # Script paths
  sops: [string]       # SOP references

# Lifecycle
lifecycle:
  install: string      # Installation command
  induct: string       # Induction command
  validate: string     # Readiness check command
  upgrade: string      # Upgrade procedure
  remove: string       # Removal procedure

# Telemetry (opt-in)
telemetry:
  fields: [string]     # Collectable fields
  opt_in: boolean      # Default false
```

### 3.2 `team.yaml`

Extends `agent.yaml` with:

```yaml
type: team
objective: string          # The goal the team is built to achieve
lead: string               # Primary specialist agent slug
members:                   # Member agent roster
  - name: string
    role: string
    triggers: [string]     # When this member is invoked
    authority_ceiling: string
orchestration:
  workflow: string         # Entrypoint workflow path
  shared_state: string     # Schema path
  budgets:
    max_agents: number
    max_parallel: number
    max_iterations: number
  failure_policy: string   # halt | retry | escalate | degrade
result_contract: string    # Schema path for final deliverable
```

## 4. Operating Doctrine (SYSTEM.md)

SYSTEM.md is the agent's system prompt. It must:

1. Define professional identity, mission, and scope
2. Declare authority boundaries — non-negotiable constraints
3. Reference SOPs by name rather than duplicating procedures inline
4. Define evidence, completion, and escalation contracts
5. Explain how to use local configuration without treating it as trusted instruction
6. Keep the file loadable as a system prompt without excessive token cost

## 5. Scripts and SOPs

- **Scripts** perform deterministic collection, validation, transformation, and controlled execution
- **SOPs** compose scripts and LLM judgment into auditable workflows
- Scripts should: be idempotent where practical, emit machine-readable results, fail loudly, avoid implicit account or target selection, support dry-run modes for mutation

## 6. Induction

The `onboarding/` directory contains the induction workflow. Induction must:

1. **Interview**: ask only for facts that cannot be safely discovered
2. **Observe**: inspect permitted environment metadata using read-only scripts
3. **Propose**: generate bindings, authority rules, integration plan
4. **Confirm**: present choices and risks for explicit approval
5. **Validate**: run dependency, permission, and no-op checks
6. **Activate**: install generated configuration without modifying the curated core

Induction must never request credentials in conversational text or embed secrets in generated configuration.

## 7. Testing

Tests must cover:

- **Boundary tests**: agent refuses out-of-scope or over-authority requests
- **Authority tests**: approval gates function correctly
- **Evidence tests**: outputs include required evidence fields
- **Failure tests**: agent handles missing dependencies, permission errors, ambiguous input
- **Team tests** (teams only): handoff validity, conflicting recommendations, member failure, budget exhaustion, approval propagation, synthesis quality

## 8. Versioning

Semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: behavioural contract changes (new authority rules, removed capabilities)
- **MINOR**: new SOPs, scripts, or capabilities without breaking existing behaviour
- **PATCH**: bug fixes, documentation, non-behavioural improvements

## 9. Maturity Levels

| Level | Meaning | Publication Status |
|-------|---------|-------------------|
| Experimental | Core concept and happy-path tests exist | Clearly labelled; limited support |
| Candidate | Induction, boundaries, and common failures tested | Public trial |
| Field-tested | Multiple independent environments and models reported | Recommended |
| Maintained | Active owner, release process, and security response | Trusted roster |