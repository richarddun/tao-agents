#!/usr/bin/env python3
"""Repository-level conformance tests for TAO packages.

Validates that every package under agents/ satisfies the layout and manifest
requirements of docs/package-spec.md, and that cross-package references (team
members, leads, script/SOP/rail paths) resolve.

Usage (from the repository root):
    python3 tests/validate_packages.py            # validate + report
    python3 tests/validate_packages.py --quiet    # only print problems

Exit: 0 all good, 1 conformance errors found, 3 missing dependency.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
AGENTS_DIR = REPO_ROOT / "agents"

REQUIRED_FILES = ["README.md", "SYSTEM.md", "CHANGELOG.md", "LICENSE"]
REQUIRED_DIRS = ["sops", "tests", "onboarding", ".pi"]
REQUIRED_IDENTITY = ["name", "version", "type", "maturity"]

errors: list[str] = []
warnings: list[str] = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def load_yaml(path: Path):
    try:
        import yaml  # type: ignore
    except ImportError:  # pragma: no cover
        print("error: PyYAML is required (pip install pyyaml)", file=sys.stderr)
        sys.exit(3)
    with open(path) as f:
        return yaml.safe_load(f)


def package_names():
    names = set()
    if AGENTS_DIR.is_dir():
        for p in sorted(AGENTS_DIR.iterdir()):
            if p.is_dir() and ((p / "agent.yaml").is_file() or (p / "team.yaml").is_file()):
                names.add(p.name)
    return names


def check_manifest_paths(pkg: Path, body: dict, manifest_name: str):
    for field in ("operating_loop", "core_sop"):
        val = body.get(field)
        if val and not (pkg / val).is_file():
            err(f"{pkg.name}: {field} points at a missing file: {val}")
    for lst in ("scripts", "tests", "taskrails", "knowledge_base"):
        for rel in body.get(lst) or []:
            if not (pkg / rel).is_file():
                # only warn if it is a directory-ish path
                err(f"{pkg.name}: {lst} entry missing: {rel}")


def check_team(pkg: Path, body: dict, pkg_names: set):
    lead = body.get("lead")
    if not lead:
        err(f"{pkg.name}: team manifest has no lead")
    elif lead not in pkg_names:
        err(f"{pkg.name}: lead '{lead}' is not a package in agents/")

    members = body.get("members") or []
    if not members:
        err(f"{pkg.name}: team manifest has no members")
    for m in members:
        mname = m.get("name") if isinstance(m, dict) else None
        if not mname:
            err(f"{pkg.name}: team member without a name")
        elif mname not in pkg_names:
            err(f"{pkg.name}: member '{mname}' is not a package in agents/")

    orch = body.get("orchestration") or {}
    if not orch.get("workflow"):
        err(f"{pkg.name}: orchestration.workflow is missing")
    elif not (pkg / orch["workflow"]).is_file():
        err(f"{pkg.name}: orchestration.workflow missing on disk: {orch['workflow']}")
    budgets = orch.get("budgets") or {}
    for b in ("max_agents", "max_parallel", "max_iterations"):
        if b not in budgets:
            warn(f"{pkg.name}: orchestration.budgets missing '{b}'")
    if members and budgets.get("max_agents") and budgets["max_agents"] < len(members):
        err(f"{pkg.name}: budgets.max_agents ({budgets['max_agents']}) < member count ({len(members)})")
    if not body.get("result_contract"):
        err(f"{pkg.name}: team manifest has no result_contract")


def validate_package(pkg: Path, pkg_names: set):
    manifest_name = None
    for name in ("agent.yaml", "team.yaml"):
        if (pkg / name).is_file():
            manifest_name = name
            break
    if not manifest_name:
        err(f"{pkg.name}: no agent.yaml or team.yaml")
        return

    for f in REQUIRED_FILES:
        if not (pkg / f).is_file():
            err(f"{pkg.name}: missing required file {f}")
    for d in REQUIRED_DIRS:
        if not (pkg / d).is_dir():
            err(f"{pkg.name}: missing required directory {d}/")

    if not (pkg / "tests" / "run_all.sh").is_file():
        warn(f"{pkg.name}: no tests/run_all.sh")

    try:
        data = load_yaml(pkg / manifest_name)
    except Exception as e:  # noqa: BLE001
        err(f"{pkg.name}: {manifest_name} is not valid YAML: {e}")
        return

    if not isinstance(data, dict):
        err(f"{pkg.name}: manifest is not a mapping")
        return

    top = "agent" if manifest_name == "agent.yaml" else "team"
    if top not in data:
        err(f"{pkg.name}: manifest must use a top-level '{top}:' key")
        body = data
    else:
        body = data[top]

    if not isinstance(body, dict):
        err(f"{pkg.name}: manifest body is not a mapping")
        return

    for field in REQUIRED_IDENTITY:
        if not body.get(field):
            err(f"{pkg.name}: manifest missing identity field '{field}'")

    declared_type = body.get("type")
    if declared_type and declared_type not in ("agent", "team", "standalone"):
        warn(f"{pkg.name}: unexpected type '{declared_type}'")

    if declared_type == "team" or top == "team":
        check_team(pkg, body, pkg_names)

    check_manifest_paths(pkg, body, manifest_name)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    if not AGENTS_DIR.is_dir():
        print("no agents/ directory", file=sys.stderr)
        return 1

    names = package_names()
    if not names:
        err("no packages found under agents/")

    for name in sorted(names):
        validate_package(AGENTS_DIR / name, names)

    if not args.quiet:
        print(f"Validated {len(names)} package(s): {', '.join(sorted(names))}")

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")

    print(f"\n{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
