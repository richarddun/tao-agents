---
name: privacy-champion
description: Audit and harden privacy surfaces on a personal computer. Fingerprints the OS and browsers, enumerates known telemetry and data-exfiltration channels, probes current state, classifies risk, presents findings for user approval, applies closures, verifies, and reports.
---

# Privacy Champion

## What it does

The Privacy Champion audits your computer for telemetry and data-exfiltration
surfaces — the ways your operating system and browsers share data about you.

It does NOT silently close everything. It fingerprints your system, shows you
exactly what's sharing data and with whom, classifies the risk, and asks for
your approval before changing anything. Every change is verified and documented
with rollback instructions.

## Quick Start

```bash
# 1. Clone the TAO repository
git clone https://github.com/richarddun/tao-agents.git
cd tao-agents

# 2. Run induction (one-time setup — adapts to your machine)
bash scripts/taskrail start --name induction \
    --taskrails-dir agents/privacy-champion/onboarding

# 3. Run the audit
bash scripts/taskrail start --name privacy-audit \
    --taskrails-dir agents/privacy-champion/taskrails
```

In a host that supports named taskrails natively (e.g. a Pi Coding Agent head
pointed at `agents/privacy-champion/`), you can start the `induction` and
`privacy-audit` rails directly, or ask the agent to "run the privacy audit".

## Supported Platforms

| OS | Versions | Browsers |
|----|----------|----------|
| Windows | 10, 11 | Chrome, Firefox, Edge, Brave |
| macOS | 13 (Ventura), 14 (Sonoma), 15 (Sequoia) | Chrome, Firefox, Safari, Edge, Brave |
| Linux | Ubuntu 22.04+, Fedora 39+, Debian 12+ | Chrome, Firefox, Edge, Brave |

Chromebooks, iOS, and Android are not supported in v0.1 (their telemetry
models differ significantly from desktop operating systems).

## How It Works

```
FINGERPRINT → ENUMERATE → PROBE → CLASSIFY → APPROVAL GATE → APPLY → VERIFY → REPORT
```

1. **Fingerprint** — Detects your OS, version, and installed browsers
2. **Enumerate** — Loads the surface catalog for your platform (40+ known surfaces)
3. **Probe** — Checks each surface's current state (enabled/disabled) — read-only
4. **Classify** — Rates each enabled surface by severity, reversibility, and user impact
5. **APPROVAL GATE** — Shows you exactly what will change and asks for approval. Nothing happens without it.
6. **Apply** — Executes closures for approved surfaces, logging every change
7. **Verify** — Re-probes every changed surface to confirm it's actually closed
8. **Report** — Produces a complete audit trail with before/after states and rollback instructions

Each step is a task in `taskrails/privacy-audit.taskrail.json`; the execution
methodology is in `sops/privacy-audit.sop.md`.

## What It Audits

- **OS telemetry** — Diagnostic data, advertising ID, location services, activity history, typing data, error reporting, Cortana/Siri/Assistant
- **Browser telemetry** — Usage stats, crash reports, search suggestions, spell check, safe browsing, sync state, password manager telemetry
- **Network privacy** — DNS leakage, WebRTC IP leakage, IPv6 privacy extensions
- **Common applications** — Known phone-home behavior in popular apps

Of the 40+ catalogued surfaces, the ones whose probes are real shell commands
are automated end to end; GUI and browser-preference surfaces are declared
`manual` in the catalog and are walked through by the agent with you. The
catalog tells you which is which (`probe_kind`).

## What It Doesn't Do (v0.1)

- Firewall configuration
- VPN setup
- Browser extension installation
- Corporate MDM/group policy management
- Mobile device auditing
- Network traffic analysis

## Safety

- **No changes without approval.** The agent proposes; you decide. The mutating
  script refuses to run unless invoked with both `--apply` and `--approved`.
- **Every change is logged** with before/after state and exact method used.
- **Every change is reversible.** Rollback instructions are included in the report.
- **No data leaves your machine.** The agent has no telemetry of its own.
- **No credentials requested.** Induction doesn't ask for passwords, tokens, or API keys.

## Package Structure

```
privacy-champion/
├── README.md                           ← You are here
├── SYSTEM.md                           ← Agent operating doctrine
├── agent.yaml                          ← TAO package manifest
├── CHANGELOG.md
├── LICENSE
├── taskrails/
│   └── privacy-audit.taskrail.json     ← Core audit workflow (8 steps)
├── sops/
│   └── privacy-audit.sop.md            ← Execution methodology
├── scripts/                            ← Deterministic tooling
│   ├── fingerprint.sh                  ← OS/browser/tool detection
│   ├── enumerate_surfaces.sh           ← Filter the surface catalog
│   ├── probe_surface.sh                ← Probe one surface (read-only)
│   ├── apply_closure.sh                ← Apply a pre-approved closure
│   └── verify_closure.sh               ← Re-probe after closure
├── data/
│   └── surface-catalog.json            ← Known surfaces per platform (40+)
├── tests/
│   ├── readiness-check.sh              ← Dependency / rail / permission checks
│   ├── boundary_test.sh                ← Out-of-scope refusals
│   ├── authority_test.sh               ← Approval-gate enforcement
│   ├── evidence_test.sh                ← Evidence contracts
│   ├── scenario_test.sh                ← Read-only end-to-end rehearsal
│   └── run_all.sh
├── onboarding/
│   ├── README.md
│   └── induction.taskrail.json         ← One-time setup workflow (7 steps)
├── .pi/                                ← Host integration (skills, prompts, workflows)
└── local/                              ← Generated during induction (gitignored)
    └── environment.yaml
```

## Requirements

- bash 4.0+
- python3 (used by the bundled scripts to read the catalog and taskrails)
- Any agent platform that supports skills + shell execution (Pi Coding Agent, Claude Code, Codex)
- Standard user access (admin/root recommended for full OS-level coverage)
- No network access required by the agent itself (surface catalog is local)

Run the test suite any time with:

```bash
bash tests/run_all.sh
```

## License

MIT — see LICENSE file.
