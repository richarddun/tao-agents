# Scripts

Deterministic, auditable tooling for TAO agents and teams.

## `taskrail`

The **taskrail** CLI is the canonical workflow runner for TAO. It implements
progressive-disclosure JSON workflows — agents fetch one task at a time with
embedded constraints and validation gates, never seeing the full plan upfront.

### Quick start

```bash
# List available taskrails
./scripts/taskrail list

# Inspect a taskrail
./scripts/taskrail info sysadmin-health-check

# Run through a taskrail (agent drives this)
./scripts/taskrail start --name sysadmin-health-check
# ... agent completes task, validates, then:
./scripts/taskrail next
# ... repeat until "All tasks complete"

# Resume after interruption (fingerprint-matched to the right session)
./scripts/taskrail resume --name sysadmin-health-check
```

### Subcommands

| Command | Purpose |
|---------|---------|
| `list` | List available named taskrails |
| `info <name>` | Show taskrail details (title, description, step count) |
| `start --name <n>` | Begin a named taskrail; returns task 1 |
| `start --self --self-path <p>` | Begin an agent's own taskrail |
| `next` | Mark current task complete, return next task |
| `resume --name <n>` | Resume an interrupted session (best-match fingerprint) |
| `status` | Show the active taskrail and progress |
| `sessions <name>` | List all sessions for a taskrail with match scores |

### Multi-agent safety

State files are timestamped and carry an environmental fingerprint
(cwd, hostname, user, env-hash, syslog birth certificate). On `resume`,
the CLI scores all candidate sessions against the current environment
and picks the best match automatically.

If multiple agents run from the same directory and the matcher
can't disambiguate, it lists candidates; the agent picks one with
`--session <n>`.

### File locations

| Resource | Path |
|----------|------|
| Named taskrails | `<repo-root>/taskrails/*.taskrail.json` |
| State files | `<repo-root>/taskrails/<manifest>_state.<iso8601>.json` |
| Active rail | `~/.taskrail/active.json` |
| Self taskrails | Any path (passed via `--self-path`) |

### Zero dependencies

The CLI is a single Python 3.8+ file with no external dependencies.
It can be vendored into any agent ecosystem — copy `scripts/taskrail`
and it works.

### Taskrail format

See `taskrails/` for examples. Each `.taskrail.json` file contains:

```json
{
  "title": "Human-readable title",
  "description": "What this taskrail achieves",
  "rail": [
    {
      "task_id": 1,
      "task_name": "short_name",
      "constraints": ["- You MUST ...", "- You SHOULD ..."],
      "validation": "Report evidence of completion before proceeding."
    }
  ]
}
```

### Integration with TAO agents

TAO agents use taskrails for:

- **SOPs**: Each standard operating procedure is a named taskrail
- **Induction**: The onboarding interview is driven by a taskrail
- **Operating loop**: An agent's core decision loop is its self-taskrail
- **Team orchestration**: The primary specialist sequences member agents via taskrails

Agents invoke the CLI via shell (e.g., `bash scripts/taskrail next`). The
progressive-disclosure design prevents pre-completion and keeps agent context
fresh — the agent only ever sees one task at a time.