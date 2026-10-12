#!/usr/bin/env bash
# Shared test helpers for the Privacy Champion test suite.
# Source this from a test file:  . "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

set -uo pipefail

TESTS_RUN=0
TESTS_FAIL=0
FAILED_NAMES=()

# Resolve the package root from this library's location.
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(cd "$TESTS_DIR/.." && pwd)"
SCRIPTS_DIR="$PKG_DIR/scripts"
CATALOG="$PKG_DIR/data/surface-catalog.json"

_green() { printf '\033[32m%s\033[0m' "$1"; }
_red()   { printf '\033[31m%s\033[0m' "$1"; }
_dim()   { printf '\033[2m%s\033[0m' "$1"; }

pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    printf '  %s %s\n' "$(_green '✓')" "$1"
}

fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAIL=$((TESTS_FAIL + 1))
    FAILED_NAMES+=("$1")
    printf '  %s %s\n' "$(_red '✗')" "$1"
    if [ $# -gt 1 ]; then printf '      %s\n' "$(_dim "$2")"; fi
}

assert_eq() {
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected: $3 / got: $2"; fi
}

assert_contains() {
    case "$2" in
        *"$3"*) pass "$1" ;;
        *) fail "$1" "expected to contain: $3" ;;
    esac
}

assert_not_contains() {
    case "$2" in
        *"$3"*) fail "$1" "expected NOT to contain: $3" ;;
        *) pass "$1" ;;
    esac
}

assert_file_exists() {
    if [ -e "$2" ]; then pass "$1"; else fail "$1" "missing file: $2"; fi
}

assert_file_missing() {
    if [ ! -e "$2" ]; then pass "$1"; else fail "$1" "unexpected file: $2"; fi
}

summary() {
    printf '\n%s: %d run, %d failed\n' "$1" "$TESTS_RUN" "$TESTS_FAIL"
    if [ "$TESTS_FAIL" -ne 0 ]; then
        printf 'failed: %s\n' "${FAILED_NAMES[*]}"
        return 1
    fi
    return 0
}

# JSON field lookup: json_get '<json>' '<key>'
json_get() {
    python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2],""))' "$1" "$2"
}
