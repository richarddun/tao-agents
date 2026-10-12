#!/usr/bin/env bash
# ── Privacy Champion: Authority Tests ─────────────────────────────────
# Verifies the declared authority model is present in the manifest and is
# actually enforced by the scripts.
#
# Run: ./authority_test.sh
# Exit: 0 all pass, 1 failures.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

printf '\nAuthority tests\n'

MANIFEST="$PKG_DIR/agent.yaml"
assert_file_exists "manifest exists" "$MANIFEST"

# 1. The manifest must be parseable YAML.
if python3 - "$MANIFEST" <<'PY' 2>/dev/null
import sys
try:
    import yaml
except ImportError:
    sys.exit(0)  # PyYAML optional; skip when unavailable
try:
    d = yaml.safe_load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
sys.exit(0 if isinstance(d, dict) else 1)
PY
then pass "agent.yaml is valid YAML (or PyYAML unavailable)"
else fail "agent.yaml is valid YAML"; fi

# 2. Declared authority: mutations require per-surface approval; destructive prohibited.
assert_contains "mutate_os_settings requires approval" \
    "$(cat "$MANIFEST")" "mutate_os_settings: explicit_approval_per_surface"
assert_contains "mutate_browser_settings requires approval" \
    "$(cat "$MANIFEST")" "mutate_browser_settings: explicit_approval_per_surface"
assert_contains "mutate_network_config requires approval" \
    "$(cat "$MANIFEST")" "mutate_network_config: explicit_approval_per_surface"
assert_contains "destructive prohibited by default" \
    "$(cat "$MANIFEST")" "destructive: prohibited_by_default"

# 3. The mutation script enforces the approval gate.
assert_contains "apply_closure documents the approval gate" \
    "$(cat "$SCRIPTS_DIR/apply_closure.sh")" "approval required"
assert_contains "apply_closure requires --approved" \
    "$(cat "$SCRIPTS_DIR/apply_closure.sh")" "--approved"

# 4. Only apply_closure.sh executes a catalog closure_command. The other
#    scripts must never run a closure (they may reference the field name
#    when listing surfaces, but must not execute it).
assert_contains "apply_closure executes the closure" \
    "$(cat "$SCRIPTS_DIR/apply_closure.sh")" '"-c", closure]'
for f in "$SCRIPTS_DIR"/*.sh; do
    base="$(basename "$f")"
    [ "$base" = "apply_closure.sh" ] && continue
    assert_not_contains "$base never executes a closure command" \
        "$(cat "$f")" '"-c", closure]'
done

# 5. Read-only scripts are marked read-only in their headers.
assert_contains "enumerate is documented read-only" "$(cat "$SCRIPTS_DIR/enumerate_surfaces.sh")" "Read-only"
assert_contains "probe is documented read-only" "$(cat "$SCRIPTS_DIR/probe_surface.sh")" "READ-ONLY"
assert_contains "verify is documented read-only" "$(cat "$SCRIPTS_DIR/verify_closure.sh")" "READ-ONLY"

# 6. Behavioral: the approval gate is enforced at runtime (repeat of the
#    boundary check, kept here because it is an authority property).
bash "$SCRIPTS_DIR/apply_closure.sh" --surface-id linux-apport-error --os linux --apply >/dev/null 2>&1; rc=$?
assert_eq "approval gate enforced at runtime (exit 2)" "$rc" "2"

summary "Authority tests"
