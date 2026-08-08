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
# 1. Clone the package
git clone https://github.com/richarddun/privacy-champion
cd privacy-champion

# 2. Run induction (one-time setup — adapts to your machine)
#    Tell your agent: "Run start_taskrail induction"

# 3. Run the audit
#    Tell your agent: "Run start_taskrail privacy-audit"
```

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

## What It Audits

- **OS telemetry** — Diagnostic data, advertising ID, location services, activity history, typing data, error reporting, Cortana/Siri/Assistant
- **Browser telemetry** — Usage stats, crash reports, search suggestions, spell check, safe browsing, sync state, password manager telemetry
- **Network privacy** — DNS leakage, WebRTC IP leakage, mDNS
- **Common applications** — Known phone-home behavior in popular apps

## What It Doesn't Do (v0.1)

- Firewall configuration
- VPN setup
- Browser extension installation
- Corporate MDM/group policy management
- Mobile device auditing
- Network traffic analysis

## Safety

- **No changes without approval.** The agent proposes; you decide.
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
├── taskrails/
│   └── privacy-audit.taskrail.json     ← Core audit workflow (8 steps)
├── sops/
│   └── privacy-audit.sop.md            ← Execution methodology
├── scripts/
│   └── fingerprint.sh                  ← OS/browser detection
├── data/
│   └── surface-catalog.json            ← Known surfaces per platform (40+ entries)
├── onboarding/
│   └── induction.taskrail.json         ← One-time setup workflow (7 steps)
└── local/                              ← Generated during induction (gitignored)
    └── environment.yaml
```

## Requirements

- Any agent platform that supports skills + shell execution (Pi Coding Agent, Claude Code, Codex)
- bash 4.0+, curl or wget, jq
- Standard user access (admin/root recommended for full OS-level coverage)
- No network access required by the agent itself (surface catalog is local)

## License

MIT — see LICENSE file.