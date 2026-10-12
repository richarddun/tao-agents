#!/usr/bin/env bash
# ── Privacy Champion: Verify Closure ──────────────────────────────────
# Re-probes one or more surfaces after a closure and reports whether the
# new state matches the expected state. READ-ONLY.
#
# Usage:
#   ./verify_closure.sh --surface-id <id> [--expect DISABLED] [--os <f>]
#   ./verify_closure.sh --log <change-log.jsonl> [--expect DISABLED]
#
# Options:
#   --surface-id <id>  verify a single surface
#   --log <jsonl>      verify every surface referenced in a change log
#                      (latest entry per surface wins)
#   --expect <state>   expected state after closure (default DISABLED)
#   --os <family>      windows | macos | linux (default auto-detect)
#   --catalog <p>      path to surface-catalog.json
#
# Output: JSON to stdout.
# Exit: 0 all verified, 2 usage error, 7 one or more failed to verify.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="${TAO_SURFACE_CATALOG:-$PKG_DIR/data/surface-catalog.json}"

SURFACE_ID=""
LOG=""
EXPECT="DISABLED"
OS_FAMILY=""

while [ $# -gt 0 ]; do
    case "$1" in
        --surface-id) SURFACE_ID="${2:-}"; shift 2 ;;
        --log)        LOG="${2:-}"; shift 2 ;;
        --expect)     EXPECT="${2:-DISABLED}"; shift 2 ;;
        --os)         OS_FAMILY="${2:-}"; shift 2 ;;
        --catalog)    CATALOG="${2:-}"; shift 2 ;;
        -h|--help)
            sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

[ -n "$SURFACE_ID" ] || [ -n "$LOG" ] || { echo "one of --surface-id or --log is required" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 3; }

if [ -z "$OS_FAMILY" ]; then
    OS_FAMILY="$("$SCRIPT_DIR/fingerprint.sh" 2>/dev/null \
        | python3 -c 'import json,sys; print(json.load(sys.stdin).get("os_family","unknown"))' 2>/dev/null \
        || echo unknown)"
fi

# Build the list of surface ids to verify.
if [ -n "$SURFACE_ID" ]; then
    IDS="$SURFACE_ID"
else
    [ -r "$LOG" ] || { echo "change log not readable: $LOG" >&2; exit 2; }
    IDS="$(python3 - "$LOG" <<'PY'
import json, sys
latest = {}
for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    try:
        rec = json.loads(line)
    except Exception:
        continue
    latest[rec.get("surface_id")] = rec
print("\n".join(sorted(latest)))
PY
)"
fi

[ -n "$IDS" ] || { echo "nothing to verify" >&2; exit 2; }

SCRIPT_DIR="$SCRIPT_DIR" CATALOG="$CATALOG" OS_FAMILY="$OS_FAMILY" EXPECT="$EXPECT" IDS="$IDS" \
python3 - <<'PY'
import json, os, subprocess, sys

script_dir = os.environ["SCRIPT_DIR"]
catalog = os.environ["CATALOG"]
os_family = os.environ["OS_FAMILY"]
expect = os.environ["EXPECT"]
ids = [i for i in os.environ["IDS"].splitlines() if i.strip()]

results = []
for sid in ids:
    proc = subprocess.run(
        ["bash", os.path.join(script_dir, "probe_surface.sh"),
         "--surface-id", sid, "--os", os_family, "--catalog", catalog],
        capture_output=True, text=True)
    try:
        p = json.loads(proc.stdout)
    except Exception:  # noqa: BLE001
        p = {"state": "UNKNOWN", "reason": "probe failed"}
    observed = p.get("state")
    results.append({
        "surface_id": sid,
        "expected": expect,
        "observed": observed,
        "verified": observed == expect,
        "reason": p.get("reason", ""),
    })

failed = [r for r in results if not r["verified"]]
out = {
    "checked": len(results),
    "verified": len(results) - len(failed),
    "failed": len(failed),
    "results": results,
}
json.dump(out, sys.stdout, indent=2)
sys.stdout.write("\n")
sys.exit(7 if failed else 0)
PY
