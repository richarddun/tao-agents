#!/usr/bin/env bash
# ── Workstation Hardening Team: Orchestration Test ────────────────────
# Validates the team manifest: members exist as real packages, the lead
# is real, every workflow step names a valid owner, budgets are sane, and
# the shared-state and result-contract schemas parse.
#
# Run: ./run_all.sh
# Exit: 0 all pass, 1 failures.

set -uo pipefail
PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$PKG_DIR/../.." && pwd)"
AGENTS_DIR="$REPO_ROOT/agents"

python3 - "$PKG_DIR" "$AGENTS_DIR" <<'PY'
import json, sys, os
from pathlib import Path

pkg = Path(sys.argv[1]); agents = Path(sys.argv[2])
try:
    import yaml
except ImportError:
    print("PyYAML required"); sys.exit(3)

runs = fails = 0
def check(name, ok, detail=""):
    global runs, fails
    runs += 1
    if ok:
        print(f"  \033[32m✓\033[0m {name}")
    else:
        fails += 1
        print(f"  \033[31m✗\033[0m {name}" + (f"\n      {detail}" if detail else ""))

manifest = yaml.safe_load((pkg / "team.yaml").read_text())
check("team.yaml parses with a top-level 'team:'", "team" in manifest)
team = manifest.get("team", {})

# Package discovery
def has_manifest(name):
    p = agents / name
    return (p / "agent.yaml").is_file() or (p / "team.yaml").is_file()

lead = team.get("lead")
check("lead is declared", bool(lead), f"lead={lead!r}")
check("lead is a real package", bool(lead) and has_manifest(lead), f"lead={lead!r}")

members = team.get("members") or []
names = [m.get("name") for m in members if isinstance(m, dict)]
check("members declared", len(members) >= 1)
for n in names:
    check(f"member '{n}' is a real package", bool(n) and has_manifest(n))

orch = team.get("orchestration") or {}
budgets = orch.get("budgets") or {}
check("orchestration.workflow declared", bool(orch.get("workflow")))
wf = pkg / (orch.get("workflow") or "")
check("workflow file exists", wf.is_file(), str(wf))
check("shared_state schema exists", (pkg / (orch.get("shared_state") or "")).is_file())
check("result_contract exists", (pkg / (team.get("result_contract") or "")).is_file())

allowed = set(names) | ({lead} if lead else set())
if wf.is_file():
    rail = json.loads(wf.read_text())
    tasks = rail.get("rail", [])
    check("workflow has tasks", len(tasks) >= 1)
    for t in tasks:
        owner = t.get("owner")
        check(f"task {t.get('task_id')} owner '{owner}' is a member", owner in allowed,
              f"allowed={sorted(allowed)}")
        check(f"task {t.get('task_id')} has constraints and validation",
              bool(t.get("constraints")) and bool(t.get("validation")))

for b in ("max_agents", "max_parallel", "max_iterations"):
    check(f"budget '{b}' declared", b in budgets)
if budgets.get("max_agents"):
    check("max_agents covers members", budgets["max_agents"] >= len(members),
          f"max_agents={budgets['max_agents']} members={len(members)}")

# Schemas parse
for rel in [orch.get("shared_state"), team.get("result_contract")]:
    if rel:
        try:
            json.loads((pkg / rel).read_text())
            check(f"schema parses: {rel}", True)
        except Exception as e:  # noqa: BLE001
            check(f"schema parses: {rel}", False, str(e))

# Authority presence
auth = team.get("authority") or {}
check("aggregate authority declared", auth.get("aggregate") == "least_privilege_intersection")
check("mutation is approval-gated", "explicit_approval" in str(auth.get("mutate", "")))

print(f"\nOrchestration test: {runs} run, {fails} failed")
sys.exit(1 if fails else 0)
PY
