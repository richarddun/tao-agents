#!/usr/bin/env bash
# ── System Sentinel: Scenario Test ────────────────────────────────────
# A full read-only rehearsal: collect an inventory, confirm the taskrail
# loads through the vendored runner, and verify the rehearsal leaves no
# state behind.
#
# Run: ./scenario_test.sh
# Exit: 0 all pass, 1 failures.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

printf '\nScenario test (read-only assessment rehearsal)\n'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1. Collect.
INV="$(bash "$SCRIPTS_DIR/inventory.sh" 2>/dev/null)"
osf="$(printf '%s' "$INV" | python3 -c 'import json,sys; print(json.load(sys.stdin)["fields"]["os_family"])' 2>/dev/null)"
if [ -n "$osf" ]; then pass "inventory detected OS family ($osf)"; else fail "inventory detected OS family"; fi

# 2. The rail loads through the repository's reference runner (if present).
REPO_ROOT="$(cd "$PKG_DIR/../.." && pwd)"
if [ -x "$REPO_ROOT/scripts/taskrail" ]; then
    out="$("$REPO_ROOT/scripts/taskrail" info --taskrails-dir "$RAILS_DIR" system-assessment 2>&1)"
    assert_contains "vendored runner loads the assessment rail" "$out" "System Assessment"
else
    printf '  %s\n' "(reference runner not found at $REPO_ROOT/scripts/taskrail — skipped)"
fi

# 3. Rehearsal leaves no state.
stray="$(find "$PKG_DIR" -name '*_state.*.json' -o -name 'change-log.jsonl' -o -name '*.bak' 2>/dev/null | head -1)"
assert_eq "rehearsal left no state files" "$stray" ""

summary "Scenario test"
