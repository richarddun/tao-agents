---
name: system-sentinel
description: Read-only inventory and posture assessment of a personal workstation — storage, memory, exposure, patching, accounts. Produces an evidence-backed report with per-area risk ratings. Makes no changes.
---

# System Sentinel

## What it does

The System Sentinel tells you what a machine currently looks like and what is
worth your attention. It collects a read-only inventory of OS, storage, memory,
listening services, firewall, disk encryption, pending updates and privileged
accounts, then rates the posture area by area with the evidence behind every
finding.

It does **not** change anything. It has no mutation capability by design: the
output is an assessment plus recommendations that you own.

## Quick Start

```bash
# 1. Clone the TAO repository
git clone https://github.com/richarddun/tao-agents.git
cd tao-agents

# 2. Collect an inventory directly
bash agents/system-sentinel/scripts/inventory.sh --pretty

# 3. Run the assessment workflow
scripts/taskrail start --name system-assessment \
    --taskrails-dir agents/system-sentinel/taskrails
```

## Supported Platforms

| OS | Versions |
|----|----------|
| Linux | Ubuntu 22.04+, Debian 12+, Fedora 39+ |
| macOS | 13 (Ventura), 14 (Sonoma), 15 (Sequoia) |

Administrator access is not required, but some fields report `unknown` without it.

## How It Works

```
INVENTORY → STORAGE → MEMORY/LOAD → EXPOSURE → PATCHING → SUMMARY
```

| Area | What is checked |
|------|-----------------|
| Storage | Filesystem usage, free space, disk encryption |
| Memory & load | RAM, swap, load average vs CPU count |
| Exposure | Listening sockets by interface, firewall status |
| Patching | Pending package/OS updates |
| Accounts | Users with privileged group membership |
| System | OS/kernel version, uptime, privilege level |

## Safety

- **Read-only.** The single collection script performs no mutation.
- **Evidence-cited.** Every finding names the inventory field it came from.
- **Honest about gaps.** Uncollected fields are reported as `unknown` with the
  reason, never guessed.
- **No transmission.** The inventory never leaves your machine.

## Package Structure

```
system-sentinel/
├── README.md
├── SYSTEM.md
├── agent.yaml
├── CHANGELOG.md
├── LICENSE
├── taskrails/
│   └── system-assessment.taskrail.json  ← Assessment workflow (6 steps)
├── sops/
│   └── system-assessment.sop.md         ← Thresholds and methodology
├── scripts/
│   └── inventory.sh                     ← Read-only inventory
├── schemas/
│   └── posture-report.json              ← Result contract
├── tests/                               ← Readiness, boundary, evidence, scenario
├── onboarding/
│   ├── README.md
│   └── induction.taskrail.json          ← One-time setup (5 steps)
├── .pi/                                 ← Host integration surface
└── local/                               ← Generated during induction (gitignored)
    └── environment.yaml
```

## Requirements

- bash 4.0+
- python3 (JSON assembly)
- Coreutils (`df`, `uptime`, `uname`)
- Any agent platform that supports skills + shell execution

Run the tests any time with:

```bash
bash tests/run_all.sh
```

## License

MIT — see LICENSE file.
