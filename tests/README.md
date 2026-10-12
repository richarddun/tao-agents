# Repository tests

Conformance checks that span every package in the roster. Each package also
ships its own suite under `agents/<name>/tests/`.

## Run everything

```bash
bash tests/run_all.sh
```

This runs, in order:

1. **Package conformance** — `tests/validate_packages.py`
2. **Registry index freshness** — `scripts/build_index.py --check`
3. **Each package's suite** — `agents/*/tests/run_all.sh`

## `validate_packages.py`

Validates every directory under `agents/` against `docs/package-spec.md`:

- required files (`README.md`, `SYSTEM.md`, `CHANGELOG.md`, `LICENSE`, and a
  manifest) and directories (`sops/`, `tests/`, `onboarding/`, `.pi/`)
- the manifest is valid YAML with a single top-level `agent:` or `team:` key
- identity fields (`name`, `version`, `type`, `maturity`) are present
- referenced paths resolve (`operating_loop`, `core_sop`, `scripts`, `tests`,
  `taskrails`, `knowledge_base`)
- for teams: the lead and every member are real packages, the orchestration
  workflow and result contract exist, and budgets are coherent

```bash
python3 tests/validate_packages.py           # validate and report
python3 tests/validate_packages.py --quiet    # only print problems
```

Exit codes: `0` clean, `1` conformance errors, `3` missing dependency (PyYAML).

## Package test conventions

Each package should provide `tests/run_all.sh` and cover:

- **Readiness** — tools, script permissions, catalog/rail/schema parsing
- **Boundary** — out-of-scope and over-authority requests are refused
- **Authority** — approval gates are enforced (declared and behavioural)
- **Evidence** — outputs carry the required machine-readable fields
- **Scenario** — a read-only end-to-end rehearsal

See `agents/privacy-champion/tests/` and `agents/system-sentinel/tests/` for
reference implementations.
