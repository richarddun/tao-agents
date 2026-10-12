# Workflows

The Privacy Champion does not ship a host-specific `.pi` workflow. Its
operating loop is expressed as a **taskrail** so that it is portable across
harnesses and enforces progressive disclosure (the agent sees one gated task
at a time rather than the whole plan).

| Workflow | Path | Tasks |
|----------|------|-------|
| Privacy audit | `taskrails/privacy-audit.taskrail.json` | 8 |
| Induction | `onboarding/induction.taskrail.json` | 7 |

Hosts should drive these rails with their taskrail runner and should look for
named rails in `.pi/taskrails/`, `taskrails/` and `onboarding/`. The repository
vendors a reference CLI at `scripts/taskrail`, which can be pointed at a
package's rails with `--taskrails-dir`:

```bash
bash scripts/taskrail list --taskrails-dir agents/privacy-champion/taskrails
bash scripts/taskrail start --name privacy-audit --taskrails-dir agents/privacy-champion/taskrails
bash scripts/taskrail start --name induction --taskrails-dir agents/privacy-champion/onboarding
```
