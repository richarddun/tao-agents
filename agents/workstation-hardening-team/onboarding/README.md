# Onboarding — team induction

A team is inducted **per member first**, then validated as a team. There is no
single team-level interview: each member's own induction resolves the
environment facts it needs, and the team manifest is then checked for
consistency.

## Steps

1. **Induct the lead** — run `system-sentinel`'s induction:
   ```bash
   scripts/taskrail start --name induction \
       --taskrails-dir agents/system-sentinel/onboarding
   ```
2. **Induct the telemetry member** — run `privacy-champion`'s induction:
   ```bash
   scripts/taskrail start --name induction \
       --taskrails-dir agents/privacy-champion/onboarding
   ```
3. **Resolve team bindings** — confirm member availability, tool
   compatibility, concurrency and budget limits, routing, and the human
   approval owner. Record them locally.
4. **Validate the team** — run the orchestration test:
   ```bash
   bash agents/workstation-hardening-team/tests/run_all.sh
   ```
5. **Partial availability** — if a member cannot be inducted, the team runs in
   the `DEGRADED` mode declared in `team.yaml`, or refuses readiness. It never
   silently proceeds without a required member.

## What team induction does not do

- It does not grant any member authority it does not already have.
- It does not ask for credentials.
- It does not modify any member's curated core.
