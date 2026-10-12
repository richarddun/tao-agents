#!/usr/bin/env bash
# ── Privacy Champion: Test Runner ─────────────────────────────────────
# Runs the full test suite: readiness, boundary, authority, evidence,
# and the read-only scenario rehearsal.
#
# Usage: ./run_all.sh
# Exit: 0 all suites passed, 1 at least one failed.

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

run_suite "Readiness"  "$TESTS_DIR/readiness-check.sh"
run_suite "Boundary"   "$TESTS_DIR/boundary_test.sh"
run_suite "Authority"  "$TESTS_DIR/authority_test.sh"
run_suite "Evidence"   "$TESTS_DIR/evidence_test.sh"
run_suite "Scenario"   "$TESTS_DIR/scenario_test.sh"

printf '\n════════════════════════════════════════\n'
if [ "$failed" -eq 0 ]; then
    printf 'All suites passed.\n'
else
    printf 'One or more suites failed.\n'
fi
exit "$failed"
