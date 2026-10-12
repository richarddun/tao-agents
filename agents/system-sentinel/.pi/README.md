# `.pi/` — Host integration surface

The System Sentinel needs no host extensions. Its capability comes from the
read-only `scripts/inventory.sh` and the `system-assessment` taskrail.

| Rail | Path | Tasks |
|------|------|-------|
| System assessment | `taskrails/system-assessment.taskrail.json` | 6 |
| Induction | `onboarding/induction.taskrail.json` | 5 |

Hosts that follow the TAO convention should search a package's
`.pi/taskrails/`, `taskrails/` and `onboarding/` directories for named rails.
The repository vendors a reference CLI at `scripts/taskrail`; point it at this
package with `--taskrails-dir`:

```bash
scripts/taskrail start --name system-assessment \
    --taskrails-dir agents/system-sentinel/taskrails
```

The result contract is `schemas/posture-report.json`.
