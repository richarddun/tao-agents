#!/usr/bin/env bash
# ── System Sentinel: Test Runner ──────────────────────────────────────
# Runs readiness, boundary/evidence and scenario suites.
#
# Usage: ./run_all.sh
# Exit: 0 all passed, 1 one or more failed.

set -uo pipefail
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

failed=0
run_suite() {
    local name="$1" cmd="$2"
    printf '\n════ %s ════\n' "$name"
    if bash "$cmd"; then
        printf '→ %s: PASSED\n' "$name"
    else
        printf '→ %s: FAILED\n' "$name"
        failed=1
    fi
}

run_suite "Readiness"         "$TESTS_DIR/readiness-check.sh"
run_suite "Boundary/Evidence" "$TESTS_DIR/boundary_test.sh"
run_suite "Scenario"          "$TESTS_DIR/scenario_test.sh"

printf '\n════════════════════════════════════════\n'
[ "$failed" -eq 0 ] && printf 'All suites passed.\n' || printf 'One or more suites failed.\n'
exit "$failed"
