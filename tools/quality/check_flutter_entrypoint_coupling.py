#!/usr/bin/env python3
"""Prevent new Flutter code from depending on the application entrypoint.

`lib/main.dart` must remain a composition root, not a service locator. A small
transitional allowlist tracks the remaining historical imports while Lot 2
removes them progressively. The allowlist is intentionally monotonic: if an
allowed file stops importing main.dart, CI asks us to remove it from the list.
"""

from __future__ import annotations

import re
from pathlib import Path


# Transitional debt. This set must only shrink during Lot 2.
_ALLOWED_MAIN_IMPORTERS = {
    "lib/dev/page_capture_catalog_page.dart",
    "lib/pages/account_page.dart",
    "lib/pages/consult_offers_page.dart",
    "lib/pages/fiche_pro_page.dart",
    "lib/pages/home_page.dart",
    "lib/pages/publish_offer_page.dart",
    "lib/pages/user_offers_section.dart",
}

_IMPORT_RE = re.compile(r"^\s*import\s+['\"]([^'\"]+)['\"]", re.MULTILINE)


def _imports_app_main(source: str) -> bool:
    if source == "main.dart":
        return True
    if source == "package:presto_app/main.dart":
        return True
    return source.startswith(".") and source.endswith("/main.dart")


def find_main_importers(root: Path) -> set[str]:
    importers: set[str] = set()
    for dart_file in sorted((root / "lib").rglob("*.dart")):
        rel = dart_file.relative_to(root).as_posix()
        if rel == "lib/main.dart":
            continue
        text = dart_file.read_text(encoding="utf-8", errors="ignore")
        if any(_imports_app_main(match) for match in _IMPORT_RE.findall(text)):
            importers.add(rel)
    return importers


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    importers = find_main_importers(root)
    unexpected = sorted(importers - _ALLOWED_MAIN_IMPORTERS)
    stale = sorted(_ALLOWED_MAIN_IMPORTERS - importers)

    if unexpected:
        print("Flutter entrypoint coupling guardrail: FAIL")
        print("New imports of lib/main.dart are forbidden:")
        for path in unexpected:
            print(f"- {path}")
        return 1

    if stale:
        print("Flutter entrypoint coupling guardrail: FAIL")
        print("Shrink the transitional allowlist; these files are now decoupled:")
        for path in stale:
            print(f"- {path}")
        return 1

    print(
        "Flutter entrypoint coupling guardrail: OK "
        f"({len(importers)} transitional importer(s) remain)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
