#!/usr/bin/env bash
# ── Privacy Champion: Probe Surface ───────────────────────────────────
# Probes the current state of a single telemetry surface. READ-ONLY:
# this script never modifies the system.
#
# For surfaces whose catalog entry has probe_kind=command, the recorded
# probe_command is executed and its output classified as
# ENABLED / DISABLED / UNKNOWN using the disabled/enabled indicators.
# For probe_kind=manual surfaces (GUI / preference inspection), the
# script reports state=MANUAL together with the human probe_method.
#
# Usage:
#   ./probe_surface.sh --surface-id <id> [--os <family>] [--catalog <path>]
#                      [--timeout <seconds>] [--raw]
#
# Options:
#   --surface-id <id>  surface_id from the catalog (required)
#   --os <family>      windows | macos | linux (default: auto-detect)
#   --catalog <p>      path to surface-catalog.json
#   --timeout <s>      probe timeout in seconds (default 15)
#   --raw              include full probe output in the report
#
# Output: JSON to stdout. Errors to stderr.
# Exit: 0 probed, 2 usage error, 3 catalog error, 4 unknown surface.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="${TAO_SURFACE_CATALOG:-$PKG_DIR/data/surface-catalog.json}"

SURFACE_ID=""
OS_FAMILY=""
TIMEOUT=15
RAW=0

while [ $# -gt 0 ]; do
    case "$1" in
        --surface-id) SURFACE_ID="${2:-}"; shift 2 ;;
        --os)         OS_FAMILY="${2:-}"; shift 2 ;;
        --catalog)    CATALOG="${2:-}"; shift 2 ;;
        --timeout)    TIMEOUT="${2:-15}"; shift 2 ;;
        --raw)        RAW=1; shift ;;
        -h|--help)
            sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

TAO_CATALOG="$CATALOG" TAO_SURFACE_ID="$SURFACE_ID" TAO_OS="$OS_FAMILY" \
TAO_TIMEOUT="$TIMEOUT" TAO_RAW="$RAW" \
python3 - <<'PY'
import json, os, re, shutil, subprocess, sys

catalog_path = os.environ["TAO_CATALOG"]
sid = os.environ["TAO_SURFACE_ID"]
os_family = os.environ["TAO_OS"].strip().lower()
timeout = int(os.environ.get("TAO_TIMEOUT", "15"))
raw = os.environ.get("TAO_RAW", "0") == "1"

with open(catalog_path) as f:
    cat = json.load(f)

# Locate the surface; prefer the detected platform, fall back to any.
found = None
found_platform = None
platforms = cat.get("platforms", {})
search_order = [os_family] + [p for p in platforms if p != os_family]
for plat in search_order:
    pv = platforms.get(plat)
    if not pv:
        continue
    surfaces = pv.get("surfaces", {})
    for cat_name, val in surfaces.items():
        arr = []
        if isinstance(val, list):
            arr = val
        elif isinstance(val, dict):
            for k, v in val.items():
                if not k.startswith("_") and isinstance(v, list):
                    arr += v
        for s in arr:
            if isinstance(s, dict) and s.get("surface_id") == sid:
                found, found_platform = s, plat
                break
        if found:
            break
    if found:
        break

if not found:
    print(f"unknown surface_id: {sid}", file=sys.stderr)
    sys.exit(4)

result = {
    "surface_id": sid,
    "name": found.get("name"),
    "category": found.get("category"),
    "platform": found_platform,
    "severity": found.get("severity"),
    "reversibility": found.get("reversibility"),
    "user_impact": found.get("user_impact"),
    "probe_kind": found.get("probe_kind", "manual"),
    "state": "UNKNOWN",
    "reason": "",
}

kind = found.get("probe_kind", "manual")
cmd = found.get("probe_command")

if kind != "command" or not cmd:
    result["state"] = "MANUAL"
    result["probe_method"] = found.get("probe_method")
    result["reason"] = "Catalog entry requires manual/GUI inspection"
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.exit(0)

result["command"] = cmd

# A probe must never mutate. Refuse anything that looks like a write.
WRITE_TOKENS = ("reg add", "reg delete", "sed -i", "systemctl stop",
                "systemctl disable", "systemctl mask", "defaults write",
                "apt remove", "apt install", "dpkg-reconfigure",
                "rm -", "rmdir ", " tee ", "chmod ", "chown ",
                "truncate ", "dd if=", "dd of=")
# A bare redirect (not a fd redirect like 2>) would write a file.
has_redirect = re.search(r"(?<![0-9])>", cmd) is not None
if has_redirect or any(tok in f" {cmd} " for tok in WRITE_TOKENS):
    result["state"] = "UNKNOWN"
    result["reason"] = "Refusing to run a probe command containing mutation tokens"
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.exit(0)

# If the first executable token is missing, report UNKNOWN (platform mismatch).
first = cmd.strip().split()[0]
if shutil.which(first) is None:
    result["state"] = "UNKNOWN"
    result["exit_code"] = 127
    result["reason"] = f"probe tool not available on this platform: {first}"
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.exit(0)

try:
    proc = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True,
                          timeout=timeout)
    out = (proc.stdout or "") + (proc.stderr or "")
    result["exit_code"] = proc.returncode
    if raw:
        result["output"] = out
    else:
        result["output"] = out[:2000]
except subprocess.TimeoutExpired:
    result["state"] = "UNKNOWN"
    result["reason"] = f"probe timed out after {timeout}s"
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.exit(0)

if out.strip() == "":
    result["state"] = "UNKNOWN"
    result["reason"] = "probe returned no output"
else:
    dis = found.get("disabled_indicator")
    en = found.get("enabled_indicator")
    if dis and re.search(dis, out, re.MULTILINE):
        result["state"] = "DISABLED"
    elif en and re.search(en, out, re.MULTILINE):
        result["state"] = "ENABLED"
    else:
        result["state"] = "UNKNOWN"
        result["reason"] = "output did not match any indicator"

json.dump(result, sys.stdout, indent=2)
sys.stdout.write("\n")
PY
