#!/usr/bin/env bash
# ── Privacy Champion: Readiness Check ─────────────────────────────────
# Validates that the environment can run the privacy audit: required
# tools, executable scripts, parseable catalog and taskrails, a writable
# workspace, and a read-only smoke probe.
#
# Referenced by agent.yaml lifecycle.validate.
#
# Usage: ./readiness-check.sh [--workspace <dir>] [--json]
# Exit: 0 PASS, 1 PARTIAL (audit can proceed with limitations), 2 FAIL.

set -uo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$PKG_DIR/scripts"
CATALOG="$PKG_DIR/data/surface-catalog.json"
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

[ "$JSON_ONLY" = "0" ] && printf '\nPrivacy Champion — readiness check\n\n'

# checks are accumulated as: status<TAB>name<TAB>detail
CHECKS=""
add() { CHECKS="${CHECKS}$1	$2	$3
"; }

# 1. Required tools.
for tool in bash python3; do
    if command -v "$tool" >/dev/null 2>&1; then
        add PASS "tool:$tool" "$(command -v "$tool")"
    else
        add FAIL "tool:$tool" "required tool missing"
    fi
done
for tool in jq curl wget; do
    if command -v "$tool" >/dev/null 2>&1; then
        add PASS "tool:$tool" "$(command -v "$tool")"
    else
        add WARN "tool:$tool" "optional tool missing (some manual probes unavailable)"
    fi
done

# 2. Catalog parses and is non-empty.
if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("platforms")' "$CATALOG" 2>/dev/null; then
    n="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1]));
c=0
for p in d["platforms"].values():
    for v in p["surfaces"].values():
        if isinstance(v,list): c+=len(v)
        elif isinstance(v,dict):
            for k,a in v.items():
                if not k.startswith("_") and isinstance(a,list): c+=len(a)
print(c)' "$CATALOG")"
    add PASS "catalog" "$n surfaces"
else
    add FAIL "catalog" "surface-catalog.json missing or unparseable"
fi

# 3. Taskrails parse.
for rail in "$PKG_DIR/taskrails/privacy-audit.taskrail.json" "$PKG_DIR/onboarding/induction.taskrail.json"; do
    name="taskrail:$(basename "$rail")"
    if [ -r "$rail" ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("rail")' "$rail" 2>/dev/null; then
        n="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["rail"]))' "$rail")"
        add PASS "$name" "$n tasks"
    else
        add FAIL "$name" "missing or unparseable"
    fi
done

# 4. Scripts executable.
for f in "$SCRIPTS_DIR"/*.sh; do
    [ -e "$f" ] || continue
    if [ -x "$f" ]; then add PASS "exec:$(basename "$f")" ""; else add FAIL "exec:$(basename "$f")" "not executable"; fi
done

# 5. Workspace writable.
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

# 6. Read-only smoke probe.
smoke="$(bash "$SCRIPTS_DIR/probe_surface.sh" --surface-id linux-apport-error 2>/dev/null || true)"
sstate="$(printf '%s' "$smoke" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("state",""))
except Exception: print("")' 2>/dev/null)"
if [ -n "$sstate" ]; then
    add PASS "smoke-probe" "probe returned state=$sstate"
else
    add WARN "smoke-probe" "smoke probe did not return a state"
fi

# ── Aggregate ─────────────────────────────────────────────────────────
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
