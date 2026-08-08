# Taskrails

Named taskrails — progressive-disclosure JSON workflows for TAO agents.

Each `.taskrail.json` file defines a sequence of tasks with embedded
constraints and validation gates. Agents fetch one task at a time via
the `scripts/taskrail` CLI.

## Format

```json
{
  "title": "Human-readable title",
  "description": "What this taskrail achieves",
  "rail": [
    {
      "task_id": 1,
      "task_name": "short_snake_case_name",
      "constraints": [
        "- You MUST open the configuration file at /etc/example.conf",
        "- You MUST locate the value of example_key",
        "- You SHOULD verify file permissions are 644"
      ],
      "validation": "Report the value and permissions before proceeding."
    }
  ]
}
```

## Conventions

- **Constraints** use RFC 2119 keywords: MUST, SHOULD, MAY
- **Validation** declares what "done" looks like — the evidence gate
- **task_id** is sequential starting at 1
- **task_name** is snake_case, used as a stable identifier

State files are auto-generated alongside the manifest with
`_state.<iso8601>.json` suffixes. They carry environmental fingerprints
for multi-agent session disambiguation.

## Available taskrails

| Name | Title | Tasks | Description |
|------|-------|-------|-------------|
| `sysadmin-health-check` | Sysadmin Health Check | 6 | Routine system health: caddy, disk, cron, heartbeat, memory, summary |