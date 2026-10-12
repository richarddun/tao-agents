#!/usr/bin/env bash
# ── Privacy Champion: Evidence Tests ──────────────────────────────────
# Verifies that every script emits machine-readable evidence with the
# fields the SOP and audit report depend on.
#
# Run: ./evidence_test.sh
# Exit: 0 all pass, 1 failures.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

printf '\nEvidence tests\n'

python3_ok() { python3 -c 'import json,sys; json.loads(sys.stdin.read())' >/dev/null 2>&1; }

# ── fingerprint.sh ────────────────────────────────────────────────────
FP="$(bash "$SCRIPTS_DIR/fingerprint.sh" 2>/dev/null)"
if printf '%s' "$FP" | python3_ok; then pass "fingerprint emits valid JSON"; else fail "fingerprint emits valid JSON"; fi
for key in fingerprint_version timestamp os_name os_family os_version browsers privilege_level available_tools; do
    if printf '%s' "$FP" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if '$key' in d else 1)"; then
        pass "fingerprint has '$key'"
    else
        fail "fingerprint has '$key'"
    fi
done

# ── enumerate_surfaces.sh ─────────────────────────────────────────────
ENUM="$(bash "$SCRIPTS_DIR/enumerate_surfaces.sh" --os linux 2>/dev/null)"
if printf '%s' "$ENUM" | python3_ok; then pass "enumerate emits valid JSON"; else fail "enumerate emits valid JSON"; fi
for key in os_family count by_category surfaces; do
    if printf '%s' "$ENUM" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if '$key' in d else 1)"; then
        pass "enumerate has '$key'"
    else
        fail "enumerate has '$key'"
    fi
done
surfaces_ok="$(printf '%s' "$ENUM" | python3 -c '
import json,sys
d=json.load(sys.stdin)
req={"surface_id","category","severity","probe_kind"}
bad=[s for s in d["surfaces"] if not req.issubset(s)]
print("ok" if d["surfaces"] and not bad else "bad")')"
assert_eq "every enumerated surface carries required fields" "$surfaces_ok" "ok"

# ── probe_surface.sh ──────────────────────────────────────────────────
PROBE="$(bash "$SCRIPTS_DIR/probe_surface.sh" --surface-id linux-apport-error --os linux 2>/dev/null)"
if printf '%s' "$PROBE" | python3_ok; then pass "probe emits valid JSON"; else fail "probe emits valid JSON"; fi
for key in surface_id state reason; do
    if printf '%s' "$PROBE" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if '$key' in d else 1)"; then
        pass "probe has '$key'"
    else
        fail "probe has '$key'"
    fi
done
state="$(json_get "$PROBE" state)"
case "$state" in
    ENABLED|DISABLED|UNKNOWN|MANUAL) pass "probe state is one of the allowed values ($state)" ;;
    *) fail "probe state is one of the allowed values" "got: $state" ;;
esac
# A command surface must carry the command it ran as evidence.
if printf '%s' "$PROBE" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('probe_kind')!='command' or d.get('command') else 1)"; then
    pass "probe records the executed command for command surfaces"
else
    fail "probe records the executed command for command surfaces"
fi

# ── verify_closure.sh ─────────────────────────────────────────────────
VER="$(bash "$SCRIPTS_DIR/verify_closure.sh" --surface-id linux-whoopsie --os linux 2>/dev/null)"
if printf '%s' "$VER" | python3_ok; then pass "verify emits valid JSON"; else fail "verify emits valid JSON"; fi
for key in checked verified failed results; do
    if printf '%s' "$VER" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if '$key' in d else 1)"; then
        pass "verify has '$key'"
    else
        fail "verify has '$key'"
    fi
done

# ── apply_closure.sh (dry-run evidence) ───────────────────────────────
APPLY="$(bash "$SCRIPTS_DIR/apply_closure.sh" --surface-id linux-apport-error --os linux 2>/dev/null)"
for key in surface_id mode before_state closure_command; do
    if printf '%s' "$APPLY" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if '$key' in d else 1)"; then
        pass "apply dry-run has '$key'"
    else
        fail "apply dry-run has '$key'"
    fi
done

summary "Evidence tests"
