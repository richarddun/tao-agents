#!/usr/bin/env bash
# ── TAO repository conformance tests ──────────────────────────────────
# Validates package layout and manifests, checks the registry index is
# current, and runs each package's own test suite.
#
# Usage: bash tests/run_all.sh
# Exit: 0 everything passed, 1 one or more checks failed.

set -uo pipefail
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
cd "$REPO_ROOT"

failed=0

printf '\n════ Package conformance ════\n'
if python3 tests/validate_packages.py; then
    printf '→ conformance: PASSED\n'
else
    printf '→ conformance: FAILED\n'
    failed=1
fi

printf '\n════ Registry index ════\n'
if command -v python3 >/dev/null 2>&1 && python3 scripts/build_index.py --check; then
    printf '→ index: PASSED\n'
else
    printf '→ index: FAILED (run: python3 scripts/build_index.py)\n'
    failed=1
fi

printf '\n════ Package test suites ════\n'
for suite in agents/*/tests/run_all.sh; do
    [ -e "$suite" ] || continue
    pkg="$(basename "$(dirname "$(dirname "$suite")")")"
    printf '\n-- %s --\n' "$pkg"
    if bash "$suite"; then
        printf '→ %s: PASSED\n' "$pkg"
    else
        printf '→ %s: FAILED\n' "$pkg"
        failed=1
    fi
done

printf '\n════════════════════════════════════════\n'
if [ "$failed" -eq 0 ]; then
    printf 'All repository checks passed.\n'
else
    printf 'One or more repository checks failed.\n'
fi
exit "$failed"
