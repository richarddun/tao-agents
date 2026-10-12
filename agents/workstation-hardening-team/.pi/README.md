# `.pi/` — Host integration surface

The Workstation Hardening Team adds no host extensions. Its orchestration is a
taskrail that sequences the two member packages.

| Rail | Path | Tasks |
|------|------|-------|
| Hardening baseline | `taskrails/hardening-baseline.taskrail.json` | 6 |

Each workflow task names its `owner` (a member slug). A host that composes
teams should:

1. Load `team.yaml` for the member roster and budgets.
2. Drive `taskrails/hardening-baseline.taskrail.json` one task at a time.
3. Route each task to the member named in `owner`.

```bash
scripts/taskrail info --taskrails-dir agents/workstation-hardening-team/taskrails hardening-baseline
```

Member packages are at `agents/system-sentinel/` and `agents/privacy-champion/`.
