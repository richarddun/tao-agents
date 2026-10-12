# TAO Package Specification v0.1

## 1. Overview

A TAO package is a versioned directory containing a complete, portable,
operational AI agent or agent team. The package separates the **curated
operational core** (maintained by the TAO project) from the **local adaptation
layer** (generated during user induction).

Packages live in the TAO monorepo under `agents/<name>/`. A package is
self-contained: everything it needs to run is inside its directory.

## 2. Repository layout

```
tao-agents/
├── agents/
│   ├── <agent-name>/          # one directory per package (agent or team)
│   │   ├── README.md
│   │   ├── SYSTEM.md
│   │   ├── agent.yaml | team.yaml
│   │   ├── CHANGELOG.md
│   │   ├── LICENSE
│   │   ├── sops/
│   │   ├── scripts/
│   │   ├── tests/
│   │   ├── taskrails/
│   │   ├── onboarding/
│   │   └── .pi/
│   │       ├── skills/
│   │       ├── prompts/
│   │       ├── workflows/
│   │       └── extensions/
│   └── ...
├── docs/                      # this specification and other design docs
├── scripts/                   # shared tooling (e.g. the taskrail CLI)
├── taskrails/                 # repository-level taskrails
├── tests/                     # repository-level conformance tests
└── tao.json                   # generated registry index (see §10)
```

### Required files in a package

| File | Required | Description |
|------|----------|-------------|
| `README.md` | Yes | Human-readable overview, install instructions, task examples |
| `SYSTEM.md` | Yes | Agent or team operating doctrine — the system prompt |
| `agent.yaml` / `team.yaml` | Yes | Machine-readable manifest (see §3) |
| `CHANGELOG.md` | Yes | Version history and behavioural changes |
| `LICENSE` | Yes | Distribution license |
| `sops/` | Yes | Standard operating procedures (markdown, one per procedure) |
| `scripts/` | Conditional | Deterministic scripts, if the agent uses any |
| `tests/` | Yes | Boundary, authority, evidence, and scenario tests |
| `taskrails/` | Conditional | Operating-loop workflows, if the package has any |
| `onboarding/` | Yes | Induction workflow and readiness checks |
| `.pi/` | Yes | Host integration surface (skills, prompts, workflows, extensions) |

## 3. Manifest schema

A package manifest is a single YAML file: `agent.yaml` for a standalone agent,
`team.yaml` for a team. Both use a single top-level key (`agent:` or `team:`)
whose value is the manifest body. Tooling must ignore unknown keys so that
manifests can evolve without breaking older consumers.

The reference implementation is [`agents/privacy-champion/agent.yaml`](../agents/privacy-champion/agent.yaml).

### 3.1 `agent.yaml`

```yaml
agent:
  # Identity
  name: <slug>                 # machine-readable slug
  title: <string>              # human-readable name
  slug: <slug>                 # usually equal to name
  version: <semver>
  maturity: <level>            # experimental | candidate | field-tested | maintained
  type: agent                  # agent | team
  purpose: <prose>             # 1-5 sentence mission statement
  good_fit: [<string>]         # example situations the agent suits
  poor_fit: [<string>]         # situations where it should not be used

  # Authority — each value is automatic | explicit_approval* | prohibited*
  authority:
    read: <level>
    propose: <level>
    mutate_<surface>: <level>  # one key per mutable surface class
    destructive: <level>
    escalation: <policy>       # e.g. halt_and_report
  authority_rationale: <prose>

  # Inputs / outputs
  inputs: [<string>]           # required context, privileges, access
  outputs: [<string>]          # evidence and result artefacts

  # State & memory
  state:
    fields: [<string>]
    retention: <prose>
    sharing: <prose>           # what crosses boundaries; default: nothing

  # Operating model
  operating_loop: <path>       # path to the core taskrail
  core_sop: <path>             # path to the primary SOP
  taskrails: [<path>]
  scripts: [<path>]
  tests: [<path>]
  knowledge_base: [<path>]

  # Recovery
  recovery:
    - <trigger>: <action>

  # Local adaptation layer (generated during induction; gitignored)
  local_adapter:
    format: <prose>
    path: <path>
    generated_by: <path>
    gitignored: <bool>
    contents: [<string>]

  # Compatibility
  compatibility:
    platforms:
      - os: <name>
        versions: [<string>]
        browsers: [<string>]   # optional, for browser-touching agents
    runtimes: [<string>]
    minimum_privileges: <prose>
    dependencies: [<string>]

  # Lifecycle
  lifecycle:
    install: <prose>
    induct: <path>
    validate: <path>
    test: <path>
    upgrade: <prose>
    rollback: <prose>
    uninstall: <prose>

  # Telemetry (opt-in, of the agent itself)
  telemetry:
    opt_in_only: <bool>
    collected_when_enabled: [<string>]
    never_collected: [<string>]

  # Provenance
  maintainer: <string>
  license: <spdx>
  repository: <url>
  feedback: <prose>
```

### 3.2 `team.yaml`

A team manifest uses the same identity, authority, lifecycle and provenance
sections as §3.1, plus the composition section below.

```yaml
team:
  name: <slug>
  title: <string>              # human-readable name
  slug: <slug>
  version: <semver>
  maturity: <level>
  type: team
  objective: <prose>           # the goal the team is built to achieve
  lead: <agent-slug>           # primary specialist; owns synthesis + final result

  members:
    - name: <agent-slug>
      role: <prose>
      triggers: [<string>]     # when this member is invoked
      authority_ceiling: <level>
      inputs: [<string>]
      outputs: [<string>]

  orchestration:
    workflow: <path>           # entrypoint workflow / taskrail
    shared_state: <path>       # schema for shared state
    budgets:
      max_agents: <int>
      max_parallel: <int>
      max_iterations: <int>
    failure_policy: <policy>   # halt | retry | escalate | degrade

  authority:
    aggregate: <policy>        # e.g. least_privilege_intersection
    destructive: <level>

  result_contract: <path>      # schema for the final deliverable

  # identity / lifecycle / maintainer / license / repository as in §3.1
```

**Composition rules.** A member must be a real, independently bounded agent.
The lead owns intake, decomposition, routing, synthesis, approval gates and
final accountability. Members receive minimum task-relevant context. Only the
lead may declare the objective complete, and only after team-level verification
passes.

## 4. Operating doctrine (SYSTEM.md)

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
- Scripts should: be idempotent where practical, emit machine-readable results (JSON), fail loudly, avoid implicit account or target selection, and support dry-run modes for mutation
- Only scripts that mutate should run mutating commands; every mutating script must document and enforce its approval gate

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

A package should provide `tests/run_all.sh` to run its suite. Repository-level
conformance tests (see §10) validate package layout and manifests across the
roster.

## 8. Versioning

Semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: behavioural contract changes (new authority rules, removed capabilities)
- **MINOR**: new SOPs, scripts, or capabilities without breaking existing behaviour
- **PATCH**: bug fixes, documentation, non-behavioural improvements

## 9. Maturity levels

| Level | Meaning | Publication status |
|-------|---------|-------------------|
| Experimental | Core concept and happy-path tests exist | Clearly labelled; limited support |
| Candidate | Induction, boundaries, and common failures tested | Public trial |
| Field-tested | Multiple independent environments and models reported | Recommended |
| Maintained | Active owner, release process, and security response | Trusted roster |

## 10. Registry index (`tao.json`)

`tao.json` is a generated, flat index of the roster, intended for consumers
that want to list or fetch packages without walking the repository tree.

```json
{
  "schema": "tao/registry-index/1",
  "generated": "<iso8601>",
  "count": <int>,
  "agents": [
    {
      "name": "<slug>",
      "title": "<human name>",
      "type": "agent | team",
      "version": "<semver>",
      "maturity": "<level>",
      "description": "<one line>",
      "path": "agents/<name>",
      "sha256": "<tree hash of the curated core>"
    }
  ]
}
```

Generate it with `python3 scripts/build_index.py` (from the repository root).
The index is committed so that consumers can pin to a known revision. The
`sha256` is a deterministic hash over the package's curated files (excluding
`local/`, `backups/` and log/state files).
