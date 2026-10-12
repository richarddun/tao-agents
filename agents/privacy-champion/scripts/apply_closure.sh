#!/usr/bin/env bash
# ── Privacy Champion: Apply Closure ───────────────────────────────────
# Applies a single, pre-approved surface closure. This is the ONLY script
# in the package that mutates the system.
#
# Safety model (non-negotiable):
#   * Dry-run by default. Nothing is changed unless --apply is given.
#   * --apply additionally requires --approved. Without it the script
#     refuses and exits 2, having changed nothing.
#   * Only surfaces whose catalog entry has a closure_command can be
#     applied. Manual surfaces are refused.
#   * The before/after state is probed with probe_surface.sh and the
#     change is appended to a JSONL change log.
#
# Usage:
#   ./apply_closure.sh --surface-id <id> [--os <family>] [--catalog <path>]
#                      [--apply --approved] [--reason <text>]
#                      [--log <jsonl>] [--backup-dir <dir>] [--backup <file>]
#
# Exit: 0 dry-run / applied successfully, 2 usage or approval error,
#       3 catalog error, 4 unknown surface, 5 no closure method,
#       6 closure command failed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="${TAO_SURFACE_CATALOG:-$PKG_DIR/data/surface-catalog.json}"

SURFACE_ID=""
OS_FAMILY=""
APPLY=0
APPROVED=0
REASON=""
LOG="${TAO_CHANGE_LOG:-$PKG_DIR/local/change-log.jsonl}"
BACKUP_DIR="${TAO_BACKUP_DIR:-$PKG_DIR/local/backups}"
BACKUP_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --surface-id) SURFACE_ID="${2:-}"; shift 2 ;;
        --os)         OS_FAMILY="${2:-}"; shift 2 ;;
        --catalog)    CATALOG="${2:-}"; shift 2 ;;
        --apply)      APPLY=1; shift ;;
        --approved)   APPROVED=1; shift ;;
        --reason)     REASON="${2:-}"; shift 2 ;;
        --log)        LOG="${2:-}"; shift 2 ;;
        --backup-dir) BACKUP_DIR="${2:-}"; shift 2 ;;
        --backup)     BACKUP_FILE="${2:-}"; shift 2 ;;
        -h|--help)
            sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

[ -n "$SURFACE_ID" ] || { echo "--surface-id is required" >&2; exit 2; }
[ -r "$CATALOG" ] || { echo "catalog not readable: $CATALOG" >&2; exit 3; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 3; }

if [ -z "$OS_FAMILY" ]; then
    OS_FAMILY="$("$SCRIPT_DIR/fingerprint.sh" 2>/dev/null \
        | python3 -c 'import json,sys; print(json.load(sys.stdin).get("os_family","unknown"))' 2>/dev/null \
        || echo unknown)"
fi

SURFACE_ID="$SURFACE_ID" OS_FAMILY="$OS_FAMILY" CATALOG="$CATALOG" \
APPLY="$APPLY" APPROVED="$APPROVED" REASON="$REASON" LOG="$LOG" \
BACKUP_DIR="$BACKUP_DIR" BACKUP_FILE="$BACKUP_FILE" SCRIPT_DIR="$SCRIPT_DIR" \
python3 - <<'PY'
import json, os, re, shlex, shutil, subprocess, sys, datetime

sid = os.environ["SURFACE_ID"]
os_family = os.environ["OS_FAMILY"]
catalog = os.environ["CATALOG"]
apply_ = os.environ["APPLY"] == "1"
approved = os.environ["APPROVED"] == "1"
reason = os.environ["REASON"]
log_path = os.environ["LOG"]
backup_dir = os.environ["BACKUP_DIR"]
backup_file = os.environ["BACKUP_FILE"]
script_dir = os.environ["SCRIPT_DIR"]

with open(catalog) as f:
    cat = json.load(f)

def locate(sid):
    platforms = cat.get("platforms", {})
    order = [os_family.lower()] + [p for p in platforms if p != os_family.lower()]
    for plat in order:
        pv = platforms.get(plat)
        if not pv:
            continue
        for cat_name, val in pv.get("surfaces", {}).items():
            arr = []
            if isinstance(val, list):
                arr = val
            elif isinstance(val, dict):
                for k, v in val.items():
                    if not k.startswith("_") and isinstance(v, list):
                        arr += v
            for s in arr:
                if isinstance(s, dict) and s.get("surface_id") == sid:
                    return s, plat
    return None, None

surface, platform = locate(sid)
if not surface:
    print(f"unknown surface_id: {sid}", file=sys.stderr)
    sys.exit(4)

closure = surface.get("closure_command")
kind = surface.get("probe_kind", "manual")

def probe():
    proc = subprocess.run(["bash", os.path.join(script_dir, "probe_surface.sh"),
                           "--surface-id", sid, "--os", os_family, "--catalog", catalog],
                          capture_output=True, text=True)
    try:
        return json.loads(proc.stdout)
    except Exception:  # noqa: BLE001
        return {"state": "UNKNOWN", "reason": "probe failed", "raw": proc.stdout + proc.stderr}

if kind != "command" or not closure:
    print(json.dumps({
        "surface_id": sid, "mode": "refused",
        "error": "no machine-executable closure method (manual surface)",
        "closure_method": surface.get("closure_method"),
    }, indent=2))
    sys.exit(5)

plan = {
    "surface_id": sid,
    "name": surface.get("name"),
    "category": surface.get("category"),
    "platform": platform,
    "severity": surface.get("severity"),
    "closure_command": closure,
    "before_state": probe().get("state"),
}

# ── Dry-run (default) ────────────────────────────────────────────────
if not apply_:
    plan["mode"] = "dry-run"
    plan["note"] = "No changes made. Re-run with --apply --approved to execute."
    print(json.dumps(plan, indent=2))
    sys.exit(0)

# ── Approval gate ────────────────────────────────────────────────────
if not approved:
    print(json.dumps({
        "surface_id": sid, "mode": "refused",
        "error": "approval required: --apply must be accompanied by --approved",
        "closure_command": closure,
        "note": "No changes made.",
    }, indent=2), file=sys.stderr)
    sys.exit(2)

# ── Apply ────────────────────────────────────────────────────────────
os.makedirs(os.path.dirname(log_path), exist_ok=True) if os.path.dirname(log_path) else None
timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

backup_path = None
if backup_file and os.path.exists(backup_file):
    os.makedirs(backup_dir, exist_ok=True)
    base = os.path.basename(backup_file)
    backup_path = os.path.join(backup_dir, f"{base}.{timestamp.replace(':', '')}.bak")
    shutil.copy2(backup_file, backup_path)

try:
    proc = subprocess.run(["bash", "-c", closure], capture_output=True, text=True, timeout=120)
    exit_code = proc.returncode
    cmd_out = (proc.stdout or "") + (proc.stderr or "")
except subprocess.TimeoutExpired:
    exit_code = 124
    cmd_out = "closure command timed out after 120s"

after = probe()
record = {
    "timestamp": timestamp,
    "surface_id": sid,
    "platform": platform,
    "closure_command": closure,
    "exit_code": exit_code,
    "before_state": plan["before_state"],
    "after_state": after.get("state"),
    "backup": backup_path,
    "reason": reason,
    "output": cmd_out[-2000:],
}
with open(log_path, "a") as f:
    f.write(json.dumps(record) + "\n")

result = {
    "surface_id": sid,
    "mode": "applied" if exit_code == 0 else "failed",
    "before_state": record["before_state"],
    "after_state": record["after_state"],
    "exit_code": exit_code,
    "backup": backup_path,
    "log": log_path,
}
print(json.dumps(result, indent=2))
sys.exit(0 if exit_code == 0 else 6)
PY
