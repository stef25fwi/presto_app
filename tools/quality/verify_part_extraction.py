#!/usr/bin/env python3
"""Prove that a `part` extraction moved code without modifying it.

Splitting a Dart library into `part` files is the only decomposition step that
is behaviour-preserving *by construction*: all parts share one library scope,
so private identifiers, imports and top-level resolution are unchanged. The
risk is not the mechanism — it is the human hand slipping while moving code.

This checker removes that risk. It compares the multiset of non-directive lines
before and after the split: relocation is allowed, any added, removed or edited
line is reported. A passing run means the extraction is a pure move.

Why not compare compiled output instead: `flutter build web` is deterministic
(verified), but dart2js emits declarations in source order and assigns minified
names accordingly. A pure `part` move therefore produces an artifact of exactly
the same size with ~0.85% of bytes permuted. Hash comparison yields false
alarms; byte-size equality survives as a useful secondary signal only.

Usage:
    python3 tools/quality/verify_part_extraction.py --base-ref origin/main \\
        lib/pages/toolbox_je_me_lance_page.dart
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

PART_DIRECTIVE = re.compile(r"^\s*part\s+'([^']+)'\s*;\s*$")
PART_OF_DIRECTIVE = re.compile(r"^\s*part\s+of\s+'[^']+'\s*;\s*$")


def significant_lines(text: str) -> list[str]:
    """Lines that must be preserved: everything but part directives and blanks."""
    kept = []
    for line in text.splitlines():
        if PART_OF_DIRECTIVE.match(line) or PART_DIRECTIVE.match(line):
            continue
        if not line.strip():
            continue
        kept.append(line)
    return kept


def declared_parts(text: str) -> list[str]:
    return [match.group(1) for line in text.splitlines()
            if (match := PART_DIRECTIVE.match(line))]


def file_at_ref(repo_root: Path, ref: str, path: str) -> str | None:
    try:
        return subprocess.check_output(
            ["git", "show", f"{ref}:{path}"],
            cwd=repo_root, stderr=subprocess.DEVNULL, text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None


def collect_current(repo_root: Path, main_path: str) -> tuple[list[str], list[str]]:
    """Return (significant lines across main + its parts, part paths)."""
    main_file = repo_root / main_path
    main_text = main_file.read_text(encoding="utf-8")
    lines = significant_lines(main_text)
    parts = []
    for relative in declared_parts(main_text):
        part_file = (main_file.parent / relative).resolve()
        parts.append(str(part_file.relative_to(repo_root.resolve())))
        lines.extend(significant_lines(part_file.read_text(encoding="utf-8")))
    return lines, parts


def compare(before: list[str], after: list[str]) -> list[str]:
    removed = Counter(before) - Counter(after)
    added = Counter(after) - Counter(before)
    findings = []
    for line, count in sorted(removed.items()):
        findings.append(f"  - perdue x{count} : {line.strip()[:110]}")
    for line, count in sorted(added.items()):
        findings.append(f"  + ajoutée x{count} : {line.strip()[:110]}")
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", help="Fichier(s) principal(aux) découpé(s)")
    parser.add_argument("--base-ref", default="origin/main")
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    failed = False

    for main_path in args.files:
        original = file_at_ref(repo_root, args.base_ref, main_path)
        if original is None:
            print(f"{main_path} : introuvable sur {args.base_ref} — nouveau fichier, rien à prouver.")
            continue

        before = significant_lines(original)
        after, parts = collect_current(repo_root, main_path)
        findings = compare(before, after)

        if findings:
            failed = True
            print(f"{main_path} : ÉCHEC — l'extraction a modifié du code.")
            for finding in findings[:40]:
                print(finding)
            if len(findings) > 40:
                print(f"  … {len(findings) - 40} écart(s) supplémentaire(s)")
        else:
            print(
                f"{main_path} : OK — déplacement pur, {len(before)} lignes "
                f"significatives réparties sur {len(parts) + 1} fichier(s)."
            )

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
