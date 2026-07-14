#!/usr/bin/env python3
"""Check Flutter screen/widget line budgets without hiding existing debt.

The goal is to make Phase 1 decomposition measurable:
- new screens should stay under 500 lines;
- reusable widgets should stay under 250 lines;
- known legacy files may remain above budget only while they do not grow.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class Finding:
    path: str
    lines: int
    limit: int
    kind: str
    reason: str


def _read_config(path: Path) -> dict:
    if not path.exists():
        raise SystemExit(f"Configuration introuvable: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def _line_count(path: Path) -> int:
    text = path.read_text(encoding="utf-8", errors="ignore")
    if not text:
        return 0
    return text.count("\n") + (0 if text.endswith("\n") else 1)


def _is_ignored(path: str, ignored_prefixes: Iterable[str]) -> bool:
    normalized = path.replace("\\", "/")
    return any(normalized.startswith(prefix) for prefix in ignored_prefixes)


def _classify(path: str, content: str) -> tuple[str, int] | None:
    normalized = path.replace("\\", "/")
    lower = normalized.lower()

    if "/widgets/" in lower or lower.endswith("_widgets.dart") or "/widget/" in lower:
        return ("widget", 250)

    if "/pages/" in lower or lower.endswith("_page.dart"):
        return ("screen", 500)

    # Defensive fallback: a file that declares a page-like widget is treated as a screen.
    if "extends StatefulWidget" in content or "extends StatelessWidget" in content:
        if "Page" in content or lower.endswith("page.dart"):
            return ("screen", 500)

    return None


def scan(root: Path, config: dict) -> list[Finding]:
    budgets = config.get("budgets", {})
    screen_limit = int(budgets.get("screen_max_lines", 500))
    widget_limit = int(budgets.get("widget_max_lines", 250))
    baseline = config.get("baseline_exceptions", {})
    ignored = tuple(config.get("ignored_paths", []))

    findings: list[Finding] = []
    lib_dir = root / "lib"
    if not lib_dir.exists():
        raise SystemExit("Dossier lib/ introuvable")

    for dart_file in sorted(lib_dir.rglob("*.dart")):
        rel = dart_file.relative_to(root).as_posix()
        if _is_ignored(rel, ignored):
            continue

        content = dart_file.read_text(encoding="utf-8", errors="ignore")
        classified = _classify(rel, content)
        if classified is None:
            continue

        kind, default_limit = classified
        limit = screen_limit if kind == "screen" else widget_limit
        if default_limit != limit:
            limit = default_limit

        lines = _line_count(dart_file)
        if lines <= limit:
            continue

        exception = baseline.get(rel)
        if exception:
            current_lines = int(exception.get("current_lines", lines))
            if lines <= current_lines:
                continue
            findings.append(
                Finding(
                    path=rel,
                    lines=lines,
                    limit=current_lines,
                    kind=kind,
                    reason="legacy file grew above its baseline",
                )
            )
            continue

        findings.append(
            Finding(
                path=rel,
                lines=lines,
                limit=limit,
                kind=kind,
                reason="new oversized Flutter file",
            )
        )

    return findings


def _print_report(findings: list[Finding]) -> None:
    if not findings:
        print("Flutter architecture size guardrail: OK")
        return

    print("Flutter architecture size guardrail: FAIL")
    for item in findings:
        print(
            f"- {item.path}: {item.lines} lines > {item.limit} "
            f"({item.kind}, {item.reason})"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".", help="Repository root")
    parser.add_argument(
        "--config",
        default="quality/flutter_architecture_size_budget.json",
        help="Architecture budget configuration",
    )
    parser.add_argument(
        "--enforce",
        action="store_true",
        help="Exit non-zero when the budget is violated",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    config_path = (root / args.config).resolve()
    findings = scan(root, _read_config(config_path))
    _print_report(findings)
    return 1 if args.enforce and findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
