#!/usr/bin/env bash
# ── System Sentinel: Readiness Check ──────────────────────────────────
# Validates that the environment can run an assessment: tools, script
# permissions, taskrail/schema parsing, a writable workspace and a
# read-only collection smoke test.
#
# Referenced by agent.yaml lifecycle.validate.
# Usage: ./readiness-check.sh [--workspace <dir>] [--json]
# Exit: 0 PASS, 1 PARTIAL, 2 FAIL.

set -uo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$PKG_DIR/scripts"
RAILS_DIR="$PKG_DIR/taskrails"
SCHEMA="$PKG_DIR/schemas/posture-report.json"
WORKSPACE="$PKG_DIR/local"
JSON_ONLY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --workspace) WORKSPACE="${2:-}"; shift 2 ;;
        --json)      JSON_ONLY=1; shift ;;
        -h|--help)   sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

CHECKS=""
add() { CHECKS="${CHECKS}$1	$2	$3
"; }

for tool in bash python3 df uptime uname; do
    if command -v "$tool" >/dev/null 2>&1; then
        add PASS "tool:$tool" "$(command -v "$tool")"
    else
        add FAIL "tool:$tool" "required tool missing"
    fi
done

if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("rail")' "$RAILS_DIR/system-assessment.taskrail.json" 2>/dev/null; then
    n="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["rail"]))' "$RAILS_DIR/system-assessment.taskrail.json")"
    add PASS "taskrail:system-assessment" "$n tasks"
else
    add FAIL "taskrail:system-assessment" "missing or unparseable"
fi

if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("properties") or d.get("type")' "$SCHEMA" 2>/dev/null; then
    add PASS "schema:posture-report" "parses"
else
    add WARN "schema:posture-report" "missing or unparseable"
fi

for f in "$SCRIPTS_DIR"/*.sh; do
    [ -e "$f" ] || continue
    if [ -x "$f" ]; then add PASS "exec:$(basename "$f")" ""; else add FAIL "exec:$(basename "$f")" "not executable"; fi
done

if [ -d "$WORKSPACE" ] || mkdir -p "$WORKSPACE" 2>/dev/null; then
    if touch "$WORKSPACE/.readiness-probe" 2>/dev/null; then
        rm -f "$WORKSPACE/.readiness-probe"
        add PASS "workspace" "$WORKSPACE writable"
    else
        add FAIL "workspace" "$WORKSPACE not writable"
    fi
else
    add FAIL "workspace" "cannot create $WORKSPACE"
fi

inv="$(bash "$SCRIPTS_DIR/inventory.sh" 2>/dev/null || true)"
if [ -n "$inv" ] && printf '%s' "$inv" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["fields"]["os_family"]' 2>/dev/null; then
    add PASS "smoke-collect" "inventory returned os_family"
else
    add WARN "smoke-collect" "inventory did not return usable output"
fi

fails="$(printf '%s' "$CHECKS" | awk -F'\t' '$1=="FAIL"{c++} END{print c+0}')"
warns="$(printf '%s' "$CHECKS" | awk -F'\t' '$1=="WARN"{c++} END{print c+0}')"
if [ "$fails" -gt 0 ]; then status="FAIL"; code=2
elif [ "$warns" -gt 0 ]; then status="PARTIAL"; code=1
else status="PASS"; code=0; fi

python3 - "$status" "$CHECKS" <<'PY'
import json, sys
status, raw = sys.argv[1], sys.argv[2]
checks = []
for line in raw.splitlines():
    if not line.strip():
        continue
    parts = line.split("\t")
    checks.append({"status": parts[0], "name": parts[1], "detail": parts[2] if len(parts) > 2 else ""})
print(json.dumps({"status": status, "checks": checks}, indent=2))
PY

if [ "$JSON_ONLY" = "0" ]; then
    echo
    printf '%s' "$CHECKS" | awk -F'\t' '{printf "  %-5s %-28s %s\n", $1, $2, $3}'
    printf '\nreadiness: %s\n' "$status"
fi

exit "$code"
