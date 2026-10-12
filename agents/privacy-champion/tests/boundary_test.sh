#!/usr/bin/env bash
# ── Privacy Champion: Boundary Tests ──────────────────────────────────
# Verifies that out-of-scope, over-authority, and malformed requests are
# refused without side effects.
#
# Run: ./boundary_test.sh
# Exit: 0 all pass, 1 failures.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

printf '\nBoundary tests\n'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1. Unknown surface id is rejected by probe and by apply.
out="$(bash "$SCRIPTS_DIR/probe_surface.sh" --surface-id does-not-exist --os linux 2>&1)"; rc=$?
assert_eq "probe rejects unknown surface (exit 4)" "$rc" "4"

out="$(bash "$SCRIPTS_DIR/apply_closure.sh" --surface-id does-not-exist --os linux 2>&1)"; rc=$?
assert_eq "apply rejects unknown surface (exit 4)" "$rc" "4"

# 2. apply_closure without --apply is a no-op dry run.
out="$(bash "$SCRIPTS_DIR/apply_closure.sh" --surface-id linux-apport-error --os linux \
        --log "$TMP/changes.jsonl" 2>&1)"; rc=$?
assert_eq "apply defaults to dry-run (exit 0)" "$rc" "0"
assert_contains "apply dry-run reports mode" "$out" '"mode": "dry-run"'
assert_file_missing "dry-run writes no change log" "$TMP/changes.jsonl"

# 3. apply_closure with --apply but no --approved is refused (exit 2) and
#    still makes no change.
out="$(bash "$SCRIPTS_DIR/apply_closure.sh" --surface-id linux-apport-error --os linux \
        --apply --log "$TMP/changes.jsonl" 2>&1)"; rc=$?
assert_eq "apply without approval refused (exit 2)" "$rc" "2"
assert_contains "refusal names the approval requirement" "$out" 'approval required'
assert_file_missing "unapproved apply writes no change log" "$TMP/changes.jsonl"

# 4. A manual (GUI-only) surface cannot be applied, even when approved.
out="$(bash "$SCRIPTS_DIR/apply_closure.sh" --surface-id mac-analytics --os macos \
        --apply --approved --log "$TMP/changes.jsonl" 2>&1)"; rc=$?
assert_eq "manual surface refused (exit 5)" "$rc" "5"
assert_file_missing "manual refusal writes no change log" "$TMP/changes.jsonl"

# 5. probe refuses a catalog entry whose probe_command contains mutation.
python3 - "$CATALOG" "$TMP/bad-catalog.json" <<'PY'
import json, sys
cat = json.load(open(sys.argv[1]))
# Inject a mutating probe into a copy of the first linux surface.
s = cat["platforms"]["linux"]["surfaces"]["os"][0]
s["probe_kind"] = "command"
s["probe_command"] = "reg add HKCU\\Software\\X /v Y /t REG_DWORD /d 1 /f"
json.dump(cat, open(sys.argv[2], "w"))
PY
out="$(bash "$SCRIPTS_DIR/probe_surface.sh" --surface-id linux-ubuntu-report --os linux \
        --catalog "$TMP/bad-catalog.json" 2>&1)"
assert_contains "probe refuses mutating probe_command" "$out" '"state": "UNKNOWN"'
assert_contains "refusal explains why" "$out" 'mutation'

# 6. Unsupported / unknown OS yields no OS-specific surfaces.
out="$(bash "$SCRIPTS_DIR/enumerate_surfaces.sh" --os chromeos --browsers none 2>&1)"
count="$(json_get "$out" count)"
assert_eq "unsupported OS enumerates zero surfaces" "$count" "0"

# 7. Out-of-scope: a network surface with a manual probe is never auto-applied.
out="$(bash "$SCRIPTS_DIR/apply_closure.sh" --surface-id linux-webrtc-leak --os linux --apply --approved 2>&1)"; rc=$?
assert_eq "network manual surface refused (exit 5)" "$rc" "5"

summary "Boundary tests"
