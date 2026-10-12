# TAO — The Agent Observatory

Curated, portable, operational AI agents and agent teams.
Inspect the dossier. Understand the authority boundaries. Take one home.

**🌐 [richarddun.dev/tao](https://richarddun.dev/tao)**

---

## What is TAO?

TAO is a registry and deployment system for complete operational agents — not skills, not prompts, not character cards, but **engineered colleagues** with:

- **Bounded authority**: read, propose, mutate, and destroy are distinct capabilities
- **Deterministic scripts**: facts come from tools, not the model's imagination
- **Standard operating procedures**: composed of scripts + LLM judgment with explicit gates
- **Evidence-based verification**: completion requires proof, not self-assertion
- **Portable by design**: the curated operational core is immutable; local adaptation is generated during induction

Each agent and team ships as a versioned package with SYSTEM.md, agent.yaml/team.yaml, SOPs, scripts, tests, onboarding, and induction tooling.

## Two-Layer Portability

| Layer | Owner | Contains | Mutation Policy |
|-------|-------|----------|-----------------|
| **Curated core** | TAO maintainer | SYSTEM.md, SOPs, skills, scripts, tests, manifest | Versioned; users do not edit |
| **Local adaptation** | Enrolling user | Accounts, regions, paths, tools, approvals | Generated during induction; user-owned |

The invariant: local adaptation may tighten authority or replace environment bindings, but must never silently weaken safety constraints or verification requirements.

## Repository Layout

```
tao-agents/
├── agents/                    # one directory per package
│   ├── privacy-champion/      # standalone agent
│   ├── system-sentinel/       # standalone agent
│   └── workstation-hardening-team/  # example team (non-deploying)
├── docs/package-spec.md       # the TAO package specification
├── scripts/                   # shared tooling (taskrail CLI, index builder)
├── taskrails/                 # repository-level taskrails
├── tests/                     # repository conformance tests
└── tao.json                   # generated registry index
```

## Package Structure

```
agent-name/
├── README.md
├── SYSTEM.md                 # Operating doctrine
├── agent.yaml                # Manifest: identity, authority, I/O, state, lifecycle
├── CHANGELOG.md
├── LICENSE
├── sops/                     # Standard operating procedures
├── scripts/                  # Deterministic tooling
├── tests/                    # Boundary, authority, evidence, scenario tests
├── taskrails/                # Operating-loop workflows
├── onboarding/               # Induction workflow and readiness checks
└── .pi/                      # Host integration surface
    ├── skills/
    ├── prompts/
    ├── workflows/
    └── extensions/

local/                        # Generated during induction (gitignored)
├── environment.yaml
├── authority.yaml
├── integrations.yaml
└── memory.yaml
```

## Getting Started

### Install an agent

```bash
git clone https://github.com/richarddun/tao-agents.git
cd tao-agents

# Induct the agent (one-time; adapts it to your machine)
scripts/taskrail start --name induction \
    --taskrails-dir agents/privacy-champion/onboarding
```

The induction workflow interviews you about your environment, observes what it can safely inspect, proposes bindings, and generates `local/` — without touching the curated core.

### Run a task

```bash
# Drive the agent's operating loop
scripts/taskrail start --name privacy-audit \
    --taskrails-dir agents/privacy-champion/taskrails
```

The agent follows its SOPs: collect evidence → propose → stop at approval gates → execute through bounded wrappers → verify → report.

> In a host that supports named taskrails natively (e.g. a Pi Coding Agent head
> pointed at a package directory), you can start these rails directly. The
> `scripts/taskrail` CLI is the zero-dependency reference runner.

## Available Agents

| Agent | Type | Maturity | Description |
|-------|------|----------|-------------|
| [**Privacy Champion**](agents/privacy-champion/) | Standalone | Experimental | Audit and harden telemetry surfaces across OS, browsers, and network. 8-step guided audit with per-surface approval gates. |
| [**System Sentinel**](agents/system-sentinel/) | Standalone | Experimental | Read-only inventory and posture assessment of a workstation: storage, memory, exposure, patching, accounts. |

## Teams

| Team | Type | Maturity | Description |
|------|------|----------|-------------|
| [**Workstation Hardening Team**](agents/workstation-hardening-team/) | Team (non-deploying example) | Experimental | Composes System Sentinel (lead) with Privacy Champion (telemetry) around one objective: harden a workstation and produce a single evidence-backed report. |

## Registry Index

`tao.json` is a generated, flat index of the roster for consumers that want to
list, fetch and pin packages without walking the tree. It records the
`repository` and the `revision` it describes, so an entry is fetchable on its
own:

```
fetch   = <repository>/archive/<revision>.tar.gz    # immutable, no auth, no git
unpack  = that tarball's <path>
verify  = tree hash of the package == entry.sha256
```

```bash
python3 scripts/build_index.py            # regenerate after adding a package
python3 scripts/build_index.py --check     # verify it is current
```

Teams declare `requires` (their lead + members), so a consumer can install the
closure. See [docs/package-spec.md §10](docs/package-spec.md) for the full
contract — including why the hash covers *content*, not tarball bytes.

## Conformance

Repository-wide checks validate package layout, manifests, cross-package
references (team members/leads) and index freshness:

```bash
bash tests/run_all.sh
```

## Philosophy

> Skills distribute knowledge. TAO distributes engineered colleagues: bounded, inspectable operational packages with curated SOPs, deterministic scripts, orchestration, adaptation workflows, and evidence-based verification.

- **Operational, not theatrical** — judged by repeatable behaviour, not impressive persona paragraphs
- **LLM inside the cockpit** — scripts establish facts; SOPs establish sequence; the LLM handles novelty
- **Authority is explicit** — you always know what an agent can and cannot do
- **Small roster, high trust** — five excellent operational units beat five thousand character cards

## Contributing

Agent and team packages follow the [TAO Package Specification](docs/package-spec.md). The
repository-level [`new-agent-checklist`](taskrails/new-agent-checklist.taskrail.json)
taskrail walks through authoring a conformant package end to end. Proposals,
field reports, and new agent submissions are welcome.

```bash
scripts/taskrail start --name new-agent-checklist
```

## License

MIT
