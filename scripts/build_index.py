#!/usr/bin/env python3
"""Build the TAO registry index (tao.json) from the packages under agents/.

The index is a flat, committed list of the roster so consumers can discover,
pin and fetch packages without walking the repository tree. See
docs/package-spec.md §10.

Resolution contract (what makes an index entry *fetchable*):

    fetch  = <repository>/archive/<revision>.tar.gz
    unpack = <that tarball>:<path>
    verify = tree_hash(unpacked package) == entry.sha256

`revision` is the commit whose package contents the hashes describe. An
index-only commit after it does not invalidate the index (the package files
are unchanged), so `--check` verifies *that* — no package change since
`revision` — rather than requiring `revision == HEAD`.

Usage (from the repository root):
    python3 scripts/build_index.py            # write tao.json
    python3 scripts/build_index.py --check     # verify tao.json is current
    python3 scripts/build_index.py --json      # print the index to stdout

    # overrides for environments without git (CI from a tarball, etc.)
    python3 scripts/build_index.py --revision <sha> --repository <https url> \
        --tag v0.2.0

Dependencies: PyYAML (for agent.yaml / team.yaml).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
AGENTS_DIR = REPO_ROOT / "agents"
INDEX_PATH = REPO_ROOT / "tao.json"

SCHEMA = "tao/registry-index/2"

# Fields that change without any package changing — excluded from the
# "is the index current?" comparison.
VOLATILE_FIELDS = ("generated", "revision", "tag")

# Files/dirs excluded from the curated-core hash and from discovery.
EXCLUDE_DIRS = {"local", "backups", ".git", "__pycache__", ".pytest_cache"}
EXCLUDE_FILE_RE = re.compile(r"(_state\..*\.json$|\.log$)")

_DESCRIPTION_LIMIT = 200


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
    """Deterministic SHA-256 over the curated core (path + content).

    ⚠️ This is a cross-implementation contract: pi-hydra reimplements it in
    `lib/registry.ts` and verifies the hash before installing a package. Any
    change here must change both, or every consumer breaks.
    """
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


def one_line(text: str, limit: int = _DESCRIPTION_LIMIT) -> str:
    """Collapse whitespace and truncate on a word boundary (never mid-word)."""
    s = " ".join((text or "").split())
    if len(s) <= limit:
        return s
    cut = s[:limit]
    if " " in cut:
        cut = cut[: cut.rfind(" ")]
    return cut.rstrip(" ,;:.") + "…"


def describe(body: dict) -> str:
    return one_line(body.get("purpose") or body.get("objective") or "")


def manifest_for(pkg: Path):
    for name in ("agent.yaml", "team.yaml"):
        p = pkg / name
        if p.is_file():
            return name, p
    return None, None


# ── git helpers (all best-effort: a tarball checkout has no .git) ───────────

def git(*args: str) -> str | None:
    try:
        r = subprocess.run(
            ["git", *args], cwd=REPO_ROOT, capture_output=True, text=True, timeout=15
        )
        if r.returncode != 0:
            return None
        return r.stdout.strip()
    except Exception:  # noqa: BLE001
        return None


def normalise_repo_url(url: str | None) -> str | None:
    """`git@github.com:o/r.git` → `https://github.com/o/r`."""
    if not url:
        return None
    url = url.strip()
    m = re.match(r"^git@([^:]+):(.+?)(?:\.git)?$", url)
    if m:
        return f"https://{m.group(1)}/{m.group(2)}"
    url = re.sub(r"\.git$", "", url)
    if url.startswith("http://") or url.startswith("https://"):
        return url
    return None


def detect_revision() -> str | None:
    sha = git("rev-parse", "HEAD")
    if sha and re.fullmatch(r"[0-9a-f]{40}", sha):
        return sha
    return None


def detect_repository() -> str | None:
    return normalise_repo_url(git("config", "--get", "remote.origin.url"))


def detect_tag() -> str | None:
    return git("describe", "--tags", "--exact-match", "HEAD")


# ── index construction ─────────────────────────────────────────────────────

def build(entry_types: dict[str, str] | None = None) -> list[dict]:
    """Build the entry list. Pass a first-pass `entry_types` map to fill `requires`."""
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
        entry = {
            "name": body.get("name") or pkg.name,
            "title": body.get("title") or body.get("name") or pkg.name,
            "type": body.get("type") or ("team" if name == "team.yaml" else "agent"),
            "version": str(body.get("version") or ""),
            "maturity": body.get("maturity") or "",
            "description": describe(body),
            "path": f"agents/{pkg.name}",
            "manifest": f"agents/{pkg.name}/{name}",
            "sha256": tree_hash(pkg),
        }
        requires = required_packages(body, pkg.name, entry_types)
        if requires:
            entry["requires"] = requires
        entries.append(entry)
    entries.sort(key=lambda e: e["name"])
    return entries


def required_packages(body: dict, self_name: str, entry_types: dict[str, str] | None) -> list[dict]:
    """Cross-package references a consumer must install alongside this one.

    Teams reference their lead and members. Standalone agents have none.
    """
    names: list[str] = []
    lead = body.get("lead")
    if lead:
        names.append(lead)
    for m in body.get("members") or []:
        if isinstance(m, dict) and m.get("name"):
            names.append(m["name"])
        elif isinstance(m, str):
            names.append(m)
    out = []
    for n in sorted({n for n in names if n and n != self_name}):
        t = (entry_types or {}).get(n)
        out.append({"name": n, **({"type": t} if t else {})})
    return out


def entry_types(entries: list[dict]) -> dict[str, str]:
    return {e["name"]: e["type"] for e in entries}


def render(entries: list[dict], repository: str | None, revision: str | None, tag: str | None) -> str:
    index: dict = {
        "schema": SCHEMA,
        "repository": repository or "",
        "revision": revision or "",
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "count": len(entries),
        "agents": entries,
    }
    if tag:
        index["tag"] = tag
    return json.dumps(index, indent=2, ensure_ascii=False) + "\n"


def strip_volatile(text: str) -> str:
    """Drop fields that legitimately change without a package changing."""
    try:
        d = json.loads(text)
    except Exception:  # noqa: BLE001
        return text
    for f in VOLATILE_FIELDS:
        d.pop(f, None)
    return json.dumps(d, indent=2, ensure_ascii=False)


def check_revision_fresh(revision: str) -> tuple[bool, str]:
    """True if no package file changed since `revision`.

    Compares `revision` against the *working tree*, so it also catches
    uncommitted package edits. Best-effort: no git → not a failure.
    """
    if git("rev-parse", "--verify", f"{revision}^{{commit}}") is None:
        return True, f"revision {revision[:12]}… is not in this clone; skipped"
    try:
        r = subprocess.run(
            ["git", "diff", "--quiet", revision, "--", "agents"],
            cwd=REPO_ROOT, capture_output=True, timeout=15,
        )
        if r.returncode == 0:
            return True, ""
        return False, f"packages changed since revision {revision[:12]}…"
    except Exception:  # noqa: BLE001
        return True, "git diff unavailable; skipped"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="verify tao.json is up to date; exit 1 if not")
    ap.add_argument("--json", action="store_true", help="print the index to stdout")
    ap.add_argument("--revision", help="commit SHA the index describes (else: git HEAD)")
    ap.add_argument("--repository", help="source repository URL (else: git origin)")
    ap.add_argument("--tag", help="release tag for this revision, if any")
    args = ap.parse_args()

    repository = normalise_repo_url(args.repository) or detect_repository()
    revision = args.revision or detect_revision()
    tag = args.tag if args.tag is not None else detect_tag()

    if args.json:
        first = build()
        entries = build(entry_types(first))
        sys.stdout.write(render(entries, repository, revision, tag))
        return 0

    if args.check:
        if not INDEX_PATH.is_file():
            print("tao.json missing — run: python3 scripts/build_index.py", file=sys.stderr)
            return 1
        current = INDEX_PATH.read_text()
        try:
            current_rev = json.loads(current).get("revision") or ""
        except Exception:  # noqa: BLE001
            current_rev = ""
        fresh = build()
        entries = build(entry_types(fresh))
        expected = render(entries, repository, revision, tag)

        ok = True
        if strip_volatile(current) != strip_volatile(expected):
            print(
                "tao.json is stale (package list or hashes changed) — "
                "run: python3 scripts/build_index.py",
                file=sys.stderr,
            )
            ok = False
        if current_rev:
            good, why = check_revision_fresh(current_rev)
            if not good:
                print(f"tao.json is stale: {why} — run: python3 scripts/build_index.py",
                      file=sys.stderr)
                ok = False
        else:
            print("warning: tao.json has no revision field (older index schema)",
                  file=sys.stderr)
        if ok:
            print(f"tao.json is up to date ({len(entries)} package(s)).")
            return 0
        return 1

    if not revision:
        print(
            "error: cannot determine a revision (no git HEAD). Pass --revision <sha>.",
            file=sys.stderr,
        )
        return 3
    if not repository:
        print(
            "warning: cannot determine a repository URL; pass --repository <url> "
            "so the index is resolvable.",
            file=sys.stderr,
        )

    first = build()
    entries = build(entry_types(first))
    INDEX_PATH.write_text(render(entries, repository, revision, tag))
    print(f"wrote {INDEX_PATH.relative_to(REPO_ROOT)} "
          f"({len(entries)} package(s), revision {revision[:12]}…)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
