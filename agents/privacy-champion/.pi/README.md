# `.pi/` — Host integration surface

This directory is the conventional Pi Coding Agent integration point for a
TAO package. It is entirely optional for the audit itself — the package runs
from `SYSTEM.md`, `agent.yaml`, the taskrails and the `scripts/` — but it is
where a host may look for skills, prompts, workflows and extensions.

For the Privacy Champion the operating loop is a **taskrail**, not a `.pi`
workflow. The rails ship at the package root so any harness can find them:

| Rail | Path | Purpose |
|------|------|---------|
| Privacy audit | `taskrails/privacy-audit.taskrail.json` | 8-step audit loop |
| Induction | `onboarding/induction.taskrail.json` | 7-step onboarding |

Hosts that follow the TAO convention should search a package's
`.pi/taskrails/`, `taskrails/` and `onboarding/` directories for named rails.

## Contents

| Path | Purpose |
|------|---------|
| `skills/privacy-audit/SKILL.md` | How and when to invoke the audit |
| `prompts/approval-gate.md` | The reusable approval-gate presentation prompt |
| `workflows/README.md` | Why the loop is a taskrail, not a host workflow |
| `extensions/README.md` | Extension posture (none required) |
