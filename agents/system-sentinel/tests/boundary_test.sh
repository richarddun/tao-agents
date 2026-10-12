#!/usr/bin/env bash
# ── System Sentinel: Boundary & Evidence Tests ────────────────────────
# The agent is read-only: verify the collection script mutates nothing,
# emits valid evidence, and that the package references resolve.
#
# Run: ./boundary_test.sh
# Exit: 0 all pass, 1 failures.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

printf '\nBoundary & evidence tests\n'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1. Inventory emits valid JSON with its required fields.
INV="$(bash "$SCRIPTS_DIR/inventory.sh" 2>/dev/null)"
if printf '%s' "$INV" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; then
    pass "inventory emits valid JSON"
else
    fail "inventory emits valid JSON"
fi
for key in inventory_version fields; do
    if printf '%s' "$INV" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if '$key' in d else 1)"; then
        pass "inventory has '$key'"
    else
        fail "inventory has '$key'"
    fi
done
for field in os_family os_version privilege_level memory_total load_average disks listening firewall pending_updates; do
    if printf '%s' "$INV" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if '$field' in d['fields'] else 1)"; then
        pass "inventory field '$field'"
    else
        fail "inventory field '$field'"
    fi
done

# 2. The collection script contains no mutation command.
bad="$(python3 - "$SCRIPTS_DIR/inventory.sh" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
pats = [
    r'\brm\b', r'\bmv\b', r'\bcp\b', r'\bmkfs\b', r'\btruncate\b',
    r'\bchmod\b', r'\bchown\b', r'\buseradd\b', r'\busermod\b', r'\bpasswd\b',
    r'\bdd\b', r'\btee\b', r'\bmount\b', r'\bumount\b',
    r'\binstall\b', r'\bremove\b', r'\bpurge\b',
    r'\bsystemctl\b.*\b(start|stop|restart|disable|enable|mask)\b',
    r'\blaunchctl\b.*\b(load|unload)\b',
    r'\bdefaults\s+write\b', r'\bsed\s+-i\b',
]
hits = [p for p in pats if re.search(p, s)]
print(" ".join(hits))
PY
)"
assert_eq "inventory contains no mutation command" "$bad" ""

# 3. Running the inventory twice produces no files anywhere in the package.
before="$(find "$PKG_DIR" -type f -newermt '-1 second' 2>/dev/null | wc -l)"
bash "$SCRIPTS_DIR/inventory.sh" >/dev/null 2>&1
stray="$(find "$PKG_DIR" -name '*_state.*.json' -o -name 'change-log.jsonl' -o -name '*.bak' 2>/dev/null | head -1)"
assert_eq "inventory leaves no state files" "$stray" ""

# 4. Required package files resolve.
assert_file_exists "taskrail present" "$RAILS_DIR/system-assessment.taskrail.json"
assert_file_exists "induction rail present" "$PKG_DIR/onboarding/induction.taskrail.json"
assert_file_exists "result schema present" "$SCHEMA"
assert_file_exists "SOP present" "$PKG_DIR/sops/system-assessment.sop.md"

# 5. Taskrail and schema are valid JSON.
if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$RAILS_DIR/system-assessment.taskrail.json" 2>/dev/null; then
    pass "taskrail is valid JSON"
else
    fail "taskrail is valid JSON"
fi
if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SCHEMA" 2>/dev/null; then
    pass "result schema is valid JSON"
else
    fail "result schema is valid JSON"
fi

summary "Boundary & evidence tests"
