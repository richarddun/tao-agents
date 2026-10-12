#!/usr/bin/env python3
"""Build the TAO registry index (tao.json) from the packages under agents/.

The index is a flat, committed list of the roster so consumers can discover
and pin packages without walking the repository tree. See
docs/package-spec.md §10.

Usage (from the repository root):
    python3 scripts/build_index.py            # write tao.json
    python3 scripts/build_index.py --check     # verify tao.json is current
    python3 scripts/build_index.py --json      # print the index to stdout

Dependencies: PyYAML (for agent.yaml / team.yaml).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
AGENTS_DIR = REPO_ROOT / "agents"
INDEX_PATH = REPO_ROOT / "tao.json"

# Files/dirs excluded from the curated-core hash and from discovery.
EXCLUDE_DIRS = {"local", "backups", ".git", "__pycache__", ".pytest_cache"}
EXCLUDE_FILE_RE = re.compile(r"(_state\..*\.json$|\.log$)")


def load_yaml(path: Path):
    try:
        import yaml  # type: ignore
    except ImportError:  # pragma: no cover
        print("error: PyYAML is required (pip install pyyaml)", file=sys.stderr)
        sys.exit(3)
    with open(path) as f:
        return yaml.safe_load(f)


def curated_files(pkg: Path):
    for root, dirs, files in os.walk(pkg):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for name in sorted(files):
            if EXCLUDE_FILE_RE.search(name):
                continue
            p = Path(root) / name
            yield p.relative_to(pkg)


def tree_hash(pkg: Path) -> str:
    """Deterministic SHA-256 over the curated core (path + content)."""
    h = hashlib.sha256()
    for rel in sorted(curated_files(pkg), key=lambda p: str(p)):
        h.update(str(rel).encode())
        h.update(b"\0")
        try:
            h.update((pkg / rel).read_bytes())
        except OSError:
            h.update(b"<unreadable>")
        h.update(b"\0")
    return h.hexdigest()


def one_line(text: str, limit: int = 240) -> str:
    return " ".join((text or "").split())[:limit]


def describe(body: dict) -> str:
    return one_line(body.get("purpose") or body.get("objective") or "")


def manifest_for(pkg: Path):
    for name in ("agent.yaml", "team.yaml"):
        p = pkg / name
        if p.is_file():
            return name, p
    return None, None


def build():
    entries = []
    if not AGENTS_DIR.is_dir():
        return entries
    for pkg in sorted(p for p in AGENTS_DIR.iterdir() if p.is_dir()):
        name, mpath = manifest_for(pkg)
        if not mpath:
            continue
        data = load_yaml(mpath) or {}
        body = data.get("agent") or data.get("team") or {}
        # fall back to flat keys for older manifests
        if not body:
            body = data
        entries.append({
            "name": body.get("name") or pkg.name,
            "title": body.get("title") or body.get("name") or pkg.name,
            "type": body.get("type") or ("team" if name == "team.yaml" else "agent"),
            "version": str(body.get("version") or ""),
            "maturity": body.get("maturity") or "",
            "description": describe(body),
            "path": f"agents/{pkg.name}",
            "manifest": f"agents/{pkg.name}/{name}",
            "sha256": tree_hash(pkg),
        })
    entries.sort(key=lambda e: e["name"])
    return entries


def render(entries) -> str:
    index = {
        "schema": "tao/registry-index/1",
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "count": len(entries),
        "agents": entries,
    }
    return json.dumps(index, indent=2, ensure_ascii=False) + "\n"


def strip_generated(text: str) -> str:
    """Ignore the volatile `generated` timestamp when comparing."""
    try:
        d = json.loads(text)
        d.pop("generated", None)
        return json.dumps(d, indent=2, ensure_ascii=False)
    except Exception:  # noqa: BLE001
        return text


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="verify tao.json is up to date; exit 1 if not")
    ap.add_argument("--json", action="store_true", help="print the index to stdout")
    args = ap.parse_args()

    entries = build()
    rendered = render(entries)

    if args.json:
        sys.stdout.write(rendered)
        return 0

    if args.check:
        if not INDEX_PATH.is_file():
            print("tao.json missing — run: python3 scripts/build_index.py", file=sys.stderr)
            return 1
        current = INDEX_PATH.read_text()
        if strip_generated(current) != strip_generated(rendered):
            print("tao.json is stale — run: python3 scripts/build_index.py", file=sys.stderr)
            return 1
        print(f"tao.json is up to date ({len(entries)} package(s)).")
        return 0

    INDEX_PATH.write_text(rendered)
    print(f"wrote {INDEX_PATH.relative_to(REPO_ROOT)} ({len(entries)} package(s)).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
