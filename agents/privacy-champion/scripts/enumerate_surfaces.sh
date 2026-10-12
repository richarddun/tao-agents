#!/usr/bin/env bash
# ── Privacy Champion: Enumerate Surfaces ──────────────────────────────
# Loads data/surface-catalog.json and emits the flat list of telemetry
# surfaces that apply to the detected (or supplied) OS and browsers.
#
# Read-only. Makes no changes to the system.
#
# Usage:
#   ./enumerate_surfaces.sh [--os <family>] [--browsers <csv>]
#                           [--catalog <path>] [--format json|tsv]
#
# Options:
#   --os <family>    windows | macos | linux   (default: auto-detect)
#   --browsers <csv> e.g. "chrome,firefox"     (default: auto-detect)
#                    use "all" to include every catalogued browser
#   --catalog <p>    path to surface-catalog.json (default: package data/)
#   --format <f>     json (default) or tsv
#
# Output: JSON to stdout. Errors to stderr.
# Exit: 0 success, 2 usage error, 3 catalog error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="${TAO_SURFACE_CATALOG:-$PKG_DIR/data/surface-catalog.json}"

OS_FAMILY=""
BROWSERS=""
FORMAT="json"

while [ $# -gt 0 ]; do
    case "$1" in
        --os)       OS_FAMILY="${2:-}"; shift 2 ;;
        --browsers) BROWSERS="${2:-}"; shift 2 ;;
        --catalog)  CATALOG="${2:-}"; shift 2 ;;
        --format)   FORMAT="${2:-}"; shift 2 ;;
        -h|--help)
            sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

[ -r "$CATALOG" ] || { echo "catalog not readable: $CATALOG" >&2; exit 3; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 3; }

# ── Auto-detect OS/browsers from the fingerprint script ───────────────
if [ -z "$OS_FAMILY" ] || [ -z "$BROWSERS" ]; then
    FP="$("$SCRIPT_DIR/fingerprint.sh" 2>/dev/null || true)"
    if [ -n "$FP" ]; then
        if [ -z "$OS_FAMILY" ]; then
            OS_FAMILY="$(printf '%s' "$FP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("os_family","unknown"))' 2>/dev/null || echo unknown)"
        fi
        if [ -z "$BROWSERS" ]; then
            BROWSERS="$(printf '%s' "$FP" | python3 -c 'import json,sys; print(",".join(b.get("name","").lower() for b in json.load(sys.stdin).get("browsers",[])))' 2>/dev/null || echo "")"
        fi
    fi
fi
OS_FAMILY="${OS_FAMILY:-unknown}"

TAO_CATALOG="$CATALOG" TAO_OS="$OS_FAMILY" TAO_BROWSERS="$BROWSERS" TAO_FORMAT="$FORMAT" \
python3 - <<'PY'
import json, os, sys

catalog_path = os.environ["TAO_CATALOG"]
os_family = os.environ["TAO_OS"].strip().lower()
browsers_raw = os.environ["TAO_BROWSERS"].strip().lower()
fmt = os.environ.get("TAO_FORMAT", "json")

try:
    with open(catalog_path) as f:
        cat = json.load(f)
except Exception as e:  # noqa: BLE001
    print(f"failed to parse catalog: {e}", file=sys.stderr)
    sys.exit(3)

# Normalise browser aliases -> catalog keys
ALIASES = {
    "google chrome": "chrome", "chrome": "chrome", "chromium": "chrome",
    "chromium-browser": "chrome", "google-chrome": "chrome",
    "mozilla firefox": "firefox", "firefox": "firefox",
    "microsoft edge": "edge", "edge": "edge", "msedge": "edge",
    "brave": "brave", "brave-browser": "brave",
    "safari": "safari",
}
if browsers_raw in ("", "auto"):
    wanted = set()
elif browsers_raw == "all":
    wanted = None  # None -> include every catalogued browser
else:
    wanted = {ALIASES.get(b.strip(), b.strip()) for b in browsers_raw.split(",") if b.strip()}

platforms = cat.get("platforms", {})

# ── OS + network surfaces for the detected platform ──────────────────
os_surfaces = []
if os_family in platforms:
    for cat_name in ("os", "network"):
        for s in platforms[os_family].get("surfaces", {}).get(cat_name, []) or []:
            os_surfaces.append(s)

# ── Browser surfaces (shared across platforms) ───────────────────────
browser_map = {}  # catalog browser key -> list[surface]
for plat, pv in platforms.items():
    bdict = pv.get("surfaces", {}).get("browsers", {})
    if not isinstance(bdict, dict):
        continue
    for bkey, arr in bdict.items():
        if bkey.startswith("_"):
            continue
        if isinstance(arr, list) and arr:
            browser_map.setdefault(bkey, [])
            for s in arr:
                if s not in browser_map[bkey]:
                    browser_map[bkey].append(s)

browser_surfaces = []
for bkey, arr in sorted(browser_map.items()):
    if wanted is None or bkey in wanted:
        browser_surfaces.extend(arr)

all_surfaces = os_surfaces + browser_surfaces

# ── Project to a stable, flat shape ──────────────────────────────────
FIELDS = ["surface_id", "category", "name", "description", "severity",
          "reversibility", "user_impact", "requires_admin",
          "probe_kind", "probe_command", "closure_command",
          "probe_method", "closure_method",
          "disabled_indicator", "enabled_indicator", "notes"]
projected = []
for s in all_surfaces:
    row = {k: s.get(k) for k in FIELDS if k in s}
    row["platform"] = os_family if s.get("category") != "browser" else "shared"
    projected.append(row)

by_cat = {}
for s in projected:
    by_cat[s.get("category", "unknown")] = by_cat.get(s.get("category", "unknown"), 0) + 1

if fmt == "tsv":
    cols = ["surface_id", "category", "severity", "probe_kind", "name"]
    print("\t".join(cols))
    for s in projected:
        print("\t".join(str(s.get(c, "")) for c in cols))
    sys.exit(0)

result = {
    "os_family": os_family,
    "browsers": sorted(wanted) if wanted is not None else sorted(browser_map),
    "count": len(projected),
    "by_category": by_cat,
    "surfaces": projected,
}
json.dump(result, sys.stdout, indent=2)
sys.stdout.write("\n")
PY
