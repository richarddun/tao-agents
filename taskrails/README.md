# Taskrails

[Taskrails](https://richarddun.dev/writing/taskrails/) are progressive-disclosure
JSON workflows for TAO agents. Each `.taskrail.json` file defines a sequence of
tasks with embedded constraints and validation gates. Agents fetch one task at a
time using the `scripts/taskrail` CLI.

The repository-level rail here is a shared example; each package also ships its
own rails under its `taskrails/` and `onboarding/` directories.

## Format

```json
{
  "title": "Human-readable title",
  "description": "What this taskrail achieves",
  "rail": [
    {
      "task_id": 1,
      "task_name": "short_snake_case_name",
      "owner": "agent-slug",
      "constraints": [
        "- You MUST open the configuration file at /etc/example.conf",
        "- You SHOULD verify file permissions are 644"
      ],
      "validation": "Report the value and permissions before proceeding."
    }
  ]
}
```

`owner` is optional and only meaningful for team workflows; ordinary rails omit it.

## Conventions

- **Constraints** use RFC 2119 keywords: MUST, SHOULD, MAY
- **Validation** declares what "done" looks like — the evidence gate
- **task_id** is sequential starting at 1
- **task_name** is snake_case, used as a stable identifier

State files are auto-generated alongside the manifest with `_state.<iso8601>.json`
suffixes (gitignored). They carry environmental fingerprints for multi-agent
session disambiguation.

## Running a rail

The vendored CLI needs to be pointed at the rails directory:

```bash
# Repository-level rails
scripts/taskrail list
scripts/taskrail info new-agent-checklist
scripts/taskrail start --name new-agent-checklist

# A package's rails
scripts/taskrail list --taskrails-dir agents/system-sentinel/taskrails
scripts/taskrail start --name system-assessment \
    --taskrails-dir agents/system-sentinel/taskrails
```

## Available taskrails

### Repository-level

| Name | Title | Tasks | Description |
|------|-------|-------|-------------|
| `new-agent-checklist` | New Agent Checklist | 7 | Author a conformant TAO package end to end |

### Package rails

| Package | Rail | Tasks | Path |
|---------|------|-------|------|
| privacy-champion | `privacy-audit` | 8 | `agents/privacy-champion/taskrails/` |
| privacy-champion | `induction` | 7 | `agents/privacy-champion/onboarding/` |
| system-sentinel | `system-assessment` | 6 | `agents/system-sentinel/taskrails/` |
| system-sentinel | `induction` | 5 | `agents/system-sentinel/onboarding/` |
| workstation-hardening-team | `hardening-baseline` | 6 | `agents/workstation-hardening-team/taskrails/` |
