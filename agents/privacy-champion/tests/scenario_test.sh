#!/usr/bin/env bash
# ── Privacy Champion: Scenario Test ───────────────────────────────────
# A full read-only rehearsal of the audit loop on the current machine:
# fingerprint -> enumerate -> probe -> dry-run apply -> verify.
# Asserts that the rehearsal leaves the system and package untouched.
#
# Run: ./scenario_test.sh
# Exit: 0 all pass, 1 failures.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

printf '\nScenario test (read-only audit rehearsal)\n'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SENTINEL="$PKG_DIR/local/change-log.jsonl"
[ -e "$SENTINEL" ] && mv "$SENTINEL" "$TMP/pre-existing-change-log.jsonl"

# 1. Fingerprint.
FP="$(bash "$SCRIPTS_DIR/fingerprint.sh" 2>/dev/null)"
osf="$(json_get "$FP" os_family)"
if [ -n "$osf" ]; then pass "fingerprint detected OS family ($osf)"; else fail "fingerprint detected OS family"; fi

# 2. Enumerate.
ENUM="$(bash "$SCRIPTS_DIR/enumerate_surfaces.sh" --os "$osf" 2>/dev/null)"
count="$(json_get "$ENUM" count)"
if [ "${count:-0}" -ge 1 ] 2>/dev/null; then pass "enumerate found surfaces ($count)"; else fail "enumerate found surfaces" "count=$count"; fi

# 3. Probe every machine-executable surface; collect states.
PROBE_JSON="$(bash "$SCRIPTS_DIR/enumerate_surfaces.sh" --os "$osf" 2>/dev/null \
    | python3 -c 'import json,sys; [print(s["surface_id"]) for s in json.load(sys.stdin)["surfaces"] if s.get("probe_kind")=="command"]')"

probed=0; states=""
while IFS= read -r sid; do
    [ -n "$sid" ] || continue
    res="$(bash "$SCRIPTS_DIR/probe_surface.sh" --surface-id "$sid" --os "$osf" 2>/dev/null)"
    st="$(json_get "$res" state)"
    states="$states $sid=$st"
    probed=$((probed + 1))
done <<< "$PROBE_JSON"
if [ "$probed" -ge 1 ]; then pass "probed $probed command surface(s)"; else fail "probed command surfaces"; fi
printf '      states:%s\n' "$states"

# 4. Dry-run apply on the first command surface (must not mutate).
first_sid="$(printf '%s' "$PROBE_JSON" | head -1)"
if [ -n "$first_sid" ]; then
    APPLY="$(bash "$SCRIPTS_DIR/apply_closure.sh" --surface-id "$first_sid" --os "$osf" \
        --log "$TMP/changes.jsonl" 2>/dev/null)"
    assert_eq "dry-run apply reported dry-run" "$(json_get "$APPLY" mode)" "dry-run"
    assert_file_missing "dry-run apply wrote no log" "$TMP/changes.jsonl"
fi

# 5. Verify against the current observed state (expect whatever probe says).
if [ -n "$first_sid" ]; then
    res="$(bash "$SCRIPTS_DIR/probe_surface.sh" --surface-id "$first_sid" --os "$osf" 2>/dev/null)"
    observed="$(json_get "$res" state)"
    VER="$(bash "$SCRIPTS_DIR/verify_closure.sh" --surface-id "$first_sid" --os "$osf" --expect "$observed" 2>/dev/null)"
    assert_eq "verify matches current observed state" "$(json_get "$VER" failed)" "0"
fi

# 6. The rehearsal must leave the curated package untracked-clean w.r.t. local/.
assert_file_missing "rehearsal created no change log in the package" "$SENTINEL"
assert_file_missing "rehearsal created no backups in the package" "$PKG_DIR/local/backups"

# 7. No audit artifact should have been written anywhere in the package.
stray="$(find "$PKG_DIR" -name '*_state.*.json' -o -name 'change-log.jsonl' 2>/dev/null | head -1)"
assert_eq "rehearsal left no stray state files" "$stray" ""

[ -e "$TMP/pre-existing-change-log.jsonl" ] && mv "$TMP/pre-existing-change-log.jsonl" "$SENTINEL"

summary "Scenario test"
