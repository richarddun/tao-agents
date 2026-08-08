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
├── tests/                    # Boundary, authority, and scenario tests
├── onboarding/               # Induction interview and readiness checks
└── .pi/
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
cd tao-agents/agents/<agent-name>
pi run induct
```

The induction workflow interviews you about your environment, observes what it can safely inspect, proposes bindings, and generates `local/` — without touching the curated core.

### Run a task

```bash
pi run task "Review the CloudFormation stack in us-east-1"
```

The agent will follow its SOPs: collect evidence → propose → stop at approval gates → execute through bounded wrappers → verify → report.

## Available Agents

| Agent | Type | Maturity | Description |
|-------|------|----------|-------------|
| *(coming soon)* | | | |

Team packages (lead specialist + bounded member agents with explicit handoff contracts) will appear alongside standalone agents.

## Philosophy

> Skills distribute knowledge. TAO distributes engineered colleagues: bounded, inspectable operational packages with curated SOPs, deterministic scripts, orchestration, adaptation workflows, and evidence-based verification.

- **Operational, not theatrical** — judged by repeatable behaviour, not impressive persona paragraphs
- **LLM inside the cockpit** — scripts establish facts; SOPs establish sequence; the LLM handles novelty
- **Authority is explicit** — you always know what an agent can and cannot do
- **Small roster, high trust** — five excellent operational units beat five thousand character cards

## Contributing

Agent and team packages follow the [TAO Package Specification](docs/package-spec.md). Proposals, field reports, and new agent submissions are welcome.

## License

MIT